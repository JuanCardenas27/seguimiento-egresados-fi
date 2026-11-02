-- Esquema de la base de datos de egresados (MariaDB 10.6 o superior).

DROP DATABASE IF EXISTS egresados_fi;
CREATE DATABASE egresados_fi
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE egresados_fi;

-- 1. Catálogos

CREATE TABLE cat_nivel_formacion (
  codigo        VARCHAR(20)  PRIMARY KEY,
  descripcion   VARCHAR(80)  NOT NULL,
  orden         TINYINT UNSIGNED NOT NULL UNIQUE
) ENGINE=InnoDB COMMENT='Niveles de formación (SNIES)';

CREATE TABLE cat_programa (
  id_programa   SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  codigo_snies  VARCHAR(10)  NULL UNIQUE COMMENT 'Código SNIES oficial del programa',
  nombre        VARCHAR(150) NOT NULL,
  codigo_nivel  VARCHAR(20)  NOT NULL,
  sede          VARCHAR(50)  NOT NULL DEFAULT 'Bogotá',
  CONSTRAINT uq_programa UNIQUE (nombre, codigo_nivel, sede),
  CONSTRAINT fk_programa_nivel FOREIGN KEY (codigo_nivel) REFERENCES cat_nivel_formacion(codigo),
  CONSTRAINT ck_programa_snies CHECK (codigo_snies IS NULL OR codigo_snies REGEXP '^[0-9]{1,10}$')
) ENGINE=InnoDB COMMENT='Programas curriculares de la Facultad';

CREATE TABLE cat_sector_ciiu (
  codigo_seccion CHAR(1)      PRIMARY KEY,
  descripcion    VARCHAR(200) NOT NULL,
  CONSTRAINT ck_ciiu_seccion CHECK (codigo_seccion REGEXP '^[A-U]$')
) ENGINE=InnoDB COMMENT='Secciones CIIU Rev. 4 A.C. (DANE)';

CREATE TABLE cat_ocupacion_ciuo (
  codigo        VARCHAR(4)   PRIMARY KEY,
  descripcion   VARCHAR(200) NOT NULL,
  nivel         TINYINT UNSIGNED NOT NULL COMMENT '1=gran grupo, 2=subgrupo principal, 4=grupo primario',
  codigo_padre  VARCHAR(4)   NULL,
  CONSTRAINT fk_ciuo_padre FOREIGN KEY (codigo_padre) REFERENCES cat_ocupacion_ciuo(codigo),
  CONSTRAINT ck_ciuo_codigo CHECK (codigo REGEXP '^[0-9]{1,4}$' AND CHAR_LENGTH(codigo) = nivel)
) ENGINE=InnoDB COMMENT='Ocupaciones CIUO-08 A.C. (DANE)';

CREATE TABLE cat_nivel_cargo (
  codigo        VARCHAR(20)  PRIMARY KEY,
  descripcion   VARCHAR(100) NOT NULL,
  orden         TINYINT UNSIGNED NOT NULL UNIQUE
) ENGINE=InnoDB COMMENT='Nivel jerárquico del cargo (ordinal)';

CREATE TABLE cat_area_desempeno (
  codigo        VARCHAR(30)  PRIMARY KEY,
  descripcion   VARCHAR(120) NOT NULL
) ENGINE=InnoDB COMMENT='Áreas funcionales de desempeño';

CREATE TABLE cat_tipo_organizacion (
  codigo        VARCHAR(20)  PRIMARY KEY,
  descripcion   VARCHAR(100) NOT NULL
) ENGINE=InnoDB COMMENT='Naturaleza de la organización';

CREATE TABLE cat_pais (
  codigo_iso2   CHAR(2)      PRIMARY KEY,
  nombre        VARCHAR(80)  NOT NULL UNIQUE,
  CONSTRAINT ck_pais_iso CHECK (codigo_iso2 REGEXP '^[A-Z]{2}$')
) ENGINE=InnoDB COMMENT='Países ISO 3166-1 alfa-2';

CREATE TABLE cat_departamento (
  codigo_dane   CHAR(2)      PRIMARY KEY,
  nombre        VARCHAR(80)  NOT NULL UNIQUE,
  CONSTRAINT ck_depto_dane CHECK (codigo_dane REGEXP '^[0-9]{2}$')
) ENGINE=InnoDB COMMENT='Departamentos DIVIPOLA';

CREATE TABLE cat_municipio (
  codigo_dane         CHAR(5)     PRIMARY KEY,
  nombre              VARCHAR(80) NOT NULL,
  codigo_departamento CHAR(2)     NOT NULL,
  CONSTRAINT fk_municipio_depto FOREIGN KEY (codigo_departamento) REFERENCES cat_departamento(codigo_dane),
  CONSTRAINT ck_municipio_dane CHECK (codigo_dane REGEXP '^[0-9]{5}$' AND LEFT(codigo_dane, 2) = codigo_departamento)
) ENGINE=InnoDB COMMENT='Municipios DIVIPOLA';

CREATE TABLE cat_canal (
  codigo        VARCHAR(30)  PRIMARY KEY,
  descripcion   VARCHAR(200) NOT NULL,
  nivel_confiabilidad TINYINT UNSIGNED NOT NULL COMMENT '1=baja, 2=media, 3=alta',
  CONSTRAINT ck_canal_conf CHECK (nivel_confiabilidad BETWEEN 1 AND 3)
) ENGINE=InnoDB COMMENT='Canales de obtención de datos de LinkedIn';

