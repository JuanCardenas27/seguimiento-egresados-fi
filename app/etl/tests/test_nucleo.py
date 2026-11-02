"""Pruebas unitarias de la lógica del proceso (sin base de datos)."""
import json
import re
import unittest
from datetime import date
from pathlib import Path

from etl.nucleo import fechas, geografia, organizaciones, vinculo
from etl.nucleo.perfil import hash_contenido, minimizar
from etl.nucleo.texto import id_empresa_desde_url, id_publico_desde_url
from etl.nucleo.verificacion import Reglas, evaluar

RAIZ = Path(__file__).resolve().parents[3]
DATOS = Path(__file__).resolve().parents[1] / "datos_ejemplo"
HOY = date(2026, 11, 1)


def _reglas_desde_sql() -> Reglas:
    """Lee los diccionarios de db/02_catalogos.sql para probar las mismas reglas que usa producción."""
    sql = (RAIZ / "db" / "02_catalogos.sql").read_text(encoding="utf-8")

    def bloque(tabla):
        cuerpo = re.search(rf"INSERT INTO {tabla} \([^)]*\) VALUES(.*?);\n", sql, re.S).group(1)
        return re.findall(r"\('((?:[^']|'')*)',\s*'?([^',)]+)'?,\s*(\d+)\)", cuerpo)

    sin_escape = lambda p: p.replace("\\\\", "\\")  # noqa: E731  (el literal SQL duplica la barra)
    niveles_programa = {1: "PREGRADO", 2: "PREGRADO", 3: "PREGRADO", 4: "PREGRADO", 5: "PREGRADO",
                        6: "PREGRADO", 7: "PREGRADO", 8: "PREGRADO", 9: "PREGRADO",
                        10: "MAESTRIA", 11: "MAESTRIA", 12: "DOCTORADO"}
    return Reglas(
        institucion=Reglas.compilar([(sin_escape(p), r, int(o)) for p, r, o in bloque("regla_institucion")]),
        nivel=Reglas.compilar([(sin_escape(p), r, int(o)) for p, r, o in bloque("regla_nivel_formacion")]),
        programa=Reglas.compilar([(sin_escape(p), (int(r), niveles_programa[int(r)]), int(o))
                                  for p, r, o in bloque("regla_programa")]),
    )


REGLAS = _reglas_desde_sql()


def _perfil(nombre):
    return minimizar(json.loads((DATOS / "perfiles" / f"{nombre}.json").read_text(encoding="utf-8")))


class PruebasIdentificadores(unittest.TestCase):
    def test_normaliza_url_de_perfil(self):
        self.assertEqual(id_publico_desde_url("https://co.linkedin.com/in/Ana-Rojas-123/?trk=x"), "ana-rojas-123")
        self.assertEqual(id_publico_desde_url("https://www.linkedin.com/in/ana-rojas-123"), "ana-rojas-123")

    def test_rechaza_urls_que_no_son_perfiles(self):
        self.assertIsNone(id_publico_desde_url("https://www.linkedin.com/posts/x-activity-1"))
        self.assertIsNone(id_publico_desde_url("https://www.linkedin.com/company/andes"))
        self.assertIsNone(id_publico_desde_url("https://linkedin.com.evil.example/in/ana"))
        self.assertIsNone(id_publico_desde_url("https://www.facebook.com/in/ana"))

    def test_id_de_empresa(self):
        self.assertEqual(id_empresa_desde_url("https://www.linkedin.com/company/andes-software/"), "andes-software")


class PruebasMinimizacion(unittest.TestCase):
    def test_descarta_campos_fuera_de_la_lista_blanca(self):
        perfil = _perfil("ana-maria-rojas-perez-fict")
        texto = json.dumps(perfil, ensure_ascii=False)
        for campo in ("foto_url", "acerca_de", "aptitudes", "correo", "titular", "descripcion", "actividades"):
            self.assertNotIn(campo, texto)
        self.assertEqual(len(perfil["experiencia"]), 3)

    def test_huella_estable_e_independiente_del_orden(self):
        a = {"nombres": "Ana", "id_publico": "x", "educacion": [], "experiencia": []}
        b = {"experiencia": [], "educacion": [], "id_publico": "x", "nombres": "Ana"}
        self.assertEqual(hash_contenido(minimizar(a)), hash_contenido(minimizar(b)))


