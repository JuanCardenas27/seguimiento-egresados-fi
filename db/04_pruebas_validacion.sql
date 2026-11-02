-- Pruebas de las reglas de validación. Todo corre en una transacción que se revierte.
USE egresados_fi;

DROP PROCEDURE IF EXISTS sp_probar;
DELIMITER $$
CREATE PROCEDURE sp_probar(IN p_caso VARCHAR(120), IN p_sql TEXT)
BEGIN
  DECLARE v_msg TEXT DEFAULT NULL;
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
  SET @stmt = p_sql;
  PREPARE s FROM @stmt;
  EXECUTE s;
  DEALLOCATE PREPARE s;
  INSERT INTO resultado_prueba VALUES (p_caso, IF(v_msg IS NULL, 'FALLA (aceptó dato inválido)', 'PASA'), v_msg);
END$$
DELIMITER ;

-- MEMORY para que los resultados sobrevivan al ROLLBACK
CREATE TEMPORARY TABLE resultado_prueba (caso VARCHAR(120), resultado VARCHAR(40), mensaje VARCHAR(255)) ENGINE=MEMORY;

START TRANSACTION;

-- 1. Datos base
INSERT INTO ejecucion (etapa, version_proceso) VALUES ('COMPLETA', 'prueba');
SET @ej = LAST_INSERT_ID();
INSERT INTO candidato (hash_id_publico, id_publico_linkedin, id_ejecucion) VALUES (SHA2('prueba-a',256), 'prueba-a', @ej);
SET @ca = LAST_INSERT_ID();
INSERT INTO candidato (hash_id_publico, id_publico_linkedin, id_ejecucion) VALUES (SHA2('prueba-b',256), 'prueba-b', @ej);
SET @cb = LAST_INSERT_ID();
INSERT INTO candidato (hash_id_publico, id_publico_linkedin, id_ejecucion, estado) VALUES (SHA2('prueba-c',256), NULL, @ej, 'EXCLUIDO');
SET @cc = LAST_INSERT_ID();
INSERT INTO lista_exclusion (hash_id_publico, motivo, radicado) VALUES (SHA2('prueba-c',256), 'SUPRESION', 'R-0001');
INSERT INTO captura (id_candidato, id_ejecucion, codigo_canal, capturada_en, hash_contenido, contenido, expira_en, resultado)
VALUES (@ca, @ej, 'ARCHIVO_PRUEBA', NOW() - INTERVAL 1 HOUR, SHA2('a',256), '{}', CURDATE() + INTERVAL 90 DAY, 'NUEVO');
SET @ka = LAST_INSERT_ID();
INSERT INTO captura (id_candidato, id_ejecucion, codigo_canal, capturada_en, hash_contenido, contenido, expira_en, resultado)
VALUES (@cb, @ej, 'ARCHIVO_PRUEBA', NOW() - INTERVAL 1 HOUR, SHA2('b',256), '{}', CURDATE() + INTERVAL 90 DAY, 'NUEVO');
SET @kb = LAST_INSERT_ID();
INSERT INTO egresado (id_candidato, id_publico_linkedin, nombres, apellidos, puntaje_pertenencia, criterios_pertenencia,
                      estado_verificacion, id_ultima_captura, primera_captura_en, ultima_captura_en)
VALUES (@ca, 'prueba-a', 'Prueba', 'Uno', 95, '{}', 'ACEPTADO', @ka, NOW() - INTERVAL 1 HOUR, NOW() - INTERVAL 1 HOUR);
SET @ea = LAST_INSERT_ID();
INSERT INTO egresado (id_candidato, id_publico_linkedin, nombres, apellidos, puntaje_pertenencia, criterios_pertenencia,
                      estado_verificacion, id_ultima_captura, primera_captura_en, ultima_captura_en)