CREATE TABLE cat_tipo_incidencia (
  codigo        VARCHAR(30)  PRIMARY KEY,
  descripcion   VARCHAR(200) NOT NULL,
  severidad     ENUM('BAJA','MEDIA','ALTA') NOT NULL
) ENGINE=InnoDB COMMENT='Tipos de incidencia de calidad';

-- 2. Diccionarios de homologación

-- Variantes con las que aparece la institución en el campo "Educación"
CREATE TABLE regla_institucion (
  id_regla   SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  patron     VARCHAR(200) NOT NULL UNIQUE COMMENT 'Expresión regular sobre el nombre o la URL de la institución',
  resultado  ENUM('UNAL_PAGINA','UNAL_NOMBRE','UNAL_AMBIGUO','OTRA_SEDE','SEDE_BOGOTA') NOT NULL,
  prioridad  TINYINT UNSIGNED NOT NULL DEFAULT 50
) ENGINE=InnoDB COMMENT='Reconocimiento de la Universidad y de sus sedes';

-- Texto libre del título o del campo de estudio -> programa de la Facultad
CREATE TABLE regla_programa (
  id_regla     SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  patron       VARCHAR(200) NOT NULL,
  id_programa  SMALLINT UNSIGNED NOT NULL,
  prioridad    TINYINT UNSIGNED NOT NULL DEFAULT 50,
  CONSTRAINT uq_rprog UNIQUE (patron, id_programa),
  CONSTRAINT fk_rprog_programa FOREIGN KEY (id_programa) REFERENCES cat_programa(id_programa)
) ENGINE=InnoDB COMMENT='Homologación del programa curricular';

-- Texto del título -> nivel de formación
CREATE TABLE regla_nivel_formacion (
  id_regla     SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  patron       VARCHAR(200) NOT NULL UNIQUE,
  codigo_nivel VARCHAR(20)  NOT NULL,
  prioridad    TINYINT UNSIGNED NOT NULL DEFAULT 50,
  CONSTRAINT fk_rnivel_nivel FOREIGN KEY (codigo_nivel) REFERENCES cat_nivel_formacion(codigo)
) ENGINE=InnoDB COMMENT='Homologación del nivel de formación';

-- Cargo en texto libre -> ocupación CIUO, nivel jerárquico y área
CREATE TABLE homologacion_cargo (
  id_regla           SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  patron             VARCHAR(200) NOT NULL UNIQUE,
  codigo_ciuo        VARCHAR(4)   NULL,
  codigo_nivel_cargo VARCHAR(20)  NULL,
  codigo_area        VARCHAR(30)  NULL,
  prioridad          TINYINT UNSIGNED NOT NULL DEFAULT 50 COMMENT 'Menor número = mayor precedencia',
  CONSTRAINT fk_homol_ciuo  FOREIGN KEY (codigo_ciuo)        REFERENCES cat_ocupacion_ciuo(codigo),
  CONSTRAINT fk_homol_nivel FOREIGN KEY (codigo_nivel_cargo) REFERENCES cat_nivel_cargo(codigo),
  CONSTRAINT fk_homol_area  FOREIGN KEY (codigo_area)        REFERENCES cat_area_desempeno(codigo)
) ENGINE=InnoDB COMMENT='Homologación de cargos';

-- Industria que LinkedIn asigna a la página de la empresa -> sección CIIU
CREATE TABLE equivalencia_industria (
  industria_linkedin  VARCHAR(120) PRIMARY KEY,
  codigo_seccion_ciiu CHAR(1)      NOT NULL,
  CONSTRAINT fk_eqind_ciiu FOREIGN KEY (codigo_seccion_ciiu) REFERENCES cat_sector_ciiu(codigo_seccion)
) ENGINE=InnoDB COMMENT='Industria de LinkedIn -> CIIU Rev. 4 A.C.';

-- Tipo de empresa de LinkedIn -> naturaleza de la organización
CREATE TABLE equivalencia_tipo_empresa (
  tipo_linkedin  VARCHAR(60) PRIMARY KEY,
  codigo_tipo    VARCHAR(20) NOT NULL,
  CONSTRAINT fk_eqtipo_tipo FOREIGN KEY (codigo_tipo) REFERENCES cat_tipo_organizacion(codigo)
) ENGINE=InnoDB COMMENT='Tipo de empresa de LinkedIn -> tipo de organización';

-- Texto de ubicación (español o inglés) -> país ISO y municipio DIVIPOLA
CREATE TABLE alias_ubicacion (
  texto_normalizado VARCHAR(120) PRIMARY KEY COMMENT 'Minúsculas y sin tildes',
  codigo_pais       CHAR(2)      NOT NULL,
  codigo_municipio  CHAR(5)      NULL,
  CONSTRAINT fk_aubic_pais FOREIGN KEY (codigo_pais)      REFERENCES cat_pais(codigo_iso2),
  CONSTRAINT fk_aubic_mpio FOREIGN KEY (codigo_municipio) REFERENCES cat_municipio(codigo_dane),
  CONSTRAINT ck_aubic_co   CHECK (codigo_municipio IS NULL OR codigo_pais = 'CO')
) ENGINE=InnoDB COMMENT='Gazetteer de ubicaciones';

-- 3. Control del proceso

