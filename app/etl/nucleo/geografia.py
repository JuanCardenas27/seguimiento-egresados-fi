"""Ubicación en texto libre -> país ISO 3166-1 y municipio DIVIPOLA."""
from dataclasses import dataclass

from .texto import espacios, normalizar


@dataclass(frozen=True)
class Ubicacion:
    codigo_pais: str | None
    codigo_municipio: str | None
    ciudad_extranjera: str | None


SIN_UBICACION = Ubicacion(None, None, None)


def resolver(texto: str | None, alias: dict[str, tuple[str, str | None]]) -> Ubicacion:
    """'Bogotá, D.C., Colombia' -> ('CO', '11001', None)"""
    if not texto:
        return SIN_UBICACION
    partes = [p for p in (espacios(x) for x in texto.split(",")) if p]
    pais = municipio = None
    no_reconocidas = []
    for parte in partes:
        clave = normalizar(parte)
        if clave in alias:
            p, m = alias[clave]
            pais = pais or p
            municipio = municipio or m
        else:
            no_reconocidas.append(parte)
    if pais is None:
        return SIN_UBICACION
    if pais == "CO":
        return Ubicacion("CO", municipio, None)
    ciudad = no_reconocidas[0] if no_reconocidas else None
    return Ubicacion(pais, None, ciudad[:100] if ciudad else None)
