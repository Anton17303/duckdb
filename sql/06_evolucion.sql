-- ============================================================================
-- 06_evolucion.sql  -  Ejercicio 8: analisis de la evolucion 2024-2026
-- Ninguna consulta nombra un anio: comparan todos los anios presentes en disco.
-- Como el ultimo anio suele estar incompleto (la TLC publica con retraso), las
-- comparaciones justas usan solo los MESES presentes en TODOS los anios
-- (vista TEMP meses_comunes).
-- ============================================================================

-- name: q8_0_meses_comunes
-- pregunta: 8.5 Que meses pueden compararse entre todos los anios?
-- objetivo: meses del anio presentes en cada anio y tipo de taxi; los comunes se usan para comparar sin sesgo
-- fuente: vista trips
SELECT taxi_type, src_month, count(DISTINCT src_year) AS anios_con_datos,
       list(DISTINCT src_year ORDER BY src_year) AS anios
FROM trips
GROUP BY ALL
ORDER BY taxi_type, src_month;

-- name: q8_1_resumen_anual_mismos_meses
-- pregunta: 8.5 Como cambian los indicadores principales de un anio a otro (mismos meses)?
-- objetivo: viajes, ingreso, tarifa, distancia, duracion y % de pago con tarjeta por anio, solo meses comunes
-- fuente: trips_clean
WITH comunes AS (
    SELECT src_month FROM trips GROUP BY src_month
    HAVING count(DISTINCT src_year) = (SELECT count(DISTINCT src_year) FROM trips)
)
SELECT taxi_type, src_year,
       count(*)                                                        AS viajes,
       round(sum(total_amount), 0)                                     AS ingreso_total,
       round(avg(fare_amount), 2)                                      AS tarifa_media,
       round(avg(trip_distance), 2)                                    AS distancia_media_mi,
       round(avg(duration_min), 1)                                     AS duracion_media_min,
       round(100.0 * count(*) FILTER (WHERE payment_type = 1) / count(*), 2) AS pct_tarjeta,
       round(100 * avg(tip_amount / fare_amount) FILTER (WHERE payment_type = 1), 2) AS pct_propina_tarjeta
FROM trips_clean
WHERE src_month IN (SELECT src_month FROM comunes)
GROUP BY taxi_type, src_year
ORDER BY taxi_type, src_year;

-- name: q8_2_variacion_interanual
-- pregunta: 8.6 Cuanto crecio o cayo cada indicador respecto al anio anterior?
-- objetivo: variacion porcentual interanual de viajes, tarifa media y distancia media (mismos meses)
-- fuente: trips_clean
WITH comunes AS (
    SELECT src_month FROM trips GROUP BY src_month
    HAVING count(DISTINCT src_year) = (SELECT count(DISTINCT src_year) FROM trips)
), anual AS (
    SELECT taxi_type, src_year, count(*) AS viajes, avg(fare_amount) AS tarifa_media, avg(trip_distance) AS distancia_media
    FROM trips_clean
    WHERE src_month IN (SELECT src_month FROM comunes)
    GROUP BY taxi_type, src_year
)
SELECT taxi_type, src_year, viajes,
       round(100.0 * (viajes - lag(viajes) OVER w) / lag(viajes) OVER w, 2)                 AS var_viajes_pct,
       round(100.0 * (tarifa_media - lag(tarifa_media) OVER w) / lag(tarifa_media) OVER w, 2)       AS var_tarifa_pct,
       round(100.0 * (distancia_media - lag(distancia_media) OVER w) / lag(distancia_media) OVER w, 2) AS var_distancia_pct
FROM anual
WINDOW w AS (PARTITION BY taxi_type ORDER BY src_year)
ORDER BY taxi_type, src_year;

-- name: q8_3_hora_pico_por_anio
-- pregunta: 8.6 Cambio el patron horario de la demanda entre anios?
-- objetivo: hora con mas viajes y su participacion, por tipo de taxi y anio (meses comunes)
-- fuente: trips_clean
WITH comunes AS (
    SELECT src_month FROM trips GROUP BY src_month
    HAVING count(DISTINCT src_year) = (SELECT count(DISTINCT src_year) FROM trips)
), horas AS (
    SELECT taxi_type, src_year, hour(pickup_ts) AS hora, count(*) AS viajes
    FROM trips_clean WHERE src_month IN (SELECT src_month FROM comunes)
    GROUP BY ALL
), ranking AS (
    SELECT *, row_number() OVER (PARTITION BY taxi_type, src_year ORDER BY viajes DESC) AS pos,
           round(100.0 * viajes / sum(viajes) OVER (PARTITION BY taxi_type, src_year), 2) AS pct
    FROM horas
)
SELECT taxi_type, src_year, hora AS hora_pico, viajes, pct AS pct_del_dia
FROM ranking WHERE pos = 1
ORDER BY taxi_type, src_year;

-- name: q8_4_mezcla_de_pago_por_anio
-- pregunta: 8.6 Cambio la mezcla de metodos de pago?
-- objetivo: participacion de cada metodo de pago por anio y tipo (meses comunes)
-- fuente: trips_clean
WITH comunes AS (
    SELECT src_month FROM trips GROUP BY src_month
    HAVING count(DISTINCT src_year) = (SELECT count(DISTINCT src_year) FROM trips)
)
SELECT taxi_type, src_year, payment_type, count(*) AS viajes,
       round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY taxi_type, src_year), 2) AS pct
FROM trips_clean
WHERE src_month IN (SELECT src_month FROM comunes)
GROUP BY taxi_type, src_year, payment_type
ORDER BY taxi_type, src_year, viajes DESC;

-- name: q8_5_calidad_por_anio
-- pregunta: 8.6 La calidad de los registros cambio entre anios?
-- objetivo: % de registros descartados por las reglas de limpieza, por anio y tipo (meses comunes)
-- fuente: trips y trips_clean
WITH comunes AS (
    SELECT src_month FROM trips GROUP BY src_month
    HAVING count(DISTINCT src_year) = (SELECT count(DISTINCT src_year) FROM trips)
), t AS (
    SELECT taxi_type, src_year, count(*) AS registros FROM trips
    WHERE src_month IN (SELECT src_month FROM comunes) GROUP BY ALL
), c AS (
    SELECT taxi_type, src_year, count(*) AS conservados FROM trips_clean
    WHERE src_month IN (SELECT src_month FROM comunes) GROUP BY ALL
)
SELECT t.taxi_type, t.src_year, t.registros, c.conservados,
       round(100.0 * (t.registros - c.conservados) / t.registros, 2) AS pct_descartado
FROM t JOIN c USING (taxi_type, src_year)
ORDER BY t.taxi_type, t.src_year;

-- name: q8_6_participacion_verde
-- pregunta: 8.6 Cambia el peso relativo de los taxis verdes frente a los amarillos?
-- objetivo: participacion de cada tipo en el total de viajes por mes (serie completa)
-- fuente: trips_clean
SELECT make_date(src_year, src_month, 1) AS periodo,
       count(*) FILTER (WHERE taxi_type = 'yellow') AS viajes_amarillos,
       count(*) FILTER (WHERE taxi_type = 'green')  AS viajes_verdes,
       round(100.0 * count(*) FILTER (WHERE taxi_type = 'green') / count(*), 3) AS pct_verdes
FROM trips_clean
GROUP BY src_year, src_month
ORDER BY periodo;