-- Bitácora de ejecuciones
CREATE TABLE ejecucion (
  id_ejecucion        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  etapa               ENUM('DESCUBRIMIENTO','EXTRACCION','IMPORTACION','PROCESAMIENTO','COMPLETA') NOT NULL,
  codigo_canal        VARCHAR(30)  NULL,
  version_proceso     VARCHAR(20)  NOT NULL,
  parametros          JSON         NULL,
  iniciada_en         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  finalizada_en       DATETIME     NULL,
  estado              ENUM('EN_CURSO','EXITOSA','PARCIAL','FALLIDA') NOT NULL DEFAULT 'EN_CURSO',
  registros_leidos    INT UNSIGNED NOT NULL DEFAULT 0,
  registros_nuevos    INT UNSIGNED NOT NULL DEFAULT 0,
  registros_sin_cambio INT UNSIGNED NOT NULL DEFAULT 0,
  registros_descartados INT UNSIGNED NOT NULL DEFAULT 0,
  errores             INT UNSIGNED NOT NULL DEFAULT 0,
  CONSTRAINT fk_ejec_canal FOREIGN KEY (codigo_canal) REFERENCES cat_canal(codigo),
  CONSTRAINT ck_ejec_param CHECK (parametros IS NULL OR JSON_VALID(parametros)),
  CONSTRAINT ck_ejec_fin   CHECK (finalizada_en IS NULL OR finalizada_en >= iniciada_en)
) ENGINE=InnoDB COMMENT='Bitácora de ejecuciones del proceso automatizado';

-- Perfiles encontrados en el descubrimiento. Si se descarta, solo queda el hash.
CREATE TABLE candidato (
  id_candidato         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  hash_id_publico      CHAR(64)     NOT NULL COMMENT 'SHA-256 del identificador público normalizado',
  id_publico_linkedin  VARCHAR(100) NULL     COMMENT 'Segmento /in/<id> en minúsculas; NULL si se descarta',
  consulta_origen      VARCHAR(300) NULL     COMMENT 'Consulta del buscador que lo encontró',
  id_ejecucion         INT UNSIGNED NOT NULL COMMENT 'Ejecución que lo descubrió',
  descubierto_en       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado               ENUM('PENDIENTE','EXTRAIDO','DESCARTADO','EXCLUIDO','NO_DISPONIBLE') NOT NULL DEFAULT 'PENDIENTE',
  motivo_estado        VARCHAR(60)  NULL,
  ultimo_intento_en    DATETIME     NULL,
  intentos_fallidos    TINYINT UNSIGNED NOT NULL DEFAULT 0,
  CONSTRAINT uq_candidato_hash UNIQUE (hash_id_publico),
  CONSTRAINT uq_candidato_id   UNIQUE (id_publico_linkedin),
  CONSTRAINT fk_cand_ejec FOREIGN KEY (id_ejecucion) REFERENCES ejecucion(id_ejecucion),
  CONSTRAINT ck_cand_hash CHECK (hash_id_publico REGEXP '^[0-9a-f]{64}$'),
  CONSTRAINT ck_cand_id   CHECK (id_publico_linkedin IS NULL OR id_publico_linkedin REGEXP '^[a-z0-9%_-]{3,100}$'),
  CONSTRAINT ck_cand_min  CHECK (estado NOT IN ('DESCARTADO','EXCLUIDO') OR id_publico_linkedin IS NULL),
  INDEX ix_cand_estado (estado, ultimo_intento_en)
) ENGINE=InnoDB COMMENT='Perfiles candidatos (salida del descubrimiento)';

-- Cada lectura de un perfil. El contenido se borra a los 90 días.
CREATE TABLE captura (
  id_captura      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_candidato    INT UNSIGNED NOT NULL,
  id_ejecucion    INT UNSIGNED NOT NULL,
  codigo_canal    VARCHAR(30)  NOT NULL,
  capturada_en    DATETIME     NOT NULL,
  hash_contenido  CHAR(64)     NOT NULL COMMENT 'SHA-256 del contenido normalizado: detecta cambios',
  contenido       JSON         NULL     COMMENT 'Campos de la lista blanca; NULL tras la purga',
  expira_en       DATE         NOT NULL,
  resultado       ENUM('NUEVO','CON_CAMBIOS','SIN_CAMBIOS','DESCARTADO') NOT NULL,
  procesada       BOOLEAN      NOT NULL DEFAULT FALSE COMMENT 'TRUE cuando ya se consolidó o descartó',
  CONSTRAINT fk_capt_cand  FOREIGN KEY (id_candidato) REFERENCES candidato(id_candidato),
  CONSTRAINT fk_capt_ejec  FOREIGN KEY (id_ejecucion) REFERENCES ejecucion(id_ejecucion),
  CONSTRAINT fk_capt_canal FOREIGN KEY (codigo_canal) REFERENCES cat_canal(codigo),
  CONSTRAINT ck_capt_hash  CHECK (hash_contenido REGEXP '^[0-9a-f]{64}$'),
  CONSTRAINT ck_capt_json  CHECK (contenido IS NULL OR JSON_VALID(contenido)),
  CONSTRAINT ck_capt_exp   CHECK (expira_en > CAST(capturada_en AS DATE)),
  INDEX ix_capt_cand (id_candidato, capturada_en)
) ENGINE=InnoDB COMMENT='Capturas de perfiles (trazabilidad de la fuente)';

-- Personas que pidieron no ser tratadas (solo se guarda el hash).
CREATE TABLE lista_exclusion (
  hash_id_publico  CHAR(64)     PRIMARY KEY,
  motivo           ENUM('SUPRESION','OPOSICION','REVOCATORIA') NOT NULL,
  radicado         VARCHAR(30)  NOT NULL COMMENT 'Número de la solicitud del titular',
  registrada_en    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT ck_excl_hash CHECK (hash_id_publico REGEXP '^[0-9a-f]{64}$')
) ENGINE=InnoDB COMMENT='Perfiles excluidos por solicitud del titular';

