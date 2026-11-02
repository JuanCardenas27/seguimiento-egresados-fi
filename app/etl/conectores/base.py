"""Interfaces comunes de los conectores."""
from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime


class PerfilNoDisponible(Exception):
    """El perfil ya no existe, es privado o la fuente no lo entrega."""


class FuenteBloqueada(Exception):
    """La fuente respondió con un límite de solicitudes o un bloqueo: la ejecución se detiene."""


@dataclass
class ResultadoBusqueda:
    url: str
    titulo: str | None = None


@dataclass
class PerfilCapturado:
    crudo: dict                       # perfil en formato canónico, aún sin minimizar
    capturado_en: datetime


class Buscador(ABC):
    codigo_canal = "BUSCADOR_WEB"

    @abstractmethod
    def buscar(self, consulta: str) -> list[ResultadoBusqueda]:
        """Devuelve las URL encontradas para una consulta."""


class Extractor(ABC):
    codigo_canal: str

    @abstractmethod
    def obtener(self, id_publico: str) -> PerfilCapturado:
        """Devuelve el perfil público o lanza PerfilNoDisponible."""
