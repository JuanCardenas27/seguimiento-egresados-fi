from django.contrib import admin

from .models import Egresado, Ejecucion, ExperienciaLaboral, IncidenciaCalidad, Organizacion


class SoloLecturaAdmin(admin.ModelAdmin):
    """La aplicación web usa un usuario de base de datos con permiso SELECT únicamente."""

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


class ExperienciaInline(admin.TabularInline):
    model = ExperienciaLaboral
    fields = ["cargo_original", "organizacion", "codigo_nivel_cargo", "codigo_area", "fecha_inicio", "fecha_fin",
              "es_actual", "vigente_en_fuente"]
    readonly_fields = fields
    extra = 0
    can_delete = False

    def has_add_permission(self, request, obj=None):
        return False


@admin.register(Egresado)
class EgresadoAdmin(SoloLecturaAdmin):
    list_display = ["id_egresado", "nombre_completo", "puntaje_pertenencia", "estado_verificacion",
                    "estado_registro", "ultima_captura_en"]
    list_filter = ["estado_verificacion", "estado_registro"]
    search_fields = ["nombres", "apellidos"]
    inlines = [ExperienciaInline]


@admin.register(Organizacion)
class OrganizacionAdmin(SoloLecturaAdmin):
    list_display = ["nombre_normalizado", "id_linkedin_empresa", "codigo_seccion_ciiu", "codigo_tipo"]
    search_fields = ["nombre_normalizado"]


@admin.register(IncidenciaCalidad)
class IncidenciaAdmin(SoloLecturaAdmin):
    list_display = ["id_incidencia", "codigo_tipo", "entidad", "id_registro", "descripcion", "estado"]
    list_filter = ["codigo_tipo", "estado"]


@admin.register(Ejecucion)
class EjecucionAdmin(SoloLecturaAdmin):
    list_display = ["id_ejecucion", "etapa", "codigo_canal", "estado", "iniciada_en", "registros_leidos",
                    "registros_nuevos", "registros_sin_cambio", "registros_descartados", "errores"]