-- 4. Datos consolidados

-- Perfiles verificados como egresados de la Facultad.
CREATE TABLE egresado (
  id_egresado            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_candidato           INT UNSIGNED NOT NULL,
  id_publico_linkedin    VARCHAR(100) NOT NULL,
  urn_linkedin           VARCHAR(60)  NULL COMMENT 'Identificador interno estable del miembro, si el canal lo entrega',
  url_perfil             VARCHAR(140) AS (CONCAT('https://www.linkedin.com/in/', id_publico_linkedin)) VIRTUAL,
  nombres                VARCHAR(100) NOT NULL,
  apellidos              VARCHAR(100) NULL,
  nombre_completo        VARCHAR(201) AS (UPPER(CONCAT_WS(' ', TRIM(nombres), TRIM(apellidos)))) STORED,
  codigo_pais_residencia CHAR(2)      NULL,
  codigo_municipio_residencia CHAR(5) NULL,
  puntaje_pertenencia    TINYINT UNSIGNED NOT NULL COMMENT '0-100, rúbrica de verificación',
  criterios_pertenencia  JSON         NOT NULL COMMENT 'Puntaje obtenido en cada criterio',
  estado_verificacion    ENUM('ACEPTADO','POR_REVISAR') NOT NULL,
  metodo_verificacion    ENUM('AUTOMATICO','MANUAL') NOT NULL DEFAULT 'AUTOMATICO',
  verificado_por         VARCHAR(60)  NULL,
  estado_registro        ENUM('ACTIVO','FUSIONADO','NO_DISPONIBLE') NOT NULL DEFAULT 'ACTIVO',
  id_egresado_destino    INT UNSIGNED NULL COMMENT 'Si FUSIONADO: registro que lo reemplaza',
  id_ultima_captura      INT UNSIGNED NOT NULL,
  primera_captura_en     DATETIME     NOT NULL,
  ultima_captura_en      DATETIME     NOT NULL,
  creado_en              TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT uq_egresado_candidato UNIQUE (id_candidato),
  CONSTRAINT uq_egresado_idpublico UNIQUE (id_publico_linkedin),
  CONSTRAINT uq_egresado_urn       UNIQUE (urn_linkedin),
  CONSTRAINT fk_egr_candidato FOREIGN KEY (id_candidato)       REFERENCES candidato(id_candidato),
  CONSTRAINT fk_egr_destino   FOREIGN KEY (id_egresado_destino) REFERENCES egresado(id_egresado),
  CONSTRAINT fk_egr_captura   FOREIGN KEY (id_ultima_captura)  REFERENCES captura(id_captura),
  CONSTRAINT fk_egr_pais      FOREIGN KEY (codigo_pais_residencia)      REFERENCES cat_pais(codigo_iso2),
  CONSTRAINT fk_egr_mpio      FOREIGN KEY (codigo_municipio_residencia) REFERENCES cat_municipio(codigo_dane),
  CONSTRAINT ck_egr_idpublico CHECK (id_publico_linkedin REGEXP '^[a-z0-9%_-]{3,100}$'),
  CONSTRAINT ck_egr_puntaje   CHECK (puntaje_pertenencia <= 100),
  CONSTRAINT ck_egr_json      CHECK (JSON_VALID(criterios_pertenencia)),
  CONSTRAINT ck_egr_estado    CHECK (
        (estado_verificacion = 'ACEPTADO'    AND (puntaje_pertenencia >= 80 OR metodo_verificacion = 'MANUAL')) OR
        (estado_verificacion = 'POR_REVISAR' AND puntaje_pertenencia >= 50)),
  CONSTRAINT ck_egr_manual    CHECK (metodo_verificacion = 'AUTOMATICO' OR verificado_por IS NOT NULL),
  CONSTRAINT ck_egr_fusion    CHECK ((estado_registro = 'FUSIONADO') = (id_egresado_destino IS NOT NULL)),
  CONSTRAINT ck_egr_geo       CHECK (codigo_municipio_residencia IS NULL OR codigo_pais_residencia = 'CO'),
  CONSTRAINT ck_egr_fechas    CHECK (ultima_captura_en >= primera_captura_en),
  INDEX ix_egr_nombre (nombre_completo),
  INDEX ix_egr_estado (estado_verificacion, estado_registro)
) ENGINE=InnoDB COMMENT='Egresados identificados y verificados';