class PruebasFechas(unittest.TestCase):
    def test_formatos(self):
        self.assertEqual(fechas.interpretar("2019-02"), fechas.FechaParcial(date(2019, 2, 1), "MES"))
        self.assertEqual(fechas.interpretar("feb. de 2019"), fechas.FechaParcial(date(2019, 2, 1), "MES"))
        self.assertEqual(fechas.interpretar("Aug 2016").fecha, date(2016, 8, 1))
        self.assertEqual(fechas.interpretar("2016"), fechas.FechaParcial(date(2016, 1, 1), "ANIO"))
        self.assertEqual(fechas.interpretar("07/2020").fecha, date(2020, 7, 1))

    def test_actualidad(self):
        for valor in (None, "", "Present", "actualidad"):
            self.assertIsNone(fechas.interpretar(valor))
            self.assertTrue(fechas.es_actual(valor))
        self.assertFalse(fechas.es_actual("2020"))


class PruebasEstandarizacion(unittest.TestCase):
    ALIAS = {"bogota": ("CO", "11001"), "colombia": ("CO", None), "alemania": ("DE", None),
             "chia": ("CO", "25175")}

    def test_ubicaciones(self):
        self.assertEqual(geografia.resolver("Bogotá, D.C., Colombia", self.ALIAS), geografia.Ubicacion("CO", "11001", None))
        self.assertEqual(geografia.resolver("Hamburgo, Alemania", self.ALIAS), geografia.Ubicacion("DE", None, "Hamburgo"))
        self.assertEqual(geografia.resolver("Marte", self.ALIAS), geografia.SIN_UBICACION)

    def test_organizaciones(self):
        self.assertEqual(organizaciones.nombre_canonico("Andes Software sas"), "ANDES SOFTWARE S.A.S.")
        self.assertEqual(organizaciones.nombre_canonico("Energía del Ejemplo S.A. E.S.P."), "ENERGÍA DEL EJEMPLO S.A. E.S.P.")
        self.assertEqual(organizaciones.nombre_base("Andes Software S.A.S."), organizaciones.nombre_base("Andes Software"))

    def test_vinculo_y_modalidad(self):
        self.assertEqual(vinculo.tipo_vinculo("Full-time", "Analista"), "TIEMPO_COMPLETO")
        self.assertEqual(vinculo.tipo_vinculo("Internship", "Practicante"), "PRACTICA")
        self.assertEqual(vinculo.tipo_vinculo(None, "Fundador y CEO"), "EMPRENDIMIENTO")
        self.assertEqual(vinculo.modalidad("On-site"), "PRESENCIAL")
        self.assertEqual(vinculo.modalidad("Remote"), "REMOTO")