VALUES (@cb, 'prueba-b', 'Prueba', 'Dos', 95, '{}', 'ACEPTADO', @kb, NOW() - INTERVAL 1 HOUR, NOW() - INTERVAL 1 HOUR);
SET @eb = LAST_INSERT_ID();
INSERT INTO organizacion (nombre_normalizado) VALUES ('ORGANIZACION DE PRUEBA S.A.S.');
SET @o = LAST_INSERT_ID();
INSERT INTO experiencia_laboral (id_egresado, id_organizacion, id_captura, huella, cargo_original, fecha_inicio, precision_inicio, codigo_pais)
VALUES (@ea, @o, @ka, SHA1('exp-1'), 'Ingeniero', '2020-01-01', 'MES', 'CO');

-- 2. Identificación y protección de datos
CALL sp_probar('Huella de candidato con formato inválido',
  "INSERT INTO candidato (hash_id_publico, id_publico_linkedin, id_ejecucion) VALUES ('123', 'x-y-z', @ej)");
CALL sp_probar('Candidato descartado que conserva su URL',
  "INSERT INTO candidato (hash_id_publico, id_publico_linkedin, id_ejecucion, estado) VALUES (SHA2('d',256), 'descartado-x', @ej, 'DESCARTADO')");
CALL sp_probar('Captura de un titular en la lista de exclusión',
  "INSERT INTO captura (id_candidato, id_ejecucion, codigo_canal, capturada_en, hash_contenido, expira_en, resultado) VALUES (@cc, @ej, 'ARCHIVO_PRUEBA', NOW(), SHA2('c',256), CURDATE() + INTERVAL 90 DAY, 'NUEVO')");
CALL sp_probar('Captura con fecha futura',
  "INSERT INTO captura (id_candidato, id_ejecucion, codigo_canal, capturada_en, hash_contenido, expira_en, resultado) VALUES (@ca, @ej, 'ARCHIVO_PRUEBA', NOW() + INTERVAL 1 DAY, SHA2('f',256), CURDATE() + INTERVAL 90 DAY, 'NUEVO')");
CALL sp_probar('Contenido de captura que no es JSON',
  "INSERT INTO captura (id_candidato, id_ejecucion, codigo_canal, capturada_en, hash_contenido, contenido, expira_en) VALUES (@ca, @ej, 'ARCHIVO_PRUEBA', NOW(), SHA2('g',256), 'no-json', CURDATE() + INTERVAL 90 DAY, 'NUEVO')");
CALL sp_probar('Aceptado automáticamente con puntaje menor que 80',
  "UPDATE egresado SET puntaje_pertenencia = 70 WHERE id_egresado = @ea");
CALL sp_probar('Por revisar con puntaje menor que 50',
  "UPDATE egresado SET estado_verificacion = 'POR_REVISAR', puntaje_pertenencia = 40 WHERE id_egresado = @ea");
CALL sp_probar('Aceptación manual sin responsable',
  "UPDATE egresado SET metodo_verificacion = 'MANUAL', puntaje_pertenencia = 70 WHERE id_egresado = @ea");
CALL sp_probar('Identificador público con formato inválido',
  "UPDATE egresado SET id_publico_linkedin = 'https://linkedin.com/in/X' WHERE id_egresado = @ea");
CALL sp_probar('Mismo perfil registrado para dos egresados',
  "UPDATE egresado SET id_publico_linkedin = 'prueba-a' WHERE id_egresado = @eb");

-- 3. Formación
CALL sp_probar('Formación de la Facultad sin programa homologado',
  "INSERT INTO formacion (id_egresado, id_captura, huella, institucion_original, es_facultad) VALUES (@ea, @ka, SHA1('f1'), 'Universidad Nacional de Colombia', TRUE)");
CALL sp_probar('Título de la Facultad con año de finalización futuro',
  "INSERT INTO formacion (id_egresado, id_captura, huella, institucion_original, es_facultad, id_programa, anio_fin) VALUES (@ea, @ka, SHA1('f2'), 'Universidad Nacional de Colombia', TRUE, 3, YEAR(CURDATE()) + 2)");