-- Formación del perfil. La huella evita duplicarla entre capturas.
CREATE TABLE formacion (
  id_formacion        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_egresado         INT UNSIGNED NOT NULL,
  id_captura          INT UNSIGNED NOT NULL COMMENT 'Captura que respalda el dato',
  huella              CHAR(40)     NOT NULL,
  institucion_original VARCHAR(200) NOT NULL,
  titulo_original     VARCHAR(200) NULL,
  campo_original      VARCHAR(200) NULL,
  es_facultad         BOOLEAN      NOT NULL DEFAULT FALSE COMMENT 'Programa de la Facultad de Ingeniería',
  id_programa         SMALLINT UNSIGNED NULL,
  codigo_nivel        VARCHAR(20)  NULL,
  anio_inicio         SMALLINT UNSIGNED NULL,
  anio_fin            SMALLINT UNSIGNED NULL COMMENT 'Año de finalización declarado (aproxima la cohorte)',
  en_curso            BOOLEAN      NOT NULL DEFAULT FALSE,
  vigente_en_fuente   BOOLEAN      NOT NULL DEFAULT TRUE COMMENT 'FALSE si desapareció del perfil',
  version_desde       TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'Inicio de la versión vigente',
  CONSTRAINT uq_formacion_huella UNIQUE (id_egresado, huella),
  CONSTRAINT fk_form_egresado FOREIGN KEY (id_egresado)  REFERENCES egresado(id_egresado),
  CONSTRAINT fk_form_captura  FOREIGN KEY (id_captura)   REFERENCES captura(id_captura),
  CONSTRAINT fk_form_programa FOREIGN KEY (id_programa)  REFERENCES cat_programa(id_programa),
  CONSTRAINT fk_form_nivel    FOREIGN KEY (codigo_nivel) REFERENCES cat_nivel_formacion(codigo),
  CONSTRAINT ck_form_facultad CHECK (es_facultad = (id_programa IS NOT NULL)),
  CONSTRAINT ck_form_anios    CHECK (anio_inicio IS NULL OR anio_fin IS NULL OR anio_fin >= anio_inicio),
  CONSTRAINT ck_form_rango    CHECK ((anio_inicio IS NULL OR anio_inicio BETWEEN 1940 AND 2100)
                                 AND (anio_fin    IS NULL OR anio_fin    BETWEEN 1940 AND 2100)),
  CONSTRAINT ck_form_huella   CHECK (huella REGEXP '^[0-9a-f]{40}$')
) ENGINE=InnoDB COMMENT='Formación académica declarada (versiones anteriores en historial_cambio)';

CREATE TABLE organizacion (
  id_organizacion       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre_normalizado    VARCHAR(200) NOT NULL,
  id_linkedin_empresa   VARCHAR(100) NULL COMMENT 'Segmento /company/<id> de la página de la empresa',
  industria_linkedin    VARCHAR(120) NULL,
  codigo_seccion_ciiu   CHAR(1)      NULL,
  codigo_tipo           VARCHAR(20)  NULL,
  CONSTRAINT uq_org_nombre   UNIQUE (nombre_normalizado),
  CONSTRAINT uq_org_linkedin UNIQUE (id_linkedin_empresa),
  CONSTRAINT fk_org_ciiu FOREIGN KEY (codigo_seccion_ciiu) REFERENCES cat_sector_ciiu(codigo_seccion),
  CONSTRAINT fk_org_tipo FOREIGN KEY (codigo_tipo)         REFERENCES cat_tipo_organizacion(codigo),
  CONSTRAINT ck_org_linkedin CHECK (id_linkedin_empresa IS NULL OR id_linkedin_empresa REGEXP '^[a-z0-9%_-]{2,100}$')
) ENGINE=InnoDB COMMENT='Organizaciones empleadoras normalizadas';

CREATE TABLE organizacion_alias (
  alias            VARCHAR(200) PRIMARY KEY,
  id_organizacion  INT UNSIGNED NOT NULL,
  CONSTRAINT fk_alias_org FOREIGN KEY (id_organizacion) REFERENCES organizacion(id_organizacion)
) ENGINE=InnoDB COMMENT='Variantes del nombre -> organización normalizada';

-- Experiencia laboral, una fila por cargo.
CREATE TABLE experiencia_laboral (
  id_experiencia     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_egresado        INT UNSIGNED NOT NULL,
  id_organizacion    INT UNSIGNED NOT NULL,
  id_captura         INT UNSIGNED NOT NULL COMMENT 'Captura que respalda el dato',
  huella             CHAR(40)     NOT NULL,
  cargo_original     VARCHAR(200) NOT NULL COMMENT 'Texto literal de LinkedIn',
  codigo_ciuo        VARCHAR(4)   NULL,
  codigo_nivel_cargo VARCHAR(20)  NULL,
  codigo_area        VARCHAR(30)  NULL,
  metodo_clasificacion ENUM('AUTOMATICA','MANUAL') NOT NULL DEFAULT 'AUTOMATICA',
  tipo_vinculo       ENUM('TIEMPO_COMPLETO','MEDIO_TIEMPO','CONTRATO','INDEPENDIENTE','PRACTICA','EMPRENDIMIENTO','NO_INFORMADO') NOT NULL DEFAULT 'NO_INFORMADO',
  modalidad          ENUM('PRESENCIAL','REMOTO','HIBRIDO','NO_INFORMADO') NOT NULL DEFAULT 'NO_INFORMADO',
  fecha_inicio       DATE         NOT NULL COMMENT 'Con precisión MES o ANIO se registra el día 1 (y el mes 1)',
  precision_inicio   ENUM('MES','ANIO') NOT NULL,
  fecha_fin          DATE         NULL,
  precision_fin      ENUM('MES','ANIO') NULL,
  es_actual          BOOLEAN      NOT NULL DEFAULT FALSE,
  ubicacion_original VARCHAR(150) NULL,
  codigo_pais        CHAR(2)      NULL,
  codigo_municipio   CHAR(5)      NULL COMMENT 'Solo si codigo_pais = CO',
  ciudad_extranjera  VARCHAR(100) NULL COMMENT 'Solo si codigo_pais <> CO',
  vigente_en_fuente  BOOLEAN      NOT NULL DEFAULT TRUE COMMENT 'FALSE si desapareció del perfil',
  version_desde      TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'Inicio de la versión vigente',
  CONSTRAINT uq_exp_huella   UNIQUE (id_egresado, huella),
  CONSTRAINT fk_exp_egresado FOREIGN KEY (id_egresado)        REFERENCES egresado(id_egresado),
  CONSTRAINT fk_exp_org      FOREIGN KEY (id_organizacion)    REFERENCES organizacion(id_organizacion),
  CONSTRAINT fk_exp_captura  FOREIGN KEY (id_captura)         REFERENCES captura(id_captura),
  CONSTRAINT fk_exp_ciuo     FOREIGN KEY (codigo_ciuo)        REFERENCES cat_ocupacion_ciuo(codigo),
  CONSTRAINT fk_exp_nivel    FOREIGN KEY (codigo_nivel_cargo) REFERENCES cat_nivel_cargo(codigo),
  CONSTRAINT fk_exp_area     FOREIGN KEY (codigo_area)        REFERENCES cat_area_desempeno(codigo),
  CONSTRAINT fk_exp_pais     FOREIGN KEY (codigo_pais)        REFERENCES cat_pais(codigo_iso2),
  CONSTRAINT fk_exp_mpio     FOREIGN KEY (codigo_municipio)   REFERENCES cat_municipio(codigo_dane),
  CONSTRAINT ck_exp_fechas   CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio),
  CONSTRAINT ck_exp_actual   CHECK (NOT (es_actual AND fecha_fin IS NOT NULL)),
  CONSTRAINT ck_exp_prec_fin CHECK ((fecha_fin IS NULL) = (precision_fin IS NULL)),
  CONSTRAINT ck_exp_geo_co   CHECK (codigo_municipio IS NULL OR codigo_pais = 'CO'),
  CONSTRAINT ck_exp_geo_ext  CHECK (ciudad_extranjera IS NULL OR (codigo_pais IS NOT NULL AND codigo_pais <> 'CO')),
  CONSTRAINT ck_exp_huella   CHECK (huella REGEXP '^[0-9a-f]{40}$'),
  INDEX ix_exp_actual (id_egresado, es_actual)
) ENGINE=InnoDB COMMENT='Experiencias laborales consolidadas (versiones anteriores en historial_cambio)';

