-- Homologación, vistas, incidencias, fusión y supresión.
USE egresados_fi;

DELIMITER $$

-- Clave fonética para comparar nombres de organizaciones
CREATE FUNCTION fn_clave_organizacion(p_nombre VARCHAR(200))
RETURNS VARCHAR(200) DETERMINISTIC NO SQL
BEGIN
  DECLARE v VARCHAR(200);
  SET v = UPPER(p_nombre);
  SET v = REGEXP_REPLACE(v, '[^[:alnum:] ]', '');
  SET v = REGEXP_REPLACE(v, '\\s+(SAS|SA|LTDA|SA ESP|ESP|GMBH|AG|INC|LLC|SL)$', '');
  RETURN SOUNDEX(TRIM(v));
END$$

-- Clasifica los cargos pendientes. No toca los clasificados a mano.
CREATE PROCEDURE sp_homologar_cargos()
BEGIN
  UPDATE experiencia_laboral e
     SET e.codigo_nivel_cargo = (
           SELECT h.codigo_nivel_cargo FROM homologacion_cargo h
            WHERE h.codigo_nivel_cargo IS NOT NULL AND e.cargo_original REGEXP h.patron
            ORDER BY h.prioridad, h.id_regla LIMIT 1)
   WHERE e.codigo_nivel_cargo IS NULL AND e.metodo_clasificacion = 'AUTOMATICA';

  UPDATE experiencia_laboral e
     SET e.codigo_ciuo = (
           SELECT h.codigo_ciuo FROM homologacion_cargo h
            WHERE h.codigo_ciuo IS NOT NULL AND e.cargo_original REGEXP h.patron
            ORDER BY h.prioridad, h.id_regla LIMIT 1)
   WHERE e.codigo_ciuo IS NULL AND e.metodo_clasificacion = 'AUTOMATICA';

  UPDATE experiencia_laboral e
     SET e.codigo_area = (
           SELECT h.codigo_area FROM homologacion_cargo h
            WHERE h.codigo_area IS NOT NULL AND e.cargo_original REGEXP h.patron
            ORDER BY h.prioridad, h.id_regla LIMIT 1)
   WHERE e.codigo_area IS NULL AND e.metodo_clasificacion = 'AUTOMATICA';

  SELECT COUNT(*) AS experiencias,
         SUM(codigo_ciuo IS NOT NULL AND codigo_nivel_cargo IS NOT NULL AND codigo_area IS NOT NULL) AS homologadas_completas,
         SUM(codigo_ciuo IS NULL OR codigo_nivel_cargo IS NULL OR codigo_area IS NULL) AS pendientes_revision_manual
    FROM experiencia_laboral;
END$$

DELIMITER ;

-- 1. Vistas de consulta (solo egresados aceptados y activos)

-- Egresado-programa: cohorte = año de finalización declarado del programa
CREATE OR REPLACE VIEW v_egresado_programa AS
SELECT e.id_egresado, pr.id_programa, pr.nombre AS programa,
       pr.codigo_nivel AS nivel_formacion, f.anio_fin AS cohorte
  FROM egresado e
  JOIN formacion f    ON f.id_egresado = e.id_egresado AND f.es_facultad AND f.vigente_en_fuente
                      AND NOT f.en_curso
  JOIN cat_programa pr ON pr.id_programa = f.id_programa
 WHERE e.estado_verificacion = 'ACEPTADO' AND e.estado_registro = 'ACTIVO';

-- Trayectoria: una fila por experiencia, con categorías y fuente
CREATE OR REPLACE VIEW v_trayectoria AS
SELECT x.id_egresado,
       x.id_experiencia,
       o.nombre_normalizado            AS organizacion,
       o.codigo_seccion_ciiu           AS seccion_ciiu,
       s.descripcion                   AS sector_ciiu,
       o.codigo_tipo                   AS tipo_organizacion,
       x.cargo_original,
       x.codigo_ciuo,
       c.descripcion                   AS ocupacion_ciuo,
       x.codigo_nivel_cargo,
       x.codigo_area,
       x.tipo_vinculo,
       x.modalidad,
       x.fecha_inicio,
       x.fecha_fin,
       x.es_actual,
       x.codigo_pais,
       COALESCE(m.nombre, x.ciudad_extranjera) AS ciudad,
       k.codigo_canal                  AS canal,
       k.capturada_en
  FROM experiencia_laboral x
  JOIN egresado            e ON e.id_egresado = x.id_egresado
  JOIN organizacion        o ON o.id_organizacion = x.id_organizacion
  JOIN captura             k ON k.id_captura = x.id_captura
  LEFT JOIN cat_sector_ciiu    s ON s.codigo_seccion = o.codigo_seccion_ciiu
  LEFT JOIN cat_ocupacion_ciuo c ON c.codigo = x.codigo_ciuo
  LEFT JOIN cat_municipio      m ON m.codigo_dane = x.codigo_municipio
 WHERE e.estado_verificacion = 'ACEPTADO' AND e.estado_registro = 'ACTIVO'
   AND x.vigente_en_fuente;

