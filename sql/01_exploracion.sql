-- ============================================================================
-- 01_exploracion.sql  -  Ejercicio 3: consultas directas sobre archivos Parquet
-- Todas las consultas leen los .parquet directamente (vistas TEMP sobre
-- read_parquet); no existe ninguna tabla importada.
-- ============================================================================

-- name: q3_1_archivos_por_tipo_anio
-- pregunta: 3.1 Cuantos archivos hay disponibles?
-- objetivo: contar los archivos Parquet por tipo de taxi y anio
-- fuente: data/raw/*/*/*.parquet (funcion glob)
SELECT split_part(file, '/', 3) AS taxi_type,
       split_part(file, '/', 4) AS anio,
       count(*)                 AS archivos
FROM glob('data/raw/*/*/*.parquet') t(file)
GROUP BY ALL
ORDER BY ALL;

-- name: q3_1b_total_archivos
-- pregunta: 3.1 Cuantos archivos hay disponibles? (total)
-- objetivo: total de archivos Parquet encontrados por el comodin
-- fuente: data/raw/*/*/*.parquet
SELECT count(*) AS total_archivos FROM glob('data/raw/*/*/*.parquet');

-- name: q3_2_registros_por_tipo_anio
-- pregunta: 3.2 Cuantos registros hay disponibles?
-- objetivo: contar registros reales (escaneo) por tipo de taxi y anio
-- fuente: yellow_raw y green_raw -> data/raw/{yellow,green}/*/*.parquet
SELECT taxi_type, src_year, count(*) AS registros
FROM trips
GROUP BY ALL
ORDER BY ALL;

-- name: q3_2b_registros_metadatos
-- pregunta: 3.2 Cuantos registros hay disponibles? (via metadatos)
-- objetivo: obtener el total leyendo solo el pie de cada Parquet (sin escanear datos) y compararlo con count(*)
-- fuente: parquet_file_metadata sobre data/raw/*/*/*.parquet
SELECT (SELECT CAST(sum(num_rows) AS BIGINT) FROM parquet_file_metadata('data/raw/*/*/*.parquet')) AS filas_segun_metadatos,
       (SELECT count(*) FROM trips)                                                  AS filas_segun_conteo,
       (SELECT sum(num_rows) FROM parquet_file_metadata('data/raw/*/*/*.parquet'))
         = (SELECT count(*) FROM trips)                                              AS coinciden;

-- name: q3_2c_filas_por_archivo
-- pregunta: 3.2 Cuantos registros hay por archivo?
-- objetivo: detectar archivos vacios o con volumen anomalo (insumo para el criterio de completitud)
-- fuente: parquet_file_metadata sobre data/raw/*/*/*.parquet
SELECT regexp_extract(file_name, '(yellow|green)_tripdata_(\d{4}-\d{2})', 1) AS taxi_type,
       regexp_extract(file_name, '(yellow|green)_tripdata_(\d{4}-\d{2})', 2) AS periodo,
       num_rows,
       num_row_groups,
       round(file_size_bytes / 1048576.0, 1)                                 AS mib
FROM parquet_file_metadata('data/raw/*/*/*.parquet')
ORDER BY taxi_type, periodo;

-- name: q3_3_columnas_yellow
-- pregunta: 3.3 / 3.4 Columnas y tipos de los taxis amarillos
-- objetivo: esquema que DuckDB infiere al unir todos los archivos amarillos (union_by_name)
-- fuente: data/raw/yellow/*/*.parquet
DESCRIBE SELECT * EXCLUDE (filename) FROM yellow_raw;