-- Versiones anteriores de formación y experiencia. Se usa una tabla propia en lugar de SYSTEM VERSIONING
-- porque MariaDB no permite borrar el historial de filas concretas, y la supresión (Ley 1581) lo exige.
CREATE TABLE historial_cambio (
  id_historial     BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  tabla            ENUM('formacion','experiencia_laboral') NOT NULL,
  id_registro      INT UNSIGNED NOT NULL COMMENT 'id_formacion o id_experiencia',
  id_egresado      INT UNSIGNED NOT NULL COMMENT 'Egresado al que pertenecía la versión',
  operacion        ENUM('UPDATE','DELETE') NOT NULL,
  version_anterior JSON         NOT NULL,
  vigente_desde    TIMESTAMP(6) NOT NULL,
  vigente_hasta    TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT ck_hist_json CHECK (JSON_VALID(version_anterior)),
  INDEX ix_hist_registro (tabla, id_registro, vigente_desde),
  INDEX ix_hist_egresado (id_egresado),
  INDEX ix_hist_fecha (vigente_hasta)
) ENGINE=InnoDB COMMENT='Historial de versiones (trazabilidad)';

-- 5. Calidad

CREATE TABLE incidencia_calidad (
  id_incidencia  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  codigo_tipo    VARCHAR(30)  NOT NULL,
  entidad        VARCHAR(40)  NOT NULL COMMENT 'Tabla afectada',
  id_registro    INT UNSIGNED NOT NULL COMMENT 'Llave del registro afectado',
  clave          VARCHAR(60)  NOT NULL DEFAULT '' COMMENT 'Distingue incidencias del mismo tipo sobre el mismo registro',
  id_egresado    INT UNSIGNED NULL,
  descripcion    VARCHAR(500) NOT NULL,
  estado         ENUM('ABIERTA','EN_REVISION','RESUELTA','DESCARTADA') NOT NULL DEFAULT 'ABIERTA',
  detectada_en   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  resuelta_en    TIMESTAMP    NULL,
  resuelta_por   VARCHAR(60)  NULL,
  CONSTRAINT uq_incidencia UNIQUE (codigo_tipo, entidad, id_registro, clave),
  CONSTRAINT fk_inc_tipo     FOREIGN KEY (codigo_tipo) REFERENCES cat_tipo_incidencia(codigo),
  CONSTRAINT fk_inc_egresado FOREIGN KEY (id_egresado) REFERENCES egresado(id_egresado) ON DELETE SET NULL,
  CONSTRAINT ck_inc_cierre   CHECK (estado NOT IN ('RESUELTA','DESCARTADA') OR resuelta_por IS NOT NULL),
  INDEX ix_inc_estado (estado, codigo_tipo)
) ENGINE=InnoDB COMMENT='Incidencias de calidad de datos';

-- 6. Triggers
DELIMITER $$

-- Fotografía de una versión (JSON) para el historial; también sirve para saber si la fila cambió
CREATE FUNCTION fn_version_formacion(p_id_egresado INT UNSIGNED, p_id_captura INT UNSIGNED, p_huella CHAR(40),
    p_institucion VARCHAR(200), p_titulo VARCHAR(200), p_campo VARCHAR(200), p_es_facultad BOOLEAN,
    p_id_programa SMALLINT UNSIGNED, p_codigo_nivel VARCHAR(20), p_anio_inicio SMALLINT UNSIGNED,
    p_anio_fin SMALLINT UNSIGNED, p_en_curso BOOLEAN, p_vigente BOOLEAN)
