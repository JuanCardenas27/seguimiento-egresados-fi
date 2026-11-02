"""Perfil canónico y lista blanca de campos (minimización de datos)."""
import json

from .texto import espacios, sha256

CAMPOS_PERFIL = ("id_publico", "urn", "nombres", "apellidos", "ubicacion", "educacion", "experiencia")
CAMPOS_EDUCACION = ("institucion", "url_institucion", "titulo", "campo", "inicio", "fin")
CAMPOS_EXPERIENCIA = (
    "cargo", "empresa", "url_empresa", "industria_empresa", "tipo_empresa",
    "tipo_empleo", "modalidad", "ubicacion", "inicio", "fin",
)


def minimizar(crudo: dict) -> dict:
    """Devuelve solo los campos permitidos, con espacios normalizados."""
    perfil = {c: espacios(crudo.get(c)) for c in CAMPOS_PERFIL if c not in ("educacion", "experiencia")}
    perfil["educacion"] = [
        {c: espacios(e.get(c)) for c in CAMPOS_EDUCACION}
        for e in (crudo.get("educacion") or [])
        if espacios(e.get("institucion"))
    ]
    perfil["experiencia"] = [
        {c: espacios(x.get(c)) for c in CAMPOS_EXPERIENCIA}
        for x in (crudo.get("experiencia") or [])
        if espacios(x.get("cargo")) and espacios(x.get("empresa"))
    ]
    return perfil


def serializar(perfil: dict) -> str:
    """JSON determinista (mismas claves y orden), base de la huella de contenido."""
    return json.dumps(perfil, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def hash_contenido(perfil: dict) -> str:
    return sha256(serializar(perfil))