-- Situación actual: la experiencia vigente de mayor nivel jerárquico
CREATE OR REPLACE VIEW v_situacion_actual AS
SELECT *
  FROM (SELECT t.*,
               ROW_NUMBER() OVER (PARTITION BY t.id_egresado
                                  ORDER BY nc.orden DESC, t.fecha_inicio DESC) AS rn
          FROM v_trayectoria t
          LEFT JOIN cat_nivel_cargo nc ON nc.codigo = t.codigo_nivel_cargo
         WHERE t.es_actual) z
 WHERE z.rn = 1;

-- 2. Vistas de calidad

CREATE OR REPLACE VIEW v_completitud_egresado AS
SELECT e.id_egresado,
       e.estado_verificacion,
       e.puntaje_pertenencia,
       (SELECT COUNT(*) FROM formacion f WHERE f.id_egresado = e.id_egresado AND f.es_facultad)        AS programas_facultad,
       (SELECT COUNT(*) FROM experiencia_laboral x WHERE x.id_egresado = e.id_egresado
           AND x.vigente_en_fuente)                                                                     AS experiencias,
       (SELECT COUNT(*) FROM experiencia_laboral x WHERE x.id_egresado = e.id_egresado
           AND x.vigente_en_fuente AND x.codigo_ciuo IS NOT NULL
           AND x.codigo_nivel_cargo IS NOT NULL AND x.codigo_area IS NOT NULL)                          AS experiencias_clasificadas,
       e.ultima_captura_en,
       DATEDIFF(CURDATE(), e.ultima_captura_en)                                                         AS dias_sin_actualizar
  FROM egresado e
 WHERE e.estado_registro = 'ACTIVO';

-- Mismo nombre (o parecido), programa y cohorte
CREATE OR REPLACE VIEW v_posibles_duplicados_egresado AS
SELECT a.id_egresado AS id_egresado_a, b.id_egresado AS id_egresado_b,
       a.nombre_completo AS nombre_a,  b.nombre_completo AS nombre_b,
       CASE WHEN a.nombre_completo = b.nombre_completo THEN 'NOMBRE_IGUAL'
            ELSE 'NOMBRE_FONETICO' END AS criterio,
       fa.id_programa, fa.anio_fin AS cohorte
  FROM egresado a
  JOIN egresado b  ON a.id_egresado < b.id_egresado
  JOIN formacion fa ON fa.id_egresado = a.id_egresado AND fa.es_facultad
  JOIN formacion fb ON fb.id_egresado = b.id_egresado AND fb.es_facultad
                   AND fb.id_programa = fa.id_programa
                   AND (fa.anio_fin IS NULL OR fb.anio_fin IS NULL OR ABS(fa.anio_fin - fb.anio_fin) <= 1)
 WHERE a.estado_registro = 'ACTIVO' AND b.estado_registro = 'ACTIVO'
   AND (a.nombre_completo = b.nombre_completo
        OR (SOUNDEX(a.nombres) = SOUNDEX(b.nombres) AND SOUNDEX(a.apellidos) = SOUNDEX(b.apellidos)));

CREATE OR REPLACE VIEW v_posibles_duplicados_organizacion AS
SELECT a.id_organizacion AS id_organizacion_a, b.id_organizacion AS id_organizacion_b,
       a.nombre_normalizado AS nombre_a, b.nombre_normalizado AS nombre_b,
       fn_clave_organizacion(a.nombre_normalizado) AS clave
  FROM organizacion a
  JOIN organizacion b ON a.id_organizacion < b.id_organizacion
 WHERE fn_clave_organizacion(a.nombre_normalizado) = fn_clave_organizacion(b.nombre_normalizado)
   AND NOT (a.id_linkedin_empresa IS NOT NULL AND b.id_linkedin_empresa IS NOT NULL
            AND a.id_linkedin_empresa <> b.id_linkedin_empresa);

