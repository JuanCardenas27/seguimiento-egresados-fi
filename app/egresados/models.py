"""Modelos de solo lectura sobre el esquema de MariaDB (db/01_esquema.sql)."""
from django.db import models


class Programa(models.Model):
    id_programa = models.SmallAutoField(primary_key=True)
    nombre = models.CharField(max_length=150)
    codigo_nivel = models.CharField(max_length=20)
    sede = models.CharField(max_length=50)

    class Meta:
        managed = False
        db_table = "cat_programa"

    def __str__(self):
        return self.nombre


class Organizacion(models.Model):
    id_organizacion = models.AutoField(primary_key=True)
    nombre_normalizado = models.CharField(max_length=200)
    id_linkedin_empresa = models.CharField(max_length=100, null=True)
    industria_linkedin = models.CharField(max_length=120, null=True)
    codigo_seccion_ciiu = models.CharField(max_length=1, null=True)
    codigo_tipo = models.CharField(max_length=20, null=True)

    class Meta:
        managed = False
        db_table = "organizacion"

    def __str__(self):
        return self.nombre_normalizado


class Egresado(models.Model):
    id_egresado = models.AutoField(primary_key=True)
    id_publico_linkedin = models.CharField(max_length=100)
    nombres = models.CharField(max_length=100)
    apellidos = models.CharField(max_length=100, null=True)
    nombre_completo = models.CharField(max_length=201)
    codigo_pais_residencia = models.CharField(max_length=2, null=True)
    codigo_municipio_residencia = models.CharField(max_length=5, null=True)
    puntaje_pertenencia = models.PositiveSmallIntegerField()
    criterios_pertenencia = models.JSONField()
    estado_verificacion = models.CharField(max_length=12)
    metodo_verificacion = models.CharField(max_length=10)
    estado_registro = models.CharField(max_length=13)
    primera_captura_en = models.DateTimeField()
    ultima_captura_en = models.DateTimeField()

    class Meta:
        managed = False
        db_table = "egresado"
        ordering = ["id_egresado"]

    @property
    def url_perfil(self):
        return f"https://www.linkedin.com/in/{self.id_publico_linkedin}"

    def __str__(self):
        return self.nombre_completo


class Formacion(models.Model):
    id_formacion = models.AutoField(primary_key=True)
    egresado = models.ForeignKey(Egresado, models.DO_NOTHING, db_column="id_egresado", related_name="formaciones")
    institucion_original = models.CharField(max_length=200)
    titulo_original = models.CharField(max_length=200, null=True)
    campo_original = models.CharField(max_length=200, null=True)
    es_facultad = models.BooleanField()
    programa = models.ForeignKey(Programa, models.DO_NOTHING, db_column="id_programa", null=True)
    codigo_nivel = models.CharField(max_length=20, null=True)
    anio_inicio = models.PositiveSmallIntegerField(null=True)
    anio_fin = models.PositiveSmallIntegerField(null=True)
    en_curso = models.BooleanField()
    vigente_en_fuente = models.BooleanField()

    class Meta:
        managed = False
        db_table = "formacion"
        ordering = ["anio_inicio"]


class ExperienciaLaboral(models.Model):
    id_experiencia = models.AutoField(primary_key=True)
    egresado = models.ForeignKey(Egresado, models.DO_NOTHING, db_column="id_egresado", related_name="experiencias")
    organizacion = models.ForeignKey(Organizacion, models.DO_NOTHING, db_column="id_organizacion")
    id_captura = models.PositiveIntegerField()
    cargo_original = models.CharField(max_length=200)
    codigo_ciuo = models.CharField(max_length=4, null=True)
    codigo_nivel_cargo = models.CharField(max_length=20, null=True)
    codigo_area = models.CharField(max_length=30, null=True)
    metodo_clasificacion = models.CharField(max_length=10)
    tipo_vinculo = models.CharField(max_length=20)
    modalidad = models.CharField(max_length=12)
    fecha_inicio = models.DateField()
    fecha_fin = models.DateField(null=True)
    es_actual = models.BooleanField()
    codigo_pais = models.CharField(max_length=2, null=True)
    codigo_municipio = models.CharField(max_length=5, null=True)
    ciudad_extranjera = models.CharField(max_length=100, null=True)
    vigente_en_fuente = models.BooleanField()

    class Meta:
        managed = False
        db_table = "experiencia_laboral"
        ordering = ["-fecha_inicio"]


class IncidenciaCalidad(models.Model):
    id_incidencia = models.AutoField(primary_key=True)
    codigo_tipo = models.CharField(max_length=30)
    entidad = models.CharField(max_length=40)
    id_registro = models.PositiveIntegerField()
    id_egresado = models.PositiveIntegerField(null=True)
    descripcion = models.CharField(max_length=500)
    estado = models.CharField(max_length=12)
    detectada_en = models.DateTimeField()
    resuelta_en = models.DateTimeField(null=True)
    resuelta_por = models.CharField(max_length=60, null=True)

    class Meta:
        managed = False
        db_table = "incidencia_calidad"
        ordering = ["id_incidencia"]


class Ejecucion(models.Model):
    id_ejecucion = models.AutoField(primary_key=True)
    etapa = models.CharField(max_length=15)
    codigo_canal = models.CharField(max_length=30, null=True)
    version_proceso = models.CharField(max_length=20)
    iniciada_en = models.DateTimeField()
    finalizada_en = models.DateTimeField(null=True)
    estado = models.CharField(max_length=10)
    registros_leidos = models.PositiveIntegerField()
    registros_nuevos = models.PositiveIntegerField()
    registros_sin_cambio = models.PositiveIntegerField()
    registros_descartados = models.PositiveIntegerField()
    errores = models.PositiveIntegerField()

    class Meta:
        managed = False
        db_table = "ejecucion"
        ordering = ["-id_ejecucion"]
