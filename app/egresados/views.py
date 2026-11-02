from django.db import connections
from django.db.models import Prefetch
from rest_framework import viewsets
from rest_framework.decorators import api_view, permission_classes
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from .models import Egresado, Ejecucion, ExperienciaLaboral, Formacion, IncidenciaCalidad
from .serializers import (EgresadoDetalleSerializer, EgresadoListaSerializer, EjecucionSerializer,
                          IncidenciaSerializer)

# grupos más pequeños no se publican
TAMANO_MINIMO_CELDA = 5


def _entero(valor: str, nombre: str) -> int:
    """Parámetro numérico de la consulta; si no lo es, responde 400 en lugar de un error 500."""
    try:
        return int(valor)
    except ValueError:
        raise ValidationError({nombre: "Debe ser un número entero."}) from None


class EgresadoViewSet(viewsets.ReadOnlyModelViewSet):
    """Egresados verificados con su trayectoria (requiere autenticación)."""

    def get_queryset(self):
        qs = Egresado.objects.filter(estado_registro="ACTIVO").prefetch_related(
            Prefetch("formaciones", queryset=Formacion.objects.select_related("programa")),
            Prefetch("experiencias", queryset=ExperienciaLaboral.objects.select_related("organizacion")),
        )
        params = self.request.query_params
        qs = qs.filter(estado_verificacion=params.get("estado", "ACEPTADO"))
        # programa y cohorte se evalúan sobre la misma formación (un solo filter sobre la relación)
        filtro_formacion = {}
        if programa := params.get("programa"):
            filtro_formacion["formaciones__programa_id"] = _entero(programa, "programa")
        if cohorte := params.get("cohorte"):
            filtro_formacion["formaciones__anio_fin"] = _entero(cohorte, "cohorte")
        if filtro_formacion:
            qs = qs.filter(formaciones__es_facultad=True, formaciones__vigente_en_fuente=True, **filtro_formacion)
        return qs.distinct()

    def get_serializer_class(self):
        return EgresadoDetalleSerializer if self.action == "retrieve" else EgresadoListaSerializer


class IncidenciaViewSet(viewsets.ReadOnlyModelViewSet):
    """Incidencias de calidad. Filtros: ?estado=ABIERTA  ?tipo=DUPLICADO_POSIBLE"""

    serializer_class = IncidenciaSerializer

    def get_queryset(self):
        qs = IncidenciaCalidad.objects.all()
        if estado := self.request.query_params.get("estado"):
            qs = qs.filter(estado=estado)
        if tipo := self.request.query_params.get("tipo"):
            qs = qs.filter(codigo_tipo=tipo)
        return qs


class EjecucionViewSet(viewsets.ReadOnlyModelViewSet):
    """Bitácora del proceso automatizado."""

    queryset = Ejecucion.objects.all()
    serializer_class = EjecucionSerializer


def _consulta(sql):
    with connections["egresados"].cursor() as cur:
        cur.execute(sql)
        columnas = [c[0] for c in cur.description]
        return [dict(zip(columnas, fila)) for fila in cur.fetchall()]


def _suprimir_celdas_pequenas(filas, campo="egresados"):
    return [f if f[campo] >= TAMANO_MINIMO_CELDA else {**f, campo: f"<{TAMANO_MINIMO_CELDA}"} for f in filas]


@api_view(["GET"])
@permission_classes([AllowAny])
def indicadores(request):
    """Indicadores agregados, sin datos personales. Público, con supresión de celdas pequeñas."""
    filas = {
        "egresados_por_programa": _consulta("""
            SELECT programa, COUNT(DISTINCT id_egresado) AS egresados
              FROM v_egresado_programa GROUP BY programa ORDER BY programa"""),
        "sector_actual": _consulta("""
            SELECT COALESCE(sector_ciiu, '(sin clasificar)') AS sector, COUNT(*) AS egresados
              FROM v_situacion_actual GROUP BY sector ORDER BY egresados DESC"""),
        "nivel_actual": _consulta("""
            SELECT COALESCE(codigo_nivel_cargo, '(sin clasificar)') AS nivel, COUNT(*) AS egresados
              FROM v_situacion_actual GROUP BY nivel"""),
        "pais_actual": _consulta("""
            SELECT COALESCE(codigo_pais, '(sin dato)') AS pais, COUNT(*) AS egresados
              FROM v_situacion_actual GROUP BY pais"""),
    }
    detalle = request.query_params.get("detalle") == "1" and request.user.is_authenticated
    respuesta = {k: (v if detalle else _suprimir_celdas_pequenas(v)) for k, v in filas.items()}
    respuesta["calidad"] = _consulta("SELECT * FROM v_resumen_calidad")
    return Response(respuesta)
