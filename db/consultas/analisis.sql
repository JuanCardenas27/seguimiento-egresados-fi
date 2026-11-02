-- Consultas de los indicadores. Al publicar, se ocultan los grupos de menos de 5 personas.
-- docker exec -i egresados-db mariadb -uanalista -panalista_dev -t egresados_fi < db/consultas/analisis.sql
USE egresados_fi;

-- P1. ¿Cuántos egresados se han identificado por programa y cohorte?
SELECT programa, cohorte, COUNT(DISTINCT id_egresado) AS egresados_identificados
  FROM v_egresado_programa
 GROUP BY programa, cohorte
 ORDER BY programa, cohorte;

-- P2. ¿En qué sectores económicos (CIIU) trabajan actualmente?
SELECT COALESCE(sector_ciiu, '(sin clasificar)') AS sector, COUNT(*) AS egresados
  FROM v_situacion_actual
 GROUP BY sector
 ORDER BY egresados DESC;

-- P3. ¿Qué nivel jerárquico alcanzan según los años desde la finalización?
SELECT nc.descripcion AS nivel_actual, COUNT(*) AS egresados,
       ROUND(AVG(YEAR(CURDATE()) - g.primer_fin), 1) AS anios_promedio_desde_finalizacion
  FROM v_situacion_actual s
  JOIN cat_nivel_cargo nc ON nc.codigo = s.codigo_nivel_cargo
  JOIN (SELECT id_egresado, MIN(cohorte) AS primer_fin FROM v_egresado_programa
         WHERE nivel_formacion = 'PREGRADO' GROUP BY id_egresado) g ON g.id_egresado = s.id_egresado
 GROUP BY nc.orden, nc.descripcion
 ORDER BY nc.orden;

-- P4. ¿Cuánto tardan en conseguir el primer empleo? (años)
SELECT p.programa, p.id_egresado, p.cohorte,
       MIN(YEAR(t.fecha_inicio)) AS primer_empleo,
       MIN(YEAR(t.fecha_inicio)) - p.cohorte AS anios_hasta_empleo
  FROM v_egresado_programa p
  JOIN v_trayectoria t ON t.id_egresado = p.id_egresado AND t.tipo_vinculo <> 'PRACTICA'
                      AND YEAR(t.fecha_inicio) >= p.cohorte
 WHERE p.nivel_formacion = 'PREGRADO'
 GROUP BY p.programa, p.id_egresado, p.cohorte;

-- P5. ¿Cuántos trabajan fuera de Colombia y dónde?
SELECT s.codigo_pais, pa.nombre AS pais, s.ciudad, COUNT(*) AS egresados
  FROM v_situacion_actual s
  JOIN cat_pais pa ON pa.codigo_iso2 = s.codigo_pais
 WHERE s.codigo_pais <> 'CO'
 GROUP BY s.codigo_pais, pa.nombre, s.ciudad;

-- P6. ¿En qué departamentos y municipios de Colombia trabajan?
SELECT d.nombre AS departamento, m.nombre AS municipio, COUNT(*) AS egresados
  FROM v_situacion_actual s
  JOIN experiencia_laboral x ON x.id_experiencia = s.id_experiencia
  JOIN cat_municipio m       ON m.codigo_dane = x.codigo_municipio
  JOIN cat_departamento d    ON d.codigo_dane = m.codigo_departamento
 GROUP BY d.nombre, m.nombre
 ORDER BY egresados DESC;

-- P7. Pertinencia: ¿el área de desempeño actual es afín al programa?
SELECT p.programa, a.descripcion AS area_actual, COUNT(*) AS egresados
  FROM v_situacion_actual s
  JOIN v_egresado_programa p ON p.id_egresado = s.id_egresado AND p.nivel_formacion = 'PREGRADO'
  LEFT JOIN cat_area_desempeno a ON a.codigo = s.codigo_area
 GROUP BY p.programa, a.descripcion
 ORDER BY p.programa, egresados DESC;

-- P8. ¿Sector público, privado o emprendimiento?
SELECT COALESCE(t.descripcion, '(sin clasificar)') AS tipo_organizacion, COUNT(*) AS egresados
  FROM v_situacion_actual s
  LEFT JOIN cat_tipo_organizacion t ON t.codigo = s.tipo_organizacion
 GROUP BY t.descripcion;

-- P9. ¿Cuántos continúan con formación posgradual (en la Facultad o fuera)?
SELECT IF(f.es_facultad, 'Facultad', 'Otra institución') AS origen, n.descripcion AS nivel,
       SUM(NOT f.en_curso) AS finalizados, SUM(f.en_curso) AS en_curso
  FROM formacion f
  JOIN egresado e ON e.id_egresado = f.id_egresado
                 AND e.estado_verificacion = 'ACEPTADO' AND e.estado_registro = 'ACTIVO'
  JOIN cat_nivel_formacion n ON n.codigo = f.codigo_nivel
 WHERE f.vigente_en_fuente AND n.orden > (SELECT orden FROM cat_nivel_formacion WHERE codigo = 'PREGRADO')
 GROUP BY origen, n.orden, n.descripcion;

-- P10. ¿Cuánto duran en promedio los empleos (rotación)?
SELECT ROUND(AVG(TIMESTAMPDIFF(MONTH, fecha_inicio, COALESCE(fecha_fin, CURDATE()))), 1) AS meses_promedio,
       COUNT(*) AS experiencias
  FROM v_trayectoria
 WHERE tipo_vinculo <> 'PRACTICA';

-- P11. Desempeño del proceso
SELECT estado_verificacion, COUNT(*) AS perfiles, ROUND(AVG(puntaje_pertenencia), 1) AS puntaje_promedio
  FROM egresado WHERE estado_registro = 'ACTIVO'
 GROUP BY estado_verificacion;

SELECT estado, motivo_estado, COUNT(*) AS candidatos
  FROM candidato GROUP BY estado, motivo_estado;

-- P12. Trazabilidad: historial completo de una experiencia (SYSTEM VERSIONING)
SELECT id_experiencia, cargo_original, codigo_ciuo, codigo_nivel_cargo, codigo_area, id_captura,
       ROW_START AS vigente_desde, ROW_END AS vigente_hasta
  FROM experiencia_laboral FOR SYSTEM_TIME ALL
 WHERE id_experiencia = 1
 ORDER BY ROW_START;
