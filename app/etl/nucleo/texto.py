"""Normalización de texto, identificadores de LinkedIn y huellas."""
import hashlib
import re
import unicodedata
from urllib.parse import unquote, urlparse

_RE_PERFIL = re.compile(r"^/in/([^/?#]+)/?$", re.IGNORECASE)
_RE_EMPRESA = re.compile(r"^/(?:company|school)/([^/?#]+)/?", re.IGNORECASE)
_RE_ID_VALIDO = re.compile(r"^[a-z0-9%_-]{3,100}$")


def sin_tildes(texto: str) -> str:
    descompuesto = unicodedata.normalize("NFKD", texto)
    return "".join(c for c in descompuesto if not unicodedata.combining(c))


def normalizar(texto: str | None) -> str:
    """Minúsculas, sin tildes, solo letras, números y espacios simples."""
    if not texto:
        return ""
    t = sin_tildes(texto).lower()
    t = re.sub(r"[^a-z0-9]+", " ", t)
    return t.strip()


def espacios(texto: str | None) -> str | None:
    """Recorta y colapsa espacios; devuelve None si queda vacío."""
    if texto is None:
        return None
    t = re.sub(r"\s+", " ", str(texto)).strip()
    return t or None


def id_publico_desde_url(url: str | None) -> str | None:
    """Extrae y normaliza el identificador público de una URL de perfil."""
    if not url:
        return None
    partes = urlparse(url.strip())
    host = (partes.hostname or "").lower()
    if not (host == "linkedin.com" or host.endswith(".linkedin.com")):
        return None
    m = _RE_PERFIL.match(partes.path)
    if not m:
        return None
    ident = unquote(m.group(1)).strip().lower()
    ident = sin_tildes(ident)
    return ident if _RE_ID_VALIDO.match(ident) else None


def id_empresa_desde_url(url: str | None) -> str | None:
    """https://www.linkedin.com/company/andes-software/ -> andes-software"""
    if not url:
        return None
    partes = urlparse(url.strip())
    host = (partes.hostname or "").lower()
    if not (host == "linkedin.com" or host.endswith(".linkedin.com")):
        return None
    m = _RE_EMPRESA.match(partes.path)
    return unquote(m.group(1)).lower() if m else None


def sha256(texto: str) -> str:
    return hashlib.sha256(texto.encode("utf-8")).hexdigest()


def huella(*partes) -> str:
    """SHA-1 de las partes normalizadas: identidad de una fila entre capturas."""
    base = "|".join(normalizar(str(p)) if p is not None else "" for p in partes)
    return hashlib.sha1(base.encode("utf-8")).hexdigest()