RETURNS LONGTEXT DETERMINISTIC NO SQL
RETURN JSON_OBJECT('id_egresado', p_id_egresado, 'id_captura', p_id_captura, 'huella', p_huella,
                   'institucion_original', p_institucion, 'titulo_original', p_titulo, 'campo_original', p_campo,
                   'es_facultad', p_es_facultad, 'id_programa', p_id_programa, 'codigo_nivel', p_codigo_nivel,
                   'anio_inicio', p_anio_inicio, 'anio_fin', p_anio_fin, 'en_curso', p_en_curso,
                   'vigente_en_fuente', p_vigente)$$

CREATE FUNCTION fn_version_experiencia(p_id_egresado INT UNSIGNED, p_id_organizacion INT UNSIGNED,
    p_id_captura INT UNSIGNED, p_huella CHAR(40), p_cargo VARCHAR(200), p_ciuo VARCHAR(4), p_nivel VARCHAR(20),
    p_area VARCHAR(30), p_metodo VARCHAR(20), p_vinculo VARCHAR(20), p_modalidad VARCHAR(20), p_inicio DATE,
    p_prec_inicio VARCHAR(4), p_fin DATE, p_prec_fin VARCHAR(4), p_actual BOOLEAN, p_ubicacion VARCHAR(150),
    p_pais CHAR(2), p_municipio CHAR(5), p_ciudad VARCHAR(100), p_vigente BOOLEAN)
RETURNS LONGTEXT DETERMINISTIC NO SQL
RETURN JSON_OBJECT('id_egresado', p_id_egresado, 'id_organizacion', p_id_organizacion, 'id_captura', p_id_captura,
                   'huella', p_huella, 'cargo_original', p_cargo, 'codigo_ciuo', p_ciuo,
                   'codigo_nivel_cargo', p_nivel, 'codigo_area', p_area, 'metodo_clasificacion', p_metodo,
                   'tipo_vinculo', p_vinculo, 'modalidad', p_modalidad, 'fecha_inicio', p_inicio,
                   'precision_inicio', p_prec_inicio, 'fecha_fin', p_fin, 'precision_fin', p_prec_fin,
                   'es_actual', p_actual, 'ubicacion_original', p_ubicacion, 'codigo_pais', p_pais,
                   'codigo_municipio', p_municipio, 'ciudad_extranjera', p_ciudad, 'vigente_en_fuente', p_vigente)$$

-- No capturar perfiles de la lista de exclusión
CREATE TRIGGER trg_captura_validar_bi BEFORE INSERT ON captura
FOR EACH ROW
BEGIN
  IF NEW.capturada_en > NOW() THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'captura: fecha de captura futura';
  END IF;
  IF EXISTS (SELECT 1 FROM lista_exclusion l JOIN candidato c ON c.hash_id_publico = l.hash_id_publico
              WHERE c.id_candidato = NEW.id_candidato) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'captura: el titular está en la lista de exclusión';
  END IF;
END$$

CREATE TRIGGER trg_exp_validar_bi BEFORE INSERT ON experiencia_laboral
FOR EACH ROW
BEGIN
  IF NEW.fecha_inicio > CURDATE() OR (NEW.fecha_fin IS NOT NULL AND NEW.fecha_fin > CURDATE()) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'experiencia_laboral: fechas futuras no permitidas';
  END IF;
  IF (SELECT k.id_candidato FROM captura k WHERE k.id_captura = NEW.id_captura)
     <> (SELECT e.id_candidato FROM egresado e WHERE e.id_egresado = NEW.id_egresado) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'experiencia_laboral: la captura pertenece a otro perfil';
  END IF;
END$$

CREATE TRIGGER trg_exp_validar_bu BEFORE UPDATE ON experiencia_laboral
FOR EACH ROW
BEGIN
  IF NEW.fecha_inicio > CURDATE() OR (NEW.fecha_fin IS NOT NULL AND NEW.fecha_fin > CURDATE()) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'experiencia_laboral: fechas futuras no permitidas';
  END IF;
  IF BINARY fn_version_experiencia(OLD.id_egresado, OLD.id_organizacion, OLD.id_captura, OLD.huella, OLD.cargo_original,
        OLD.codigo_ciuo, OLD.codigo_nivel_cargo, OLD.codigo_area, OLD.metodo_clasificacion, OLD.tipo_vinculo,
        OLD.modalidad, OLD.fecha_inicio, OLD.precision_inicio, OLD.fecha_fin, OLD.precision_fin, OLD.es_actual,
        OLD.ubicacion_original, OLD.codigo_pais, OLD.codigo_municipio, OLD.ciudad_extranjera, OLD.vigente_en_fuente)
     <> BINARY fn_version_experiencia(NEW.id_egresado, NEW.id_organizacion, NEW.id_captura, NEW.huella, NEW.cargo_original,
        NEW.codigo_ciuo, NEW.codigo_nivel_cargo, NEW.codigo_area, NEW.metodo_clasificacion, NEW.tipo_vinculo,
        NEW.modalidad, NEW.fecha_inicio, NEW.precision_inicio, NEW.fecha_fin, NEW.precision_fin, NEW.es_actual,
        NEW.ubicacion_original, NEW.codigo_pais, NEW.codigo_municipio, NEW.ciudad_extranjera, NEW.vigente_en_fuente) THEN
    -- la versión anterior pasa al historial
    INSERT INTO historial_cambio (tabla, id_registro, id_egresado, operacion, version_anterior, vigente_desde)
    VALUES ('experiencia_laboral', OLD.id_experiencia, OLD.id_egresado, 'UPDATE',
            fn_version_experiencia(OLD.id_egresado, OLD.id_organizacion, OLD.id_captura, OLD.huella, OLD.cargo_original,
              OLD.codigo_ciuo, OLD.codigo_nivel_cargo, OLD.codigo_area, OLD.metodo_clasificacion, OLD.tipo_vinculo,
              OLD.modalidad, OLD.fecha_inicio, OLD.precision_inicio, OLD.fecha_fin, OLD.precision_fin, OLD.es_actual,
              OLD.ubicacion_original, OLD.codigo_pais, OLD.codigo_municipio, OLD.ciudad_extranjera, OLD.vigente_en_fuente),
            OLD.version_desde);
    SET NEW.version_desde = CURRENT_TIMESTAMP(6);
  END IF;