class PruebasVerificacion(unittest.TestCase):
    """La rúbrica aplicada a los perfiles ficticios de datos_ejemplo/."""

    def caso(self, nombre, decision, puntaje=None, motivo=None):
        r = evaluar(_perfil(nombre), REGLAS, HOY)
        self.assertEqual(r.decision, decision, r)
        if puntaje is not None:
            self.assertEqual(r.puntaje, puntaje, r.criterios)
        if motivo is not None:
            self.assertEqual(r.motivo, motivo)
        return r

    def test_pagina_oficial_y_programa(self):
        r = self.caso("ana-maria-rojas-perez-fict", "ACEPTADO", 100)
        programas = {f.id_programa for f in r.formaciones}
        self.assertEqual(programas, {3, 10})  # pregrado y maestría de Sistemas

    def test_nombre_sin_pagina(self):
        self.caso("carlos-gomez-salazar-fict", "ACEPTADO", 95)

    def test_titulo_en_ingles_y_residencia_exterior(self):
        r = self.caso("valentina-herrera-castro-fict", "ACEPTADO", 95)
        self.assertEqual(r.criterios["sede"], 5)

    def test_sin_fechas_va_a_revision(self):
        r = self.caso("julian-moreno-diaz-fict", "POR_REVISAR", 75)
        self.assertEqual(r.criterios["condicion"], 5)

    def test_estudiante_excluido(self):
        self.caso("mariana-castillo-ortiz-fict", "EXCLUIDO", motivo="ESTUDIANTE")

    def test_otra_sede_excluida(self):
        self.caso("laura-medina-fict", "EXCLUIDO", motivo="OTRA_SEDE")

    def test_sin_formacion_unal(self):
        perfil = {"educacion": [{"institucion": "Universidad del Ejemplo", "titulo": "Ingeniero", "fin": "2010"}]}
        self.assertEqual(evaluar(minimizar(perfil), REGLAS, HOY).decision, "DESCARTADO")

    def test_sin_programa_no_hay_aceptacion_automatica(self):
        perfil = {"educacion": [{"institucion": "Universidad Nacional de Colombia",
                                 "url_institucion": "https://www.linkedin.com/school/universidad-nacional-de-colombia/",
                                 "titulo": "Ingeniero", "campo": "Ingeniería", "inicio": "2008", "fin": "2013"}],
                  "ubicacion": "Bogotá, Colombia"}
        r = evaluar(minimizar(perfil), REGLAS, HOY)
        self.assertEqual(r.puntaje, 80)
        self.assertEqual(r.decision, "POR_REVISAR")

    def test_institucion_ambigua_queda_por_debajo_del_umbral(self):
        perfil = {"educacion": [{"institucion": "Universidad Nacional", "titulo": "Ingeniero Civil",
                                 "inicio": "2008", "fin": "2013"}]}
        r = evaluar(minimizar(perfil), REGLAS, HOY)
        self.assertEqual(r.criterios["institucion"], 10)
        self.assertEqual(r.decision, "POR_REVISAR")

    @staticmethod
    def _unal(titulo, campo, pagina=True):
        return minimizar({"ubicacion": "Bogotá, Colombia", "educacion": [{
            "institucion": "Universidad Nacional de Colombia", "titulo": titulo, "campo": campo,
            "url_institucion": "https://www.linkedin.com/school/universidad-nacional-de-colombia/" if pagina else None,
            "inicio": "2010", "fin": "2015"}]})

    def test_programas_de_otras_facultades_no_se_aceptan(self):
        # coinciden con el patrón de un programa de la Facultad, pero no son ingeniería
        for titulo, campo in (("Diseñador Industrial", "Diseño Industrial"), ("Químico", "Química"),
                              ("Profesional", "Ciencias de la Computación")):
            r = evaluar(self._unal(titulo, campo), REGLAS, HOY)
            self.assertNotEqual(r.decision, "ACEPTADO", campo)
            self.assertEqual(r.criterios["programa"], 0, campo)

    def test_otra_facultad_sin_relacion_con_ingenieria_se_excluye(self):
        r = evaluar(self._unal("Economista", "Economía"), REGLAS, HOY)
        self.assertEqual((r.decision, r.motivo), ("EXCLUIDO", "OTRA_FACULTAD"))

    def test_canal_a_infiere_el_programa_de_la_consulta(self):
        consulta = 'site:linkedin.com/in "Universidad Nacional de Colombia" "Ingeniería Civil"'
        perfil = self._unal(None, None)
        sin_pista = evaluar(perfil, REGLAS, HOY)
        con_pista = evaluar(perfil, REGLAS, HOY, consulta)
        self.assertEqual(sin_pista.decision, "POR_REVISAR")
        self.assertEqual(con_pista.decision, "ACEPTADO")
        self.assertEqual(con_pista.formaciones[0].id_programa, 2)
        # la pista no reemplaza un título que sí está en el perfil
        self.assertEqual(evaluar(self._unal("Economista", "Economía"), REGLAS, HOY, consulta).decision, "EXCLUIDO")


if __name__ == "__main__":
    unittest.main()
