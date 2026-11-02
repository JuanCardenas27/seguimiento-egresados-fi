"""Nombre canónico de organizaciones."""
import re

from .texto import espacios, sin_tildes

# Variantes del sufijo societario -> forma canónica
_SUFIJOS = [
    (r"S\.?\s*A\.?\s*S\.?", "S.A.S."),
    (r"S\.?\s*A\.?\s*E\.?\s*S\.?\s*P\.?", "S.A. E.S.P."),
    (r"E\.?\s*S\.?\s*P\.?", "E.S.P."),
    (r"LTDA\.?", "LTDA."),
    (r"S\.?\s*A\.?", "S.A."),
    (r"GMBH", "GMBH"),
    (r"INC\.?", "INC."),
    (r"LLC\.?", "LLC"),
]


def nombre_canonico(nombre: str) -> str:
    """'Andes Software sas' -> 'ANDES SOFTWARE S.A.S.'"""
    n = espacios(nombre) or ""
    n = n.upper().rstrip(" ,.")
    for patron, canonico in _SUFIJOS:
        nuevo, cambios = re.subn(r"[\s,]+" + patron + r"$", " " + canonico, n)
        if cambios:
            return nuevo.strip()
    return n


def nombre_base(nombre: str) -> str:
    """Nombre canónico sin sufijo societario ni tildes: 'ANDES SOFTWARE S.A.S.' -> 'ANDES SOFTWARE'."""
    n = nombre_canonico(nombre)
    for _, canonico in _SUFIJOS:
        if n.endswith(" " + canonico):
            n = n[: -len(canonico) - 1]
            break
    return sin_tildes(n).strip()


def clave_alias(nombre: str) -> str:
    """Clave de búsqueda de alias: mayúsculas, sin tildes ni espacios repetidos."""
    return sin_tildes(espacios(nombre) or "").upper()