-- name: q3_3_columnas_green
-- pregunta: 3.3 / 3.4 Columnas y tipos de los taxis verdes
-- objetivo: esquema que DuckDB infiere al unir todos los archivos verdes
-- fuente: data/raw/green/*/*.parquet
DESCRIBE SELECT * EXCLUDE (filename) FROM green_raw;

-- name: q3_4_deriva_de_esquema
-- pregunta: 3.4 Los tipos y nombres son estables entre archivos?
-- objetivo: detectar columnas con mas de un tipo fisico o nombres con distinta capitalizacion entre archivos
-- fuente: parquet_schema sobre data/raw/*/*/*.parquet
WITH esquema AS (
    SELECT regexp_extract(file_name, '/(yellow|green)/', 1) AS taxi_type, file_name, name, type
    FROM parquet_schema('data/raw/*/*/*.parquet')
    WHERE type IS NOT NULL                       -- excluye el nodo raiz del esquema
), totales AS (
    SELECT taxi_type, count(DISTINCT file_name) AS archivos_totales
    FROM esquema GROUP BY taxi_type
)
SELECT e.taxi_type,
       lower(e.name)                          AS columna,
       list(DISTINCT e.name ORDER BY e.name)  AS variantes_de_nombre,
       list(DISTINCT e.type ORDER BY e.type)  AS tipos_fisicos,
       count(DISTINCT e.file_name)            AS archivos_con_la_columna,
       any_value(t.archivos_totales)          AS archivos_totales
FROM esquema e JOIN totales t USING (taxi_type)
GROUP BY e.taxi_type, lower(e.name)
HAVING len(list(DISTINCT e.name)) > 1
    OR len(list(DISTINCT e.type)) > 1
    OR count(DISTINCT e.file_name) < any_value(t.archivos_totales)
ORDER BY e.taxi_type, columna;

-- name: q3_5_muestra_aleatoria
-- pregunta: 3.5 Muestra de registros
-- objetivo: inspeccionar 10 registros aleatorios de la vista unificada
-- fuente: vista trips (yellow + green)
SELECT * EXCLUDE (filename) FROM trips USING SAMPLE 10 ROWS;

-- name: q3_5b_primeros_por_tipo
-- pregunta: 3.5 Muestra de registros (primeros por tipo)
-- objetivo: ver 5 registros de cada tipo de taxi
-- fuente: vista trips
(SELECT * EXCLUDE (filename) FROM trips WHERE taxi_type = 'yellow' LIMIT 5)
UNION ALL
(SELECT * EXCLUDE (filename) FROM trips WHERE taxi_type = 'green' LIMIT 5);

-- name: q3_6_resumen_estadistico
-- pregunta: 3.6 Que problemas de calidad se observan?
-- objetivo: SUMMARIZE (min, max, nulos, cuantiles) de las columnas numericas y de fecha
-- fuente: vista trips
SUMMARIZE SELECT pickup_ts, dropoff_ts, passenger_count, trip_distance, ratecode_id,
                 payment_type, fare_amount, tip_amount, tolls_amount, total_amount
          FROM trips;

-- name: q3_6b_nulos_por_tipo
-- pregunta: 3.6 Cuantos valores nulos hay en las columnas clave?
-- objetivo: cuantificar nulos por tipo de taxi
-- fuente: vista trips
SELECT taxi_type,
       count(*)                                    AS registros,
       count(*) - count(passenger_count)           AS passenger_count_nulos,
       count(*) - count(ratecode_id)               AS ratecode_nulos,
       count(*) - count(payment_type)              AS payment_type_nulos,
       count(*) - count(pickup_ts)                 AS pickup_nulos,
       count(*) - count(dropoff_ts)                AS dropoff_nulos
FROM trips
GROUP BY taxi_type;

-- name: q3_6c_anomalias_basicas
-- pregunta: 3.6 Cuantos registros violan reglas basicas de coherencia?
-- objetivo: contar anomalias evidentes (fechas, distancias, importes, pasajeros) por tipo
-- fuente: vista trips
SELECT taxi_type,
       count(*)                                                                         AS registros,
       count(*) FILTER (WHERE year(pickup_ts) <> src_year OR month(pickup_ts) <> src_month) AS fuera_del_periodo_del_archivo,
       count(*) FILTER (WHERE dropoff_ts < pickup_ts)                                   AS llegada_antes_de_salida,
       count(*) FILTER (WHERE date_diff('hour', pickup_ts, dropoff_ts) > 24)            AS duracion_mayor_24h,
       count(*) FILTER (WHERE trip_distance = 0)                                        AS distancia_cero,
       count(*) FILTER (WHERE trip_distance > 100)                                      AS distancia_mayor_100mi,
       count(*) FILTER (WHERE fare_amount < 0)                                          AS tarifa_negativa,
       count(*) FILTER (WHERE total_amount <= 0)                                        AS total_no_positivo,
       count(*) FILTER (WHERE passenger_count = 0)                                      AS pasajeros_cero,
       count(*) FILTER (WHERE passenger_count IS NULL)                                  AS pasajeros_nulo,
       count(*) FILTER (WHERE payment_type = 0 OR payment_type > 6)                     AS pago_fuera_de_catalogo
FROM trips
GROUP BY taxi_type;

-- name: q3_7_rango_fechas
-- pregunta: 3.7 Que rango de fechas contiene realmente cada archivo?
-- objetivo: comparar el periodo del nombre del archivo con las fechas reales de recogida
-- fuente: vista trips
SELECT taxi_type, src_year, src_month,
       min(pickup_ts) AS primera_recogida,
       max(pickup_ts) AS ultima_recogida,
       count(*)       AS registros
FROM trips
GROUP BY ALL
ORDER BY ALL;

-- name: q3_7b_catalogos
-- pregunta: 3.7 Que valores toman los codigos de pago y tarifa?
-- objetivo: revisar los catalogos payment_type y ratecode_id frente al diccionario de la TLC
-- fuente: vista trips
SELECT 'payment_type' AS campo, CAST(payment_type AS VARCHAR) AS valor, taxi_type, count(*) AS registros FROM trips GROUP BY ALL
UNION ALL
SELECT 'ratecode_id', CAST(ratecode_id AS VARCHAR), taxi_type, count(*) FROM trips GROUP BY ALL
ORDER BY campo, taxi_type, registros DESC;