CREATE OR REPLACE VIEW v_resumen_calidad AS
SELECT i.codigo_tipo, t.severidad, i.estado, COUNT(*) AS incidencias
  FROM incidencia_calidad i
  JOIN cat_tipo_incidencia t ON t.codigo = i.codigo_tipo
 GROUP BY i.codigo_tipo, t.severidad, i.estado;

-- 3. Detección de incidencias
DELIMITER $$

-- Se reúnen las detecciones en una tabla temporal y se registran con un solo upsert: si una
-- incidencia ya estaba RESUELTA y el problema reaparece, se reabre (las DESCARTADAS no se tocan).
CREATE PROCEDURE sp_detectar_incidencias(IN p_meses_vigencia INT)
BEGIN
  DROP TEMPORARY TABLE IF EXISTS tmp_incidencia;
  CREATE TEMPORARY TABLE tmp_incidencia (
    codigo_tipo VARCHAR(30), entidad VARCHAR(40), id_registro INT UNSIGNED, clave VARCHAR(60),
    id_egresado INT UNSIGNED NULL, descripcion VARCHAR(500)) ENGINE=MEMORY;

  -- AMBIGUO: pertenencia no concluyente (cola de revisión manual)
  INSERT INTO tmp_incidencia
  SELECT 'AMBIGUO', 'egresado', e.id_egresado, 'POR_REVISAR', e.id_egresado,
         CONCAT('Pertenencia con puntaje ', e.puntaje_pertenencia, '/100: requiere revisión manual')
    FROM egresado e
   WHERE e.estado_verificacion = 'POR_REVISAR' AND e.estado_registro = 'ACTIVO';

  -- NO_VERIFICABLE: el programa de la Facultad no tiene años declarados
  INSERT INTO tmp_incidencia
  SELECT 'NO_VERIFICABLE', 'formacion', f.id_formacion, '', f.id_egresado,
         'Formación de la Facultad sin años: no se puede confirmar el grado ni la cohorte'
    FROM formacion f
   WHERE f.es_facultad AND f.vigente_en_fuente AND f.anio_fin IS NULL AND NOT f.en_curso;

  -- NO_VERIFICABLE: el perfil dejó de estar disponible
  INSERT INTO tmp_incidencia
  SELECT 'NO_VERIFICABLE', 'egresado', e.id_egresado, 'NO_DISPONIBLE', e.id_egresado,
         'El perfil ya no está disponible en la fuente'
    FROM egresado e
   WHERE e.estado_registro = 'NO_DISPONIBLE';

  -- INCOMPLETO: cargo sin homologación completa
  INSERT INTO tmp_incidencia
  SELECT 'INCOMPLETO', 'experiencia_laboral', x.id_experiencia, 'HOMOLOGACION', x.id_egresado,
         CONCAT('Cargo sin homologación completa: "', x.cargo_original, '" (falta ',
                CONCAT_WS(', ', IF(x.codigo_ciuo IS NULL, 'ocupación CIUO', NULL),
                                IF(x.codigo_nivel_cargo IS NULL, 'nivel', NULL),
                                IF(x.codigo_area IS NULL, 'área', NULL)), ')')
    FROM experiencia_laboral x
   WHERE x.vigente_en_fuente
     AND (x.codigo_ciuo IS NULL OR x.codigo_nivel_cargo IS NULL OR x.codigo_area IS NULL);

  -- INCOMPLETO: ubicación no reconocida
  INSERT INTO tmp_incidencia
  SELECT 'INCOMPLETO', 'experiencia_laboral', x.id_experiencia, 'UBICACION', x.id_egresado,
         CONCAT('Ubicación no reconocida: "', COALESCE(x.ubicacion_original, 'sin dato'), '"')
    FROM experiencia_laboral x
   WHERE x.vigente_en_fuente AND x.codigo_pais IS NULL
     AND x.modalidad <> 'REMOTO';

  -- INCOMPLETO: organización sin sector CIIU
  INSERT INTO tmp_incidencia
  SELECT 'INCOMPLETO', 'organizacion', o.id_organizacion, 'CIIU', NULL,
         CONCAT('Organización sin sector CIIU: ', o.nombre_normalizado)
    FROM organizacion o
   WHERE o.codigo_seccion_ciiu IS NULL;

  -- DESACTUALIZADO: última captura más antigua que el periodo de vigencia
  INSERT INTO tmp_incidencia
  SELECT 'DESACTUALIZADO', 'egresado', e.id_egresado, '', e.id_egresado,
         CONCAT('Última captura: ', DATE(e.ultima_captura_en), ' (',
                DATEDIFF(CURDATE(), e.ultima_captura_en), ' días)')
    FROM egresado e
   WHERE e.estado_registro = 'ACTIVO'
     AND e.ultima_captura_en < NOW() - INTERVAL p_meses_vigencia MONTH;

  -- DUPLICADO_POSIBLE: egresados (una incidencia por pareja)
  INSERT INTO tmp_incidencia
  SELECT DISTINCT 'DUPLICADO_POSIBLE', 'egresado', d.id_egresado_b, CONCAT('DE:', d.id_egresado_a), d.id_egresado_b,
         CONCAT('Posible duplicado de id_egresado=', d.id_egresado_a, ' (', d.criterio,
                ', mismo programa y cohorte)')
    FROM v_posibles_duplicados_egresado d;

  -- DUPLICADO_POSIBLE: organizaciones (una incidencia por pareja)
  INSERT INTO tmp_incidencia
  SELECT 'DUPLICADO_POSIBLE', 'organizacion', d.id_organizacion_b, CONCAT('DE:', d.id_organizacion_a), NULL,
         CONCAT('Posible duplicado de "', d.nombre_a, '" (clave ', d.clave, ')')
    FROM v_posibles_duplicados_organizacion d;

  -- INCONSISTENTE: tiempo completo 2 años antes de graduarse
  INSERT INTO tmp_incidencia
  SELECT 'INCONSISTENTE', 'experiencia_laboral', x.id_experiencia, '', x.id_egresado,
         CONCAT('Empleo de tiempo completo desde ', x.fecha_inicio,
                ', más de 2 años antes de finalizar el programa (', g.primer_fin, ')')
    FROM experiencia_laboral x
    JOIN (SELECT id_egresado, MIN(anio_fin) AS primer_fin
            FROM formacion WHERE es_facultad AND vigente_en_fuente AND anio_fin IS NOT NULL
           GROUP BY id_egresado) g ON g.id_egresado = x.id_egresado
   WHERE x.vigente_en_fuente AND x.tipo_vinculo = 'TIEMPO_COMPLETO'
     AND YEAR(x.fecha_inicio) < g.primer_fin - 2;

  -- INCONSISTENTE: más de dos experiencias actuales simultáneas
  INSERT INTO tmp_incidencia
  SELECT 'INCONSISTENTE', 'egresado', x.id_egresado, 'ACTUALES', x.id_egresado,
         CONCAT(COUNT(*), ' experiencias marcadas como actuales')
    FROM experiencia_laboral x
   WHERE x.es_actual AND x.vigente_en_fuente
   GROUP BY x.id_egresado
  HAVING COUNT(*) > 2;

  INSERT INTO incidencia_calidad (codigo_tipo, entidad, id_registro, clave, id_egresado, descripcion)
  SELECT codigo_tipo, entidad, id_registro, clave, id_egresado, descripcion FROM tmp_incidencia
  ON DUPLICATE KEY UPDATE
     descripcion  = VALUES(descripcion),
     detectada_en = IF(estado = 'RESUELTA', CURRENT_TIMESTAMP, detectada_en),
     resuelta_en  = IF(estado = 'RESUELTA', NULL, resuelta_en),
     resuelta_por = IF(estado = 'RESUELTA', NULL, resuelta_por),
     estado       = IF(estado = 'RESUELTA', 'ABIERTA', estado);

  -- Cierra las incidencias de este procedimiento que ya no aplican. Las que registra el proceso en
  -- Python (clave 'EXP:...' y 'PERTENENCIA_NO_CONFIRMADA') las cierra el propio proceso o un analista.
  UPDATE incidencia_calidad i
     SET i.estado = 'RESUELTA', i.resuelta_en = CURRENT_TIMESTAMP, i.resuelta_por = 'sistema'
   WHERE i.estado = 'ABIERTA'
     AND i.clave NOT LIKE 'EXP:%' AND i.clave <> 'PERTENENCIA_NO_CONFIRMADA'
     AND NOT EXISTS (SELECT 1 FROM tmp_incidencia t
                      WHERE t.codigo_tipo = i.codigo_tipo AND t.entidad = i.entidad
                        AND t.id_registro = i.id_registro AND t.clave = i.clave);

  DROP TEMPORARY TABLE tmp_incidencia;
  SELECT * FROM v_resumen_calidad ORDER BY FIELD(severidad,'ALTA','MEDIA','BAJA'), codigo_tipo, estado;
