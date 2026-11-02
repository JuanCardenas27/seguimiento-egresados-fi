"""Conectores de archivo: reproducen las respuestas de las API con datos ficticios."""
import json
from datetime import datetime
from pathlib import Path

from .base import Buscador, Extractor, PerfilCapturado, PerfilNoDisponible, ResultadoBusqueda


class BuscadorArchivo(Buscador):
    codigo_canal = "ARCHIVO_PRUEBA"

    def __init__(self, ruta: Path):
        datos = json.loads(Path(ruta).read_text(encoding="utf-8"))
        self._por_consulta = {d["consulta"]: d["resultados"] for d in datos}

    def buscar(self, consulta: str) -> list[ResultadoBusqueda]:
        return [ResultadoBusqueda(r["url"], r.get("titulo")) for r in self._por_consulta.get(consulta, [])]


class ExtractorArchivo(Extractor):
    """Lee perfiles/<id_publico>.json."""
    codigo_canal = "ARCHIVO_PRUEBA"

    def __init__(self, carpeta: Path):
        self.carpeta = Path(carpeta)

    def obtener(self, id_publico: str) -> PerfilCapturado:
        ruta = self.carpeta / f"{id_publico}.json"
        if not ruta.exists():
            raise PerfilNoDisponible(id_publico)
        crudo = json.loads(ruta.read_text(encoding="utf-8"))
        capturado = crudo.pop("_capturado_en", None)
        return PerfilCapturado(crudo, datetime.fromisoformat(capturado) if capturado else datetime.now())
