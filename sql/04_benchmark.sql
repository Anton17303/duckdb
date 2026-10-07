-- ============================================================================
-- 04_benchmark.sql  -  Ejercicio 6: consultas del benchmark Parquet vs tabla
-- {{T}} se reemplaza por:
--   bench_pq  = vista sobre los archivos Parquet del subconjunto (lectura directa)
--   bench_tbl = filas del subconjunto en la tabla materializada trips_tbl
-- Ambas vistas tienen el mismo esquema y se filtran con la misma condicion
-- (filename IN (...)), por lo que el cuerpo de cada consulta es identico.
-- ============================================================================

-- name: b1_conteo
-- objetivo: agregado trivial (count); el Parquet puede resolverlo casi solo con metadatos
-- fuente: {{T}}
SELECT count(*) AS viajes FROM {{T}};

-- name: b2_agregado_por_tipo
-- objetivo: agregados sobre pocas columnas numericas (poca proyeccion, muchas filas)
-- fuente: {{T}}
SELECT taxi_type,
       count(*)                 AS viajes,
       avg(fare_amount)         AS tarifa_media,
       avg(trip_distance)       AS distancia_media,
       sum(total_amount)        AS ingreso_total
FROM {{T}}
GROUP BY taxi_type
ORDER BY taxi_type;

-- name: b3_viajes_por_hora
-- objetivo: agrupacion por una expresion temporal (extraccion de hora) de baja cardinalidad
-- fuente: {{T}}
SELECT taxi_type, hour(pickup_ts) AS hora, count(*) AS viajes, avg(total_amount) AS total_medio
FROM {{T}}
GROUP BY taxi_type, hour(pickup_ts)
ORDER BY taxi_type, hora;

-- name: b4_mensual_por_pago
-- objetivo: serie mensual por metodo de pago (agrupacion con varias llaves)
-- fuente: {{T}}
SELECT taxi_type, src_year, src_month, payment_type,
       count(*) AS viajes, sum(total_amount) AS ingreso, avg(tip_amount) AS propina_media
FROM {{T}}
GROUP BY taxi_type, src_year, src_month, payment_type
ORDER BY taxi_type, src_year, src_month, payment_type;

-- name: b5_top_pares_de_zonas
-- objetivo: agrupacion de alta cardinalidad (pares origen-destino) y ordenamiento
-- fuente: {{T}}
SELECT pu_location_id, do_location_id, count(*) AS viajes
FROM {{T}}
GROUP BY pu_location_id, do_location_id
ORDER BY viajes DESC, pu_location_id, do_location_id
LIMIT 20;

-- name: b6_filtro_selectivo
-- objetivo: filtro muy selectivo sobre columnas numericas (aprovecha estadisticas de bloques)
-- fuente: {{T}}
SELECT count(*) AS viajes, avg(total_amount) AS total_medio, max(total_amount) AS total_max
FROM {{T}}
WHERE total_amount > 150 AND trip_distance < 1;

-- name: b7_percentiles_tarifa
-- objetivo: agregado costoso (percentiles exactos) que requiere materializar los valores
-- fuente: {{T}}
SELECT taxi_type,
       quantile_cont(fare_amount, 0.50) AS mediana,
       quantile_cont(fare_amount, 0.90) AS p90,
       quantile_cont(fare_amount, 0.99) AS p99
FROM {{T}}
WHERE fare_amount > 0
GROUP BY taxi_type
ORDER BY taxi_type;