END$$

-- 4. Fusión de duplicados (la decide una persona)
CREATE PROCEDURE sp_fusionar_egresados(IN p_origen INT UNSIGNED, IN p_destino INT UNSIGNED, IN p_responsable VARCHAR(60))
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  IF p_origen = p_destino THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'origen y destino deben ser distintos';
  END IF;
  START TRANSACTION;
    UPDATE formacion f SET f.id_egresado = p_destino
     WHERE f.id_egresado = p_origen
       AND NOT EXISTS (SELECT 1 FROM (SELECT huella FROM formacion WHERE id_egresado = p_destino) d
                        WHERE d.huella = f.huella);
    UPDATE experiencia_laboral x SET x.id_egresado = p_destino
     WHERE x.id_egresado = p_origen
       AND NOT EXISTS (SELECT 1 FROM (SELECT huella FROM experiencia_laboral WHERE id_egresado = p_destino) d
                        WHERE d.huella = x.huella);
    -- queda en el historial
    UPDATE formacion           SET vigente_en_fuente = FALSE WHERE id_egresado = p_origen;
    UPDATE experiencia_laboral SET vigente_en_fuente = FALSE WHERE id_egresado = p_origen;
    UPDATE egresado SET estado_registro = 'FUSIONADO', id_egresado_destino = p_destino
     WHERE id_egresado = p_origen;
    UPDATE incidencia_calidad
       SET estado = 'RESUELTA', resuelta_en = CURRENT_TIMESTAMP, resuelta_por = p_responsable
     WHERE codigo_tipo = 'DUPLICADO_POSIBLE' AND entidad = 'egresado' AND estado = 'ABIERTA'
       AND (id_registro = p_origen OR (id_registro = p_destino AND clave = CONCAT('DE:', p_origen)));
    UPDATE incidencia_calidad
       SET estado = 'DESCARTADA', resuelta_en = CURRENT_TIMESTAMP, resuelta_por = p_responsable
     WHERE id_egresado = p_origen AND estado = 'ABIERTA';
  COMMIT;
