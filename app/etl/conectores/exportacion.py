"""Canal consentido: archivo de exportación de LinkedIn entregado por el egresado."""
import csv
from datetime import datetime
from pathlib import Path

from .base import PerfilCapturado


def _leer(ruta: Path) -> list[dict]:
    if not ruta.exists():
        return []
    with ruta.open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def leer_exportacion(carpeta: Path, id_publico: str) -> PerfilCapturado:
    carpeta = Path(carpeta)
    perfil = (_leer(carpeta / "Profile.csv") or [{}])[0]
    educacion = [
        {
            "institucion": e.get("School Name"),
            "titulo": e.get("Degree Name"),
            "campo": e.get("Notes") or None,
            "inicio": e.get("Start Date"),
            "fin": e.get("End Date"),
        }
        for e in _leer(carpeta / "Education.csv")
    ]
    experiencia = [
        {
            "cargo": p.get("Title"),
            "empresa": p.get("Company Name"),
            "ubicacion": p.get("Location"),
            "inicio": p.get("Started On"),
            "fin": p.get("Finished On"),
        }
        for p in _leer(carpeta / "Positions.csv")
    ]
    crudo = {
        "id_publico": id_publico,
        "nombres": perfil.get("First Name"),
        "apellidos": perfil.get("Last Name"),
        "ubicacion": perfil.get("Geo Location"),
        "educacion": educacion,
        "experiencia": experiencia,
        # el resto de columnas de Profile.csv no se copia
    }
    return PerfilCapturado(crudo, datetime.now())
