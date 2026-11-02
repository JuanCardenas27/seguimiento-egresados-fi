"""Tipo de vínculo y modalidad: valores de LinkedIn (español o inglés) -> categorías."""
import re

from .texto import normalizar

_TIPO_EMPLEO = {
    "full time": "TIEMPO_COMPLETO", "jornada completa": "TIEMPO_COMPLETO", "tiempo completo": "TIEMPO_COMPLETO",
    "part time": "MEDIO_TIEMPO", "jornada parcial": "MEDIO_TIEMPO", "medio tiempo": "MEDIO_TIEMPO",
    "contract": "CONTRATO", "contrato": "CONTRATO", "temporary": "CONTRATO", "temporal": "CONTRATO",
    "seasonal": "CONTRATO", "de temporada": "CONTRATO",
    "self employed": "INDEPENDIENTE", "autonomo": "INDEPENDIENTE", "freelance": "INDEPENDIENTE",
    "independiente": "INDEPENDIENTE",
    "internship": "PRACTICA", "practicas": "PRACTICA", "apprenticeship": "PRACTICA",
    "contrato de formacion": "PRACTICA",
}
_MODALIDAD = {
    "on site": "PRESENCIAL", "presencial": "PRESENCIAL",
    "remote": "REMOTO", "en remoto": "REMOTO", "remoto": "REMOTO",
    "hybrid": "HIBRIDO", "hibrido": "HIBRIDO",
}
_RE_FUNDADOR = re.compile(r"(?i)\b(fundador|fundadora|cofundador|cofundadora|co-?founder|founder)\b")


def tipo_vinculo(tipo_empleo: str | None, cargo: str | None) -> str:
    if cargo and _RE_FUNDADOR.search(cargo):
        return "EMPRENDIMIENTO"
    return _TIPO_EMPLEO.get(normalizar(tipo_empleo), "NO_INFORMADO")


def modalidad(valor: str | None) -> str:
    return _MODALIDAD.get(normalizar(valor), "NO_INFORMADO")