END$$

-- 5. Supresión a solicitud del titular (Ley 1581, arts. 8 y 15)
CREATE PROCEDURE sp_suprimir_egresado(IN p_id_egresado INT UNSIGNED, IN p_radicado VARCHAR(30))
BEGIN
  DECLARE v_cand INT UNSIGNED;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  SELECT id_candidato INTO v_cand FROM egresado WHERE id_egresado = p_id_egresado;
  IF v_cand IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'egresado inexistente';
  END IF;
  IF EXISTS (SELECT 1 FROM egresado WHERE id_egresado_destino = p_id_egresado) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'suprima primero los registros fusionados en este egresado';
  END IF;
  START TRANSACTION;
    INSERT IGNORE INTO lista_exclusion (hash_id_publico, motivo, radicado)
    SELECT hash_id_publico, 'SUPRESION', p_radicado FROM candidato WHERE id_candidato = v_cand;
    DELETE FROM incidencia_calidad  WHERE id_egresado = p_id_egresado;
    DELETE FROM experiencia_laboral WHERE id_egresado = p_id_egresado;
    DELETE FROM formacion           WHERE id_egresado = p_id_egresado;
    -- después de los DELETE, que también dejan su versión en el historial
    DELETE FROM historial_cambio    WHERE id_egresado = p_id_egresado;
    DELETE FROM egresado            WHERE id_egresado = p_id_egresado;
    UPDATE captura   SET contenido = NULL WHERE id_candidato = v_cand;
    UPDATE candidato SET id_publico_linkedin = NULL, estado = 'EXCLUIDO', motivo_estado = 'SUPRESION'
     WHERE id_candidato = v_cand;
  COMMIT;
END$$

DELIMITER ;
