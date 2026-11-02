"""Rúbrica de pertenencia a la Facultad (0 a 100).

Institución 35, programa 30, condición de egresado 20, sede 10, coherencia 5.
80 o más: aceptado; 50 a 79: revisión manual; menos de 50: descartado.
"""
import re
from dataclasses import dataclass, field
from datetime import date

from . import fechas

UMBRAL_ACEPTADO = 80
UMBRAL_REVISION = 50

DURACION_PLAUSIBLE = {  # años entre inicio y fin
    "TECNOLOGICO": (2, 5), "PREGRADO": (4, 9), "ESPECIALIZACION": (1, 3),
    "MAESTRIA": (1, 5), "DOCTORADO": (3, 8), "POSDOCTORADO": (1, 4),
}
_RE_INGENIERIA = re.compile(r"(?i)ingenier|engineer|\bing\b\.?")
# Puntaje del programa cuando el perfil no trae título ni campo (canal A) y se infiere de la consulta
PUNTAJE_PROGRAMA_INFERIDO = 20
PRIORIDAD_EXCLUSION = ("OTRA_SEDE", "ESTUDIANTE", "OTRA_FACULTAD")


@dataclass(frozen=True)
class Regla:
    patron: re.Pattern
    resultado: object
    prioridad: int


@dataclass
class Reglas:
    """Diccionarios cargados desde la base de datos (tablas regla_*)."""
    institucion: list[Regla]          # resultado: 'UNAL_PAGINA', 'OTRA_SEDE', ...
    nivel: list[Regla]                # resultado: código de nivel
    programa: list[Regla]             # resultado: (id_programa, codigo_nivel)

    @staticmethod
    def compilar(filas, convertir=lambda r: r):
        """filas: iterable de (patron_sql, resultado, prioridad)."""
        reglas = []
        for patron, resultado, prioridad in filas:
            # los patrones vienen de MariaDB; Python acepta la misma sintaxis
            reglas.append(Regla(re.compile(patron), convertir(resultado), prioridad))
        return sorted(reglas, key=lambda r: r.prioridad)

    def senales_institucion(self, texto: str) -> set[str]:
        return {r.resultado for r in self.institucion if r.patron.search(texto)}

    def nivel_de(self, titulo: str) -> str | None:
        return next((r.resultado for r in self.nivel if titulo and r.patron.search(titulo)), None)

    def programa_de(self, texto: str, nivel: str) -> int | None:
        for r in self.programa:
            id_programa, nivel_programa = r.resultado
            if nivel_programa == nivel and r.patron.search(texto):
                return id_programa
        return None


@dataclass
class EvaluacionFormacion:
    indice: int
    es_unal: bool
    id_programa: int | None = None
    codigo_nivel: str | None = None
    exclusion: str | None = None
    criterios: dict = field(default_factory=dict)

    @property
    def puntaje(self) -> int:
        return sum(self.criterios.values())


@dataclass
class Resultado:
    decision: str                 # ACEPTADO | POR_REVISAR | DESCARTADO | EXCLUIDO
    puntaje: int
    criterios: dict
    motivo: str | None
    formaciones: list[EvaluacionFormacion]


