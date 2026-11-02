#!/bin/bash
# Roles y usuarios con mínimo privilegio. Las contraseñas vienen del entorno.
set -euo pipefail

mariadb --protocol=socket -uroot -p"${MARIADB_ROOT_PASSWORD}" <<-EOSQL
  CREATE ROLE IF NOT EXISTS rol_proceso;
  GRANT SELECT ON egresados_fi.* TO rol_proceso;
  GRANT INSERT, UPDATE ON egresados_fi.ejecucion           TO rol_proceso;
  GRANT INSERT, UPDATE ON egresados_fi.candidato           TO rol_proceso;
  GRANT INSERT, UPDATE ON egresados_fi.captura             TO rol_proceso;
  GRANT INSERT, UPDATE ON egresados_fi.egresado            TO rol_proceso;
  GRANT INSERT, UPDATE ON egresados_fi.formacion           TO rol_proceso;
  GRANT INSERT, UPDATE ON egresados_fi.organizacion        TO rol_proceso;
  GRANT INSERT, UPDATE ON egresados_fi.organizacion_alias  TO rol_proceso;
  GRANT INSERT, UPDATE ON egresados_fi.experiencia_laboral TO rol_proceso;
  GRANT INSERT, UPDATE ON egresados_fi.incidencia_calidad  TO rol_proceso;
  GRANT EXECUTE ON PROCEDURE egresados_fi.sp_homologar_cargos     TO rol_proceso;
  GRANT EXECUTE ON PROCEDURE egresados_fi.sp_detectar_incidencias TO rol_proceso;

  CREATE ROLE IF NOT EXISTS rol_analista;
  GRANT SELECT ON egresados_fi.* TO rol_analista;
  GRANT UPDATE ON egresados_fi.egresado            TO rol_analista;
  GRANT UPDATE ON egresados_fi.experiencia_laboral TO rol_analista;
  GRANT UPDATE ON egresados_fi.organizacion        TO rol_analista;
  GRANT UPDATE ON egresados_fi.incidencia_calidad  TO rol_analista;
  GRANT INSERT, UPDATE ON egresados_fi.homologacion_cargo        TO rol_analista;
  GRANT INSERT, UPDATE ON egresados_fi.regla_programa            TO rol_analista;
  GRANT INSERT, UPDATE ON egresados_fi.regla_institucion         TO rol_analista;
  GRANT INSERT, UPDATE ON egresados_fi.equivalencia_industria    TO rol_analista;
  GRANT INSERT, UPDATE ON egresados_fi.alias_ubicacion           TO rol_analista;
  GRANT INSERT, UPDATE ON egresados_fi.organizacion_alias        TO rol_analista;
  GRANT EXECUTE ON PROCEDURE egresados_fi.sp_fusionar_egresados   TO rol_analista;
  GRANT EXECUTE ON PROCEDURE egresados_fi.sp_homologar_cargos     TO rol_analista;
  GRANT EXECUTE ON PROCEDURE egresados_fi.sp_detectar_incidencias TO rol_analista;

  CREATE ROLE IF NOT EXISTS rol_oficial_datos;
  GRANT SELECT ON egresados_fi.egresado        TO rol_oficial_datos;
  GRANT SELECT ON egresados_fi.lista_exclusion TO rol_oficial_datos;
  GRANT EXECUTE ON PROCEDURE egresados_fi.sp_suprimir_egresado TO rol_oficial_datos;

  CREATE ROLE IF NOT EXISTS rol_consulta;
  GRANT SELECT ON egresados_fi.v_egresado_programa TO rol_consulta;
  GRANT SELECT ON egresados_fi.v_trayectoria       TO rol_consulta;
  GRANT SELECT ON egresados_fi.v_situacion_actual  TO rol_consulta;
  GRANT SELECT ON egresados_fi.v_resumen_calidad   TO rol_consulta;

  CREATE USER IF NOT EXISTS 'proceso'@'%' IDENTIFIED BY '${PROCESO_DB_PASSWORD:-proceso_dev}';
  GRANT rol_proceso TO 'proceso'@'%';
  SET DEFAULT ROLE rol_proceso FOR 'proceso'@'%';

  CREATE USER IF NOT EXISTS 'analista'@'%' IDENTIFIED BY '${ANALISTA_DB_PASSWORD:-analista_dev}';
  GRANT rol_analista TO 'analista'@'%';
  SET DEFAULT ROLE rol_analista FOR 'analista'@'%';

  CREATE USER IF NOT EXISTS 'oficial_datos'@'%' IDENTIFIED BY '${OFICIAL_DB_PASSWORD:-oficial_dev}';
  GRANT rol_oficial_datos TO 'oficial_datos'@'%';
  SET DEFAULT ROLE rol_oficial_datos FOR 'oficial_datos'@'%';

  -- usuario de la API: solo lectura
  CREATE USER IF NOT EXISTS 'api_lectura'@'%' IDENTIFIED BY '${API_DB_PASSWORD:-api_lectura_dev}';
  GRANT SELECT ON egresados_fi.* TO 'api_lectura'@'%';
  REVOKE SELECT ON egresados_fi.* FROM 'api_lectura'@'%';
  GRANT SELECT ON egresados_fi.egresado            TO 'api_lectura'@'%';
  GRANT SELECT ON egresados_fi.formacion           TO 'api_lectura'@'%';
  GRANT SELECT ON egresados_fi.experiencia_laboral TO 'api_lectura'@'%';
  GRANT SELECT ON egresados_fi.organizacion        TO 'api_lectura'@'%';
  GRANT SELECT ON egresados_fi.incidencia_calidad  TO 'api_lectura'@'%';
  GRANT SELECT ON egresados_fi.ejecucion           TO 'api_lectura'@'%';
  GRANT SELECT ON egresados_fi.cat_programa        TO 'api_lectura'@'%';
  GRANT SELECT ON egresados_fi.cat_sector_ciiu     TO 'api_lectura'@'%';
  GRANT SELECT ON egresados_fi.cat_nivel_cargo     TO 'api_lectura'@'%';
  GRANT SELECT ON egresados_fi.cat_pais            TO 'api_lectura'@'%';
  GRANT SELECT ON egresados_fi.v_egresado_programa TO 'api_lectura'@'%';
  GRANT SELECT ON egresados_fi.v_trayectoria       TO 'api_lectura'@'%';
  GRANT SELECT ON egresados_fi.v_situacion_actual  TO 'api_lectura'@'%';
  GRANT SELECT ON egresados_fi.v_resumen_calidad   TO 'api_lectura'@'%';
  GRANT SELECT ON egresados_fi.v_completitud_egresado TO 'api_lectura'@'%';
EOSQL