END$$

CREATE TRIGGER trg_exp_historial_ad AFTER DELETE ON experiencia_laboral
FOR EACH ROW
BEGIN
  INSERT INTO historial_cambio (tabla, id_registro, id_egresado, operacion, version_anterior, vigente_desde)
  VALUES ('experiencia_laboral', OLD.id_experiencia, OLD.id_egresado, 'DELETE',
          fn_version_experiencia(OLD.id_egresado, OLD.id_organizacion, OLD.id_captura, OLD.huella, OLD.cargo_original,
            OLD.codigo_ciuo, OLD.codigo_nivel_cargo, OLD.codigo_area, OLD.metodo_clasificacion, OLD.tipo_vinculo,
            OLD.modalidad, OLD.fecha_inicio, OLD.precision_inicio, OLD.fecha_fin, OLD.precision_fin, OLD.es_actual,
            OLD.ubicacion_original, OLD.codigo_pais, OLD.codigo_municipio, OLD.ciudad_extranjera, OLD.vigente_en_fuente),
          OLD.version_desde);
END$$

CREATE TRIGGER trg_form_historial_bu BEFORE UPDATE ON formacion
FOR EACH ROW
BEGIN
  IF BINARY fn_version_formacion(OLD.id_egresado, OLD.id_captura, OLD.huella, OLD.institucion_original, OLD.titulo_original,
        OLD.campo_original, OLD.es_facultad, OLD.id_programa, OLD.codigo_nivel, OLD.anio_inicio, OLD.anio_fin,
        OLD.en_curso, OLD.vigente_en_fuente)
     <> BINARY fn_version_formacion(NEW.id_egresado, NEW.id_captura, NEW.huella, NEW.institucion_original, NEW.titulo_original,
        NEW.campo_original, NEW.es_facultad, NEW.id_programa, NEW.codigo_nivel, NEW.anio_inicio, NEW.anio_fin,
        NEW.en_curso, NEW.vigente_en_fuente) THEN
    INSERT INTO historial_cambio (tabla, id_registro, id_egresado, operacion, version_anterior, vigente_desde)
    VALUES ('formacion', OLD.id_formacion, OLD.id_egresado, 'UPDATE',
            fn_version_formacion(OLD.id_egresado, OLD.id_captura, OLD.huella, OLD.institucion_original, OLD.titulo_original,
              OLD.campo_original, OLD.es_facultad, OLD.id_programa, OLD.codigo_nivel, OLD.anio_inicio, OLD.anio_fin,
              OLD.en_curso, OLD.vigente_en_fuente),
            OLD.version_desde);
    SET NEW.version_desde = CURRENT_TIMESTAMP(6);
  END IF;
END$$

CREATE TRIGGER trg_form_historial_ad AFTER DELETE ON formacion
FOR EACH ROW
BEGIN
  INSERT INTO historial_cambio (tabla, id_registro, id_egresado, operacion, version_anterior, vigente_desde)
  VALUES ('formacion', OLD.id_formacion, OLD.id_egresado, 'DELETE',
          fn_version_formacion(OLD.id_egresado, OLD.id_captura, OLD.huella, OLD.institucion_original, OLD.titulo_original,
            OLD.campo_original, OLD.es_facultad, OLD.id_programa, OLD.codigo_nivel, OLD.anio_inicio, OLD.anio_fin,
            OLD.en_curso, OLD.vigente_en_fuente),
          OLD.version_desde);
END$$

CREATE TRIGGER trg_form_validar_bi BEFORE INSERT ON formacion
FOR EACH ROW
BEGIN
  IF NEW.es_facultad AND NOT NEW.en_curso AND NEW.anio_fin > YEAR(CURDATE()) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'formacion: título de la Facultad con año de finalización futuro';
  END IF;
  IF (SELECT k.id_candidato FROM captura k WHERE k.id_captura = NEW.id_captura)
     <> (SELECT e.id_candidato FROM egresado e WHERE e.id_egresado = NEW.id_egresado) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'formacion: la captura pertenece a otro perfil';
  END IF;
END$$

DELIMITER ;

-- 7. Purga de capturas vencidas (requiere event_scheduler=ON)
CREATE EVENT ev_purgar_capturas
  ON SCHEDULE EVERY 1 DAY STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 2 HOUR)
  COMMENT 'Elimina el contenido de las capturas vencidas'
  DO UPDATE captura SET contenido = NULL WHERE expira_en <= CURDATE() AND contenido IS NOT NULL;

-- 8. Depuración del historial: se conservan como máximo cinco años
CREATE EVENT ev_purgar_historial
  ON SCHEDULE EVERY 1 MONTH STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 3 HOUR)
  COMMENT 'Elimina las versiones con más de cinco años'
  DO DELETE FROM historial_cambio WHERE vigente_hasta < NOW() - INTERVAL 5 YEAR;