def evaluar(perfil: dict, reglas: Reglas, hoy: date, pista_programa: str | None = None) -> Resultado:
    """pista_programa: consulta del buscador que encontró el perfil. Solo se usa cuando la formación
    no trae título ni campo (la versión pública del perfil no los publica)."""
    residencia = perfil.get("ubicacion") or ""
    evaluadas: list[EvaluacionFormacion] = []

    for i, edu in enumerate(perfil.get("educacion", [])):
        texto_inst = f"{edu.get('institucion') or ''} {edu.get('url_institucion') or ''}"
        texto_prog = f"{edu.get('titulo') or ''} {edu.get('campo') or ''}"
        senales = reglas.senales_institucion(texto_inst)
        senales_formacion = senales | reglas.senales_institucion(texto_prog)

        ev = EvaluacionFormacion(indice=i, es_unal=bool(senales & {"UNAL_PAGINA", "UNAL_NOMBRE", "UNAL_AMBIGUO"}))
        nivel_titulo = reglas.nivel_de(edu.get("titulo") or "")
        ev.codigo_nivel = nivel_titulo or reglas.nivel_de(edu.get("campo") or "")
        if not ev.es_unal:
            evaluadas.append(ev)
            continue

        inicio, fin = fechas.anio(edu.get("inicio")), fechas.anio(edu.get("fin"))
        es_ingenieria = bool(_RE_INGENIERIA.search(texto_prog))
        if texto_prog.strip():
            ev.id_programa = reglas.programa_de(texto_prog, ev.codigo_nivel or "PREGRADO")
            # C2 programa: solo cuenta si el texto habla de ingeniería ("Diseño Industrial" o "Química"
            # coinciden con el patrón del programa, pero no son de la Facultad)
            ev.criterios["programa"] = (30 if ev.id_programa and es_ingenieria
                                        else 10 if es_ingenieria else 0)
            if ev.id_programa is None and not es_ingenieria:
                ev.exclusion = "OTRA_FACULTAD"
        else:
            # sin título ni campo: el programa se infiere de la consulta que encontró el perfil
            ev.id_programa = reglas.programa_de(pista_programa or "", "PREGRADO")
            ev.criterios["programa"] = PUNTAJE_PROGRAMA_INFERIDO if ev.id_programa else 0
        if ev.id_programa and ev.codigo_nivel is None:
            ev.codigo_nivel = "PREGRADO"

        # C1 institución
        ev.criterios["institucion"] = (35 if "UNAL_PAGINA" in senales
                                       else 30 if "UNAL_NOMBRE" in senales else 10)
        # C3 condición de egresado
        ev.criterios["condicion"] = (15 if fin and fin <= hoy.year else 0) + (5 if nivel_titulo else 0)
        # C4 sede
        if "OTRA_SEDE" in senales_formacion:
            ev.criterios["sede"] = 0
        elif "SEDE_BOGOTA" in senales_formacion or "SEDE_BOGOTA" in reglas.senales_institucion(residencia):
            ev.criterios["sede"] = 10
        else:
            ev.criterios["sede"] = 5
        # C5 coherencia de la duración
        rango = DURACION_PLAUSIBLE.get(ev.codigo_nivel or "")
        ev.criterios["coherencia"] = 5 if (rango and inicio and fin and rango[0] <= fin - inicio <= rango[1]) else 0

        if "OTRA_SEDE" in senales_formacion:
            ev.exclusion = "OTRA_SEDE"
        elif ev.id_programa and fin and fin > hoy.year:
            ev.exclusion = "ESTUDIANTE"
        evaluadas.append(ev)

    unal = [e for e in evaluadas if e.es_unal]
    validas = [e for e in unal if e.exclusion is None]
    if not unal:
        return Resultado("DESCARTADO", 0, {}, "SIN_FORMACION_UNAL", evaluadas)
    if not validas:
        motivos = {e.exclusion for e in unal}
        motivo = next(m for m in PRIORIDAD_EXCLUSION if m in motivos)
        return Resultado("EXCLUIDO", 0, {}, motivo, evaluadas)

    mejor = max(validas, key=lambda e: (e.puntaje, e.id_programa is not None))
    # sin programa reconocido no se acepta automáticamente
    if mejor.puntaje >= UMBRAL_ACEPTADO and mejor.id_programa is not None:
        decision = "ACEPTADO"
    elif mejor.puntaje >= UMBRAL_REVISION:
        decision = "POR_REVISAR"
    else:
        decision = "DESCARTADO"
    return Resultado(decision, mejor.puntaje, dict(mejor.criterios),
                     None if decision != "DESCARTADO" else "PUNTAJE_BAJO", evaluadas)
