from rest_framework import serializers

from .models import Egresado, Ejecucion, ExperienciaLaboral, Formacion, IncidenciaCalidad


class FormacionSerializer(serializers.ModelSerializer):
    programa = serializers.CharField(source="programa.nombre", allow_null=True, default=None)

    class Meta:
        model = Formacion
        fields = ["institucion_original", "titulo_original", "campo_original", "es_facultad", "programa",
                  "codigo_nivel", "anio_inicio", "anio_fin", "en_curso"]


class ExperienciaSerializer(serializers.ModelSerializer):
    organizacion = serializers.CharField(source="organizacion.nombre_normalizado")
    sector_ciiu = serializers.CharField(source="organizacion.codigo_seccion_ciiu", allow_null=True)

    class Meta:
        model = ExperienciaLaboral
        fields = ["id_experiencia", "organizacion", "sector_ciiu", "cargo_original", "codigo_ciuo",
                  "codigo_nivel_cargo", "codigo_area", "tipo_vinculo", "modalidad", "fecha_inicio", "fecha_fin",
                  "es_actual", "codigo_pais", "codigo_municipio", "ciudad_extranjera", "id_captura"]


class EgresadoListaSerializer(serializers.ModelSerializer):
    programas = serializers.SerializerMethodField()

    class Meta:
        model = Egresado
        fields = ["id_egresado", "nombre_completo", "programas", "puntaje_pertenencia", "estado_verificacion",
                  "ultima_captura_en"]

    def get_programas(self, obj):
        return [f.programa.nombre for f in obj.formaciones.all() if f.es_facultad and f.vigente_en_fuente]


class EgresadoDetalleSerializer(serializers.ModelSerializer):
    formaciones = serializers.SerializerMethodField()
    experiencias = serializers.SerializerMethodField()

    class Meta:
        model = Egresado
        fields = ["id_egresado", "nombres", "apellidos", "url_perfil", "codigo_pais_residencia",
                  "codigo_municipio_residencia", "puntaje_pertenencia", "criterios_pertenencia",
                  "estado_verificacion", "metodo_verificacion", "primera_captura_en", "ultima_captura_en",
                  "formaciones", "experiencias"]

    def get_formaciones(self, obj):
        return FormacionSerializer([f for f in obj.formaciones.all() if f.vigente_en_fuente], many=True).data

    def get_experiencias(self, obj):
        return ExperienciaSerializer([x for x in obj.experiencias.all() if x.vigente_en_fuente], many=True).data


class IncidenciaSerializer(serializers.ModelSerializer):
    class Meta:
        model = IncidenciaCalidad
        fields = ["id_incidencia", "codigo_tipo", "entidad", "id_registro", "id_egresado", "descripcion",
                  "estado", "detectada_en"]


class EjecucionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Ejecucion
        fields = "__all__"
