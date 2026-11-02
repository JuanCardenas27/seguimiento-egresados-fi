"""Pruebas del canal A sin conexión a LinkedIn: analizador, muros e identificación."""
import os
import unittest
from unittest import mock

from etl.conectores.base import FuenteBloqueada, PerfilNoDisponible, PerfilRestringido
from etl.conectores.scraping import MUROS_PARA_DETENER, ExtractorScraping, analizar_html, es_muro
from etl.nucleo.perfil import minimizar

PAGINA = """<html><head>
<script type="application/ld+json">{"@context": "https://schema.org", "@graph": [
  {"@type": "WebPage", "name": "Perfil"},
  {"@type": "Person", "givenName": "Paula", "familyName": "Ficticia Ruiz",
   "image": "https://ejemplo/foto.jpg", "description": "Extracto que no se guarda",
   "address": {"@type": "PostalAddress", "addressLocality": "Bogotá, D.C.", "addressCountry": "CO"},
   "alumniOf": [{"@type": "CollegeOrUniversity", "name": "Universidad Nacional de Colombia",
                 "url": "https://www.linkedin.com/school/universidad-nacional-de-colombia/",
                 "member": {"@type": "OrganizationRole", "startDate": "2012", "endDate": "2017"}}],
   "worksFor": [{"@type": "Organization", "name": "Empresa Ficticia S.A.S.",
                 "url": "https://www.linkedin.com/company/empresa-ficticia/",
                 "location": "Medellín, Antioquia, Colombia",
                 "member": {"@type": "OrganizationRole", "roleName": "Ingeniera de procesos",
                            "startDate": "2019-03"}}]}
]}</script></head><body></body></html>"""


class AnalizadorTest(unittest.TestCase):
    def test_json_ld_a_perfil_canonico(self):
        perfil = minimizar(analizar_html(PAGINA, "paula-ficticia-ruiz"))
        self.assertEqual(perfil["nombres"], "Paula")
        self.assertEqual(perfil["ubicacion"], "Bogotá, D.C., CO")
        self.assertEqual(perfil["educacion"][0]["institucion"], "Universidad Nacional de Colombia")
        self.assertEqual((perfil["educacion"][0]["inicio"], perfil["educacion"][0]["fin"]), ("2012", "2017"))
        x = perfil["experiencia"][0]
        self.assertEqual((x["cargo"], x["empresa"], x["inicio"], x["fin"]),
                         ("Ingeniera de procesos", "Empresa Ficticia S.A.S.", "2019-03", None))

    def test_minimizacion_descarta_foto_y_extracto(self):
        perfil = minimizar(analizar_html(PAGINA, "paula-ficticia-ruiz"))
        self.assertNotIn("image", perfil)
        self.assertNotIn("description", perfil)

    def test_pagina_sin_datos_estructurados(self):
        with self.assertRaises(PerfilNoDisponible):
            analizar_html("<html><body>Sin JSON-LD</body></html>", "x-fict")

    def test_muro_de_inicio_de_sesion_y_captcha(self):
        self.assertTrue(es_muro("https://www.linkedin.com/authwall?trk=x", ""))
        self.assertTrue(es_muro("https://www.linkedin.com/in/x/", '<div class="g-recaptcha"></div>'))
        self.assertFalse(es_muro("https://www.linkedin.com/in/x/", PAGINA))


class CargoTest(unittest.TestCase):
    def test_cargo_actual_solo_para_el_empleo_vigente(self):
        pagina = """<script type="application/ld+json">{"@type": "Person", "givenName": "P", "jobTitle": "Gerente",
          "worksFor": [{"name": "Actual S.A.S.", "member": {"startDate": "2020"}},
                       {"name": "Anterior S.A.S.", "member": {"startDate": "2015", "endDate": "2019"}}]}</script>"""
        perfil = minimizar(analizar_html(pagina, "p-fict"))
        self.assertEqual([(x["empresa"], x["cargo"]) for x in perfil["experiencia"]], [("Actual S.A.S.", "Gerente")])


class MurosTest(unittest.TestCase):
    def setUp(self):
        with mock.patch.dict(os.environ, {"ETL_SCRAPING_CONTACTO": "egresados@ejemplo.edu.co"}):
            self.extractor = ExtractorScraping(pausa=(0, 0))

    def test_muro_aislado_es_perfil_restringido(self):
        with mock.patch.object(self.extractor, "_descargar", return_value=("https://www.linkedin.com/authwall", "")):
            with self.assertRaises(PerfilRestringido):
                self.extractor.obtener("a-fict")

    def test_muros_seguidos_detienen_la_extraccion(self):
        with mock.patch.object(self.extractor, "_descargar", return_value=("https://www.linkedin.com/authwall", "")):
            for _ in range(MUROS_PARA_DETENER - 1):
                with self.assertRaises(PerfilRestringido):
                    self.extractor.obtener("a-fict")
            with self.assertRaises(FuenteBloqueada):
                self.extractor.obtener("a-fict")

    def test_una_lectura_exitosa_reinicia_el_conteo(self):
        muro = ("https://www.linkedin.com/authwall", "")
        ok = ("https://www.linkedin.com/in/x/", PAGINA)
        respuestas = [muro] * (MUROS_PARA_DETENER - 1) + [ok, muro]
        with mock.patch.object(self.extractor, "_descargar", side_effect=respuestas):
            for _ in range(MUROS_PARA_DETENER - 1):
                with self.assertRaises(PerfilRestringido):
                    self.extractor.obtener("a-fict")
            self.extractor.obtener("x-fict")
            with self.assertRaises(PerfilRestringido):
                self.extractor.obtener("a-fict")


class IdentificacionTest(unittest.TestCase):
    def test_no_arranca_sin_correo_de_contacto(self):
        with mock.patch.dict(os.environ, {}, clear=True):
            with self.assertRaises(ValueError):
                ExtractorScraping()

    def test_agente_de_usuario_identifica_a_la_facultad(self):
        with mock.patch.dict(os.environ, {"ETL_SCRAPING_CONTACTO": "egresados@ejemplo.edu.co"}, clear=True):
            self.assertIn("mailto:egresados@ejemplo.edu.co", ExtractorScraping().agente)


if __name__ == "__main__":
    unittest.main()
