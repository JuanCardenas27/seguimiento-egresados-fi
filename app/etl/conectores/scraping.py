"""Canal A: scraping de la versión pública del perfil de LinkedIn."""
import json
import os
import random
import time
import urllib.error
import urllib.request
from datetime import datetime
from html.parser import HTMLParser

from .base import Extractor, FuenteBloqueada, PerfilCapturado, PerfilNoDisponible

VERSION_ANALIZADOR = "1.0.0"
PAUSA_MIN, PAUSA_MAX = 10.0, 20.0
# LinkedIn redirige a estas rutas cuando no muestra el perfil
_MARCAS_MURO = ("authwall", "uas/login", "checkpoint/challenge", "captcha")


class _LectorJsonLd(HTMLParser):
    """Recoge el contenido de los <script type="application/ld+json">."""

    def __init__(self):
        super().__init__()
        self.bloques: list[str] = []
        self._dentro = False

    def handle_starttag(self, tag, attrs):
        if tag == "script" and (dict(attrs).get("type") or "").lower() == "application/ld+json":
            self._dentro = True
            self.bloques.append("")

    def handle_endtag(self, tag):
        if tag == "script":
            self._dentro = False

    def handle_data(self, data):
        if self._dentro:
            self.bloques[-1] += data


def _como_lista(valor) -> list:
    if valor is None:
        return []
    return valor if isinstance(valor, list) else [valor]


def _nodos(dato) -> list[dict]:
    """Aplana un JSON-LD: objeto suelto, lista u objeto con @graph."""
    nodos = []
    for d in _como_lista(dato):
        if isinstance(d, dict):
            nodos.extend(_nodos(d["@graph"]) if "@graph" in d else [d])
    return nodos


def _es_tipo(nodo: dict, tipo: str) -> bool:
    return tipo in _como_lista(nodo.get("@type"))


def _texto(valor) -> str | None:
    if isinstance(valor, dict):
        valor = valor.get("name")
    return str(valor).strip() if valor else None


def _localidad(direccion) -> str | None:
    if isinstance(direccion, dict):
        partes = [direccion.get(k) for k in ("addressLocality", "addressRegion", "addressCountry")]
        return ", ".join(_texto(p) for p in partes if _texto(p)) or None
    return _texto(direccion)


def _periodo(org: dict) -> tuple[str | None, str | None]:
    """schema.org registra las fechas en el rol (member) o en la propia organización."""
    rol = next((m for m in _como_lista(org.get("member")) if isinstance(m, dict)), {})
    return (rol.get("startDate") or org.get("startDate"), rol.get("endDate") or org.get("endDate"))


def analizar_html(html: str, id_publico: str) -> dict:
    """Página pública del perfil -> perfil canónico (aún sin minimizar)."""
    lector = _LectorJsonLd()
    lector.feed(html)
    persona = None
    for bloque in lector.bloques:
        try:
            dato = json.loads(bloque)
        except json.JSONDecodeError:
            continue
        persona = next((n for n in _nodos(dato) if _es_tipo(n, "Person")), None)
        if persona:
            break
    if persona is None:
        raise PerfilNoDisponible(f"{id_publico}: sin datos estructurados (analizador {VERSION_ANALIZADOR})")

    nombres, apellidos = persona.get("givenName"), persona.get("familyName")
    if not nombres and persona.get("name"):
        # si no vienen separados, todo queda en nombres
        nombres = _texto(persona["name"])

    educacion = []
    for org in _como_lista(persona.get("alumniOf")):
        if isinstance(org, dict) and _texto(org):
            inicio, fin = _periodo(org)
            educacion.append({"institucion": _texto(org), "url_institucion": org.get("url"),
                              "titulo": None, "campo": None, "inicio": inicio, "fin": fin})

    experiencia = []
    for org in _como_lista(persona.get("worksFor")):
        if isinstance(org, dict) and _texto(org):
            inicio, fin = _periodo(org)
            rol = next((m for m in _como_lista(org.get("member")) if isinstance(m, dict)), {})
            experiencia.append({
                "cargo": rol.get("roleName") or rol.get("jobTitle") or _texto(persona.get("jobTitle")),
                "empresa": _texto(org), "url_empresa": org.get("url"),
                "ubicacion": _localidad(org.get("location") or org.get("address")),
                "inicio": inicio, "fin": fin,
            })

    # minimizar() quita después lo que no está en la lista blanca
    return {"id_publico": id_publico, "nombres": nombres, "apellidos": apellidos,
            "ubicacion": _localidad(persona.get("address")),
            "educacion": educacion, "experiencia": experiencia}


def es_muro(url_final: str, html: str) -> bool:
    """True si LinkedIn devolvió un muro de inicio de sesión o un CAPTCHA en lugar del perfil."""
    url_final = (url_final or "").lower()
    if any(m in url_final for m in _MARCAS_MURO):
        return True
    # no buscar 'authwall' en el html, también aparece en páginas normales
    return "g-recaptcha" in html[:20000].lower()


class ExtractorScraping(Extractor):
    codigo_canal = "SCRAPING_PUBLICO"

    def __init__(self, pausa: tuple[float, float] = (PAUSA_MIN, PAUSA_MAX)):
        contacto = os.environ.get("ETL_SCRAPING_CONTACTO", "").strip()
        if not contacto:
            raise ValueError("Falta ETL_SCRAPING_CONTACTO: correo de la Facultad que identifica al scraper.")
        self.agente = (f"SeguimientoEgresadosFI/{VERSION_ANALIZADOR} "
                       f"(Facultad de Ingenieria, Universidad Nacional de Colombia; +mailto:{contacto})")
        self.pausa = pausa

    def _descargar(self, url: str) -> tuple[str, str]:
        # sin cookies ni sesión
        peticion = urllib.request.Request(url, headers={"User-Agent": self.agente,
                                                        "Accept": "text/html", "Accept-Language": "es,en"})
        try:
            with urllib.request.urlopen(peticion, timeout=30) as resp:
                return resp.geturl(), resp.read().decode("utf-8", errors="replace")
        except urllib.error.HTTPError as e:
            if e.code in (404, 410):
                raise PerfilNoDisponible(url) from e
            if e.code in (429, 999) or e.code >= 500:
                # LinkedIn está limitando: se para por hoy
                raise FuenteBloqueada(f"HTTP {e.code} en {url}") from e
            raise

    def obtener(self, id_publico: str) -> PerfilCapturado:
        time.sleep(random.uniform(*self.pausa))
        url_final, html = self._descargar(f"https://www.linkedin.com/in/{id_publico}/")
        if es_muro(url_final, html):
            raise PerfilNoDisponible(f"{id_publico}: muro de inicio de sesión o CAPTCHA")
        return PerfilCapturado(analizar_html(html, id_publico), datetime.now())
