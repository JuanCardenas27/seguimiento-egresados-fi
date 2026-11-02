from django.urls import include, path
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register("egresados", views.EgresadoViewSet, basename="egresado")
router.register("incidencias", views.IncidenciaViewSet, basename="incidencia")
router.register("ejecuciones", views.EjecucionViewSet, basename="ejecucion")

urlpatterns = [
    path("indicadores/", views.indicadores, name="indicadores"),
    path("", include(router.urls)),
]
