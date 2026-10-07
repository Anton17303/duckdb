-- ============================================================================
-- 03_incorporacion.sql  -  Ejercicios 5 y 8: validar la incorporacion de anios
-- Ninguna consulta menciona un anio concreto: funcionan igual con 1, 2 o 3 anios
-- porque las vistas leen con comodines (data/raw/<tipo>/*/*.parquet).
-- ============================================================================

-- name: q5_1_archivos_por_anio
-- pregunta: 5.5 Los archivos nuevos fueron incorporados?
-- objetivo: contar archivos y filas por tipo y anio (segun metadatos Parquet, sin escanear datos)
-- fuente: parquet_file_metadata sobre data/raw/*/*/*.parquet
SELECT regexp_extract(file_name, '/(yellow|green)/', 1)  AS taxi_type,
       regexp_extract(file_name, '/(\d{4})/', 1)         AS anio,
       count(*)                                          AS archivos,
       CAST(sum(num_rows) AS BIGINT)                     AS filas
FROM parquet_file_metadata('data/raw/*/*/*.parquet')
GROUP BY ALL
ORDER BY ALL;

-- name: q5_2_consulta_conjunta_por_mes
-- pregunta: 5.6 Es posible consultar conjuntamente todos los anios?
-- objetivo: viajes por mes del anio (filas) y por anio (columnas) con una unica consulta
-- fuente: vista trips (todos los archivos)
PIVOT (SELECT taxi_type, src_month AS mes, src_year AS anio FROM trips)
ON anio
USING count(*)
GROUP BY taxi_type, mes
ORDER BY taxi_type, mes;

-- name: q5_3_sin_archivos_duplicados
-- pregunta: 5.5 Hay periodos duplicados o cargados dos veces?
-- objetivo: verificar que cada (tipo, anio, mes) proviene de exactamente un archivo (se esperan 0 filas)
-- fuente: vista trips
SELECT taxi_type, src_year, src_month, count(DISTINCT filename) AS archivos
FROM trips
GROUP BY ALL
HAVING count(DISTINCT filename) > 1;

-- name: q5_4_meses_presentes
-- pregunta: 5.5 Que meses existen realmente por tipo y anio?
-- objetivo: detectar meses faltantes dentro de un anio (lista los meses presentes y su conteo)
-- fuente: vista trips
SELECT taxi_type, src_year,
       count(DISTINCT src_month)                       AS meses_presentes,
       list(DISTINCT src_month ORDER BY src_month)     AS meses
FROM trips
GROUP BY ALL
ORDER BY ALL;

-- name: q5_5_consistencia_esquema_por_anio
-- pregunta: 5.7 Cambia el esquema entre anios de modo que las consultas deban modificarse?
-- objetivo: columnas presentes por anio y tipo; las columnas usadas por las vistas deben aparecer en todos los anios
-- fuente: parquet_schema sobre data/raw/*/*/*.parquet
SELECT regexp_extract(file_name, '/(yellow|green)/', 1) AS taxi_type,
       regexp_extract(file_name, '/(\d{4})/', 1)        AS anio,
       count(DISTINCT lower(name))                      AS columnas,
       list(DISTINCT lower(name) ORDER BY lower(name))
         FILTER (WHERE lower(name) LIKE '%fee' OR lower(name) LIKE '%surcharge') AS columnas_de_cargos
FROM parquet_schema('data/raw/*/*/*.parquet')
WHERE type IS NOT NULL
GROUP BY ALL
ORDER BY ALL;