-- 4. Experiencia laboral
CALL sp_probar('Fecha de fin anterior a la de inicio',
  "INSERT INTO experiencia_laboral (id_egresado, id_organizacion, id_captura, huella, cargo_original, fecha_inicio, precision_inicio, fecha_fin, precision_fin) VALUES (@ea, @o, @ka, SHA1('e2'), 'X', '2020-05-01', 'MES', '2019-01-01', 'MES')");
CALL sp_probar('Experiencia actual con fecha de fin',
  "INSERT INTO experiencia_laboral (id_egresado, id_organizacion, id_captura, huella, cargo_original, fecha_inicio, precision_inicio, fecha_fin, precision_fin, es_actual) VALUES (@ea, @o, @ka, SHA1('e3'), 'X', '2020-05-01', 'MES', '2021-01-01', 'MES', TRUE)");
CALL sp_probar('Fecha de inicio futura',
  "INSERT INTO experiencia_laboral (id_egresado, id_organizacion, id_captura, huella, cargo_original, fecha_inicio, precision_inicio) VALUES (@ea, @o, @ka, SHA1('e4'), 'X', CURDATE() + INTERVAL 1 YEAR, 'MES')");
CALL sp_probar('Municipio colombiano con país extranjero',
  "INSERT INTO experiencia_laboral (id_egresado, id_organizacion, id_captura, huella, cargo_original, fecha_inicio, precision_inicio, codigo_pais, codigo_municipio) VALUES (@ea, @o, @ka, SHA1('e5'), 'X', '2020-01-01', 'MES', 'DE', '11001')");
CALL sp_probar('Código DIVIPOLA inexistente',
  "INSERT INTO experiencia_laboral (id_egresado, id_organizacion, id_captura, huella, cargo_original, fecha_inicio, precision_inicio, codigo_pais, codigo_municipio) VALUES (@ea, @o, @ka, SHA1('e6'), 'X', '2020-01-01', 'MES', 'CO', '99999')");
CALL sp_probar('Experiencia respaldada por la captura de otro perfil',
  "INSERT INTO experiencia_laboral (id_egresado, id_organizacion, id_captura, huella, cargo_original, fecha_inicio, precision_inicio) VALUES (@eb, @o, @ka, SHA1('e7'), 'X', '2020-01-01', 'MES')");
CALL sp_probar('Misma experiencia registrada dos veces (huella)',
  "INSERT INTO experiencia_laboral (id_egresado, id_organizacion, id_captura, huella, cargo_original, fecha_inicio, precision_inicio) VALUES (@ea, @o, @ka, SHA1('exp-1'), 'Ingeniero', '2020-01-01', 'MES')");
CALL sp_probar('Sector CIIU inexistente',
  "INSERT INTO organizacion (nombre_normalizado, codigo_seccion_ciiu) VALUES ('NUEVA S.A.S.', 'Z')");

ROLLBACK;

-- reiniciar los AUTO_INCREMENT
SET @@system_versioning_alter_history = KEEP;
ALTER TABLE ejecucion AUTO_INCREMENT = 1;
ALTER TABLE candidato AUTO_INCREMENT = 1;
ALTER TABLE captura AUTO_INCREMENT = 1;
ALTER TABLE egresado AUTO_INCREMENT = 1;
ALTER TABLE organizacion AUTO_INCREMENT = 1;
ALTER TABLE formacion AUTO_INCREMENT = 1;
ALTER TABLE experiencia_laboral AUTO_INCREMENT = 1;
SET @@system_versioning_alter_history = ERROR;

SELECT caso, resultado, LEFT(mensaje, 90) AS mensaje_base_de_datos FROM resultado_prueba;
SELECT CONCAT(SUM(resultado = 'PASA'), ' de ', COUNT(*), ' pruebas superadas') AS resumen FROM resultado_prueba;

DROP PROCEDURE sp_probar;
