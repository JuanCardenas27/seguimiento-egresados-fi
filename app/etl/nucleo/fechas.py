"""Interpretación de las fechas tal como aparecen en LinkedIn."""
import re
from dataclasses import dataclass
from datetime import date

from .texto import normalizar

MESES = {
    "ene": 1, "enero": 1, "jan": 1, "january": 1,
    "feb": 2, "febrero": 2, "february": 2,
    "mar": 3, "marzo": 3, "march": 3,
    "abr": 4, "abril": 4, "apr": 4, "april": 4,
    "may": 5, "mayo": 5,
    "jun": 6, "junio": 6, "june": 6,
    "jul": 7, "julio": 7, "july": 7,
    "ago": 8, "agosto": 8, "aug": 8, "august": 8,
    "sep": 9, "sept": 9, "septiembre": 9, "setiembre": 9, "september": 9,
    "oct": 10, "octubre": 10, "october": 10,
    "nov": 11, "noviembre": 11, "november": 11,
    "dic": 12, "diciembre": 12, "dec": 12, "december": 12,
}

ACTUAL = {"actualidad", "presente", "present", "actual", "hoy", "now"}


@dataclass(frozen=True)
class FechaParcial:
    fecha: date
    precision: str  # 'MES' | 'ANIO'


def interpretar(valor) -> FechaParcial | None:
    """Convierte '2019-02', '2019', 'feb. de 2019', 'Feb 2019' o '02/2019'."""
    if valor is None:
        return None
    texto = str(valor).strip()
    if not texto or normalizar(texto) in ACTUAL:
        return None

    m = re.fullmatch(r"(\d{4})-(\d{1,2})(?:-\d{1,2})?", texto)
    if m:
        return _crear(int(m.group(1)), int(m.group(2)))
    m = re.fullmatch(r"(\d{1,2})/(\d{4})", texto)
    if m:
        return _crear(int(m.group(2)), int(m.group(1)))
    m = re.fullmatch(r"(\d{4})", texto)
    if m:
        return _crear(int(m.group(1)), None)

    palabras = normalizar(texto).split()
    anio = next((int(p) for p in palabras if re.fullmatch(r"\d{4}", p)), None)
    mes = next((MESES[p] for p in palabras if p in MESES), None)
    if anio:
        return _crear(anio, mes)
    return None


def es_actual(valor) -> bool:
    return valor is None or normalizar(str(valor)) in ACTUAL or str(valor).strip() == ""


def anio(valor) -> int | None:
    f = interpretar(valor)
    return f.fecha.year if f else None


def _crear(anio_: int, mes: int | None) -> FechaParcial | None:
    if not 1940 <= anio_ <= 2100:
        return None
    if mes is None:
        return FechaParcial(date(anio_, 1, 1), "ANIO")
    if not 1 <= mes <= 12:
        return None
    return FechaParcial(date(anio_, mes, 1), "MES")
