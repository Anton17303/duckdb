-- ============================================================================
-- 02_eda.sql  -  Ejercicio 4: analisis exploratorio con DuckDB
-- Las preguntas se justifican a partir de lo observado en 01_exploracion.sql:
--   * existen registros incoherentes (fechas, distancias, importes) -> se
--     cuantifican (P9) y se analiza sobre la vista trips_clean (docs/transformaciones.md);
--   * los dos taxis tienen servicios y zonas distintos -> se comparan (P5, P11);
--   * hay varios codigos de pago y la propina solo se registra con tarjeta -> P6.
-- Salvo indicacion, las consultas usan trips_clean (datos depurados).
-- ============================================================================

-- name: q4_p1_viajes_mensuales
-- pregunta: P1 Como evoluciona el numero de viajes y el ingreso mes a mes para cada tipo de taxi?
-- objetivo: serie mensual de viajes, ingreso total y tarifa media por tipo
-- fuente: trips_clean (data/raw/{yellow,green}/*/*.parquet)
SELECT taxi_type, src_year, src_month,
       count(*)                       AS viajes,
       round(sum(total_amount), 0)    AS ingreso_total,
       round(avg(total_amount), 2)    AS total_medio
FROM trips_clean
GROUP BY ALL
ORDER BY taxi_type, src_year, src_month;

-- name: q4_p1b_viajes_diarios
-- pregunta: P1b Hay dias con volumen anomalo (feriados, tormentas, fallas de datos)?
-- objetivo: serie diaria y z-score respecto al promedio del mes y tipo; lista los 15 dias mas atipicos
-- fuente: trips_clean
WITH diario AS (
    SELECT taxi_type, CAST(pickup_ts AS DATE) AS dia, count(*) AS viajes
    FROM trips_clean GROUP BY ALL
), z AS (
    SELECT *, (viajes - avg(viajes) OVER w) / nullif(stddev_pop(viajes) OVER w, 0) AS z_score
    FROM diario
    WINDOW w AS (PARTITION BY taxi_type, date_trunc('month', dia))
)
SELECT taxi_type, dia, dayname(dia) AS dia_semana, viajes, round(z_score, 2) AS z_score
FROM z
ORDER BY abs(z_score) DESC NULLS LAST
LIMIT 15;

-- name: q4_p2_demanda_por_hora
-- pregunta: P2 A que horas del dia se concentra la demanda y cambia el patron entre taxis?
-- objetivo: participacion porcentual de viajes por hora de recogida y tipo
-- fuente: trips_clean
SELECT taxi_type,
       hour(pickup_ts)                                                       AS hora,
       count(*)                                                              AS viajes,
       round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY taxi_type), 2) AS pct_viajes
FROM trips_clean
GROUP BY taxi_type, hour(pickup_ts)
ORDER BY taxi_type, hora;

-- name: q4_p3_demanda_dia_semana
-- pregunta: P3 Cambia la demanda entre dias laborales y fin de semana?
-- objetivo: viajes y propina/tarifa media por dia de la semana (1=lunes ... 7=domingo)
-- fuente: trips_clean
SELECT taxi_type,
       isodow(pickup_ts)           AS dia_iso,
       dayname(pickup_ts)          AS dia,
       count(*)                    AS viajes,
       round(avg(total_amount), 2) AS total_medio,
       round(avg(trip_distance), 2) AS distancia_media
FROM trips_clean
GROUP BY ALL
ORDER BY taxi_type, dia_iso;

-- name: q4_p4_caracteristicas_viaje
-- pregunta: P4 Cuales son la distancia, duracion y tarifa tipicas de un viaje?
-- objetivo: percentiles (p05, p25, mediana, p75, p95, p99) por tipo para distancia, duracion y tarifa
-- fuente: trips_clean
SELECT taxi_type,
       round(quantile_cont(trip_distance, 0.05), 2) AS dist_p05,
       round(quantile_cont(trip_distance, 0.50), 2) AS dist_mediana,
       round(quantile_cont(trip_distance, 0.95), 2) AS dist_p95,
       round(quantile_cont(trip_distance, 0.99), 2) AS dist_p99,
       round(quantile_cont(duration_min, 0.50), 1)  AS dur_min_mediana,
       round(quantile_cont(duration_min, 0.95), 1)  AS dur_min_p95,
       round(quantile_cont(fare_amount, 0.50), 2)   AS tarifa_mediana,
       round(quantile_cont(fare_amount, 0.95), 2)   AS tarifa_p95
FROM trips_clean
GROUP BY taxi_type;

-- name: q4_p4b_pasajeros
-- pregunta: P4b Cuantos pasajeros viajan normalmente?
-- objetivo: distribucion del numero de pasajeros por tipo (incluye nulos y ceros, que son datos de baja calidad)
-- fuente: trips_clean
SELECT taxi_type,
       coalesce(CAST(passenger_count AS VARCHAR), 'NULL') AS pasajeros,
       count(*)                                           AS viajes,
       round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY taxi_type), 2) AS pct
FROM trips_clean
GROUP BY taxi_type, passenger_count
ORDER BY taxi_type, viajes DESC;

-- name: q4_p5_amarillo_vs_verde
-- pregunta: P5 En que se diferencian los taxis amarillos y los verdes?
-- objetivo: comparacion de volumen, distancia, duracion, velocidad, tarifa, propina y pasajeros
-- fuente: trips_clean
SELECT taxi_type,
       count(*)                                           AS viajes,
       round(avg(trip_distance), 2)                       AS distancia_media_mi,
       round(avg(duration_min), 1)                        AS duracion_media_min,
       round(avg(trip_distance / (duration_min / 60.0)), 1) AS velocidad_media_mph,
       round(avg(fare_amount), 2)                         AS tarifa_media,
       round(avg(total_amount), 2)                        AS total_medio,
       round(avg(tip_amount), 2)                          AS propina_media,
       round(avg(passenger_count), 2)                     AS pasajeros_medios
FROM trips_clean
GROUP BY taxi_type;

-- name: q4_p6_metodos_de_pago
-- pregunta: P6 Como pagan los pasajeros y como cambia por tipo de taxi?
-- objetivo: participacion de cada payment_type por tipo (1=tarjeta, 2=efectivo, 3=sin cargo, 4=disputa, 0=desconocido)
-- fuente: trips_clean
SELECT taxi_type, payment_type,
       CASE payment_type WHEN 0 THEN 'flex fare/desconocido' WHEN 1 THEN 'tarjeta' WHEN 2 THEN 'efectivo'
            WHEN 3 THEN 'sin cargo' WHEN 4 THEN 'disputa' WHEN 5 THEN 'desconocido' WHEN 6 THEN 'anulado'
            ELSE 'otro' END AS metodo,
       count(*)                                                                  AS viajes,
       round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY taxi_type), 2)  AS pct,
       round(avg(tip_amount), 2)                                                 AS propina_media
FROM trips_clean
GROUP BY taxi_type, payment_type
ORDER BY taxi_type, viajes DESC;

-- name: q4_p6b_propina_tarjeta
-- pregunta: P6b Que porcentaje de propina dejan quienes pagan con tarjeta?
-- objetivo: propina como % de la tarifa (solo tarjeta, donde la propina se registra) por tipo y anio
-- fuente: trips_clean
SELECT taxi_type, src_year,
       round(100 * avg(tip_amount / fare_amount), 2)                  AS pct_propina_medio,
       round(100 * quantile_cont(tip_amount / fare_amount, 0.5), 2)   AS pct_propina_mediana,
       round(100.0 * count(*) FILTER (WHERE tip_amount = 0) / count(*), 2) AS pct_sin_propina
FROM trips_clean
WHERE payment_type = 1
GROUP BY ALL
ORDER BY taxi_type, src_year;

-- name: q4_p7_histograma_tarifa
-- pregunta: P7 Como se distribuye la tarifa?
-- objetivo: histograma de tarifa en bloques de 5 USD (hasta 100; mayores agrupados)
-- fuente: trips_clean
SELECT taxi_type,
       least(CAST(floor(fare_amount / 5) AS INTEGER) * 5, 100) AS tarifa_desde,
       count(*)                                                AS viajes
FROM trips_clean
GROUP BY ALL
ORDER BY taxi_type, tarifa_desde;

-- name: q4_p7b_histograma_distancia
-- pregunta: P7b Como se distribuye la distancia?
-- objetivo: histograma de distancia en bloques de 1 milla (hasta 20; mayores agrupadas)
-- fuente: trips_clean
SELECT taxi_type,
       least(CAST(floor(trip_distance) AS INTEGER), 20) AS milla_desde,
       count(*)                                         AS viajes
FROM trips_clean
GROUP BY ALL
ORDER BY taxi_type, milla_desde;

-- name: q4_p8_valores_atipicos
-- pregunta: P8 Cuantos valores atipicos quedan incluso despues de la limpieza basica?
-- objetivo: contar outliers por regla de Tukey (Q3 + 3*IQR) y velocidades implausibles, sobre trips_clean
-- fuente: trips_clean
WITH lim AS (
    SELECT taxi_type,
           quantile_cont(fare_amount, 0.75)    + 3 * (quantile_cont(fare_amount, 0.75)    - quantile_cont(fare_amount, 0.25))    AS lim_tarifa,
           quantile_cont(trip_distance, 0.75)  + 3 * (quantile_cont(trip_distance, 0.75)  - quantile_cont(trip_distance, 0.25))  AS lim_distancia
    FROM trips_clean GROUP BY taxi_type
)
SELECT t.taxi_type,
       count(*)                                                                   AS viajes,
       any_value(l.lim_tarifa)                                                    AS limite_tarifa,
       count(*) FILTER (WHERE t.fare_amount   > l.lim_tarifa)                     AS tarifas_atipicas,
       any_value(l.lim_distancia)                                                 AS limite_distancia,
       count(*) FILTER (WHERE t.trip_distance > l.lim_distancia)                  AS distancias_atipicas,
       count(*) FILTER (WHERE t.trip_distance / (t.duration_min / 60.0) > 80)     AS velocidad_mayor_80mph,
       count(*) FILTER (WHERE t.trip_distance / (t.duration_min / 60.0) < 1)      AS velocidad_menor_1mph
FROM trips_clean t JOIN lim l USING (taxi_type)
GROUP BY t.taxi_type;

-- name: q4_p8b_top_extremos
-- pregunta: P8b Cuales son los registros mas extremos?
-- objetivo: inspeccionar los 10 viajes con mayor tarifa en los datos SIN limpiar para entender que se descarta
-- fuente: trips (sin depurar)
SELECT taxi_type, pickup_ts, dropoff_ts, trip_distance, fare_amount, total_amount, payment_type
FROM trips
ORDER BY fare_amount DESC
LIMIT 10;

-- name: q4_p9_reglas_limpieza
-- pregunta: P9 Cuantos registros elimina cada regla de limpieza (R1-R6)?
-- objetivo: cuantificar el efecto de cada regla de trips_clean (un registro puede incumplir varias)
-- fuente: trips (sin depurar)
SELECT taxi_type,
       count(*)                                                                                  AS registros,
       count(*) FILTER (WHERE NOT (year(pickup_ts) = src_year AND month(pickup_ts) = src_month)) AS r1_fuera_de_periodo,
       count(*) FILTER (WHERE NOT (dropoff_ts > pickup_ts))                                      AS r2_llegada_no_posterior,
       count(*) FILTER (WHERE date_diff('second', pickup_ts, dropoff_ts) > 6 * 3600)             AS r3_duracion_mayor_6h,
       count(*) FILTER (WHERE NOT (trip_distance > 0 AND trip_distance <= 100))                  AS r4_distancia_invalida,
       count(*) FILTER (WHERE NOT (fare_amount > 0))                                             AS r5_tarifa_no_positiva,
       count(*) FILTER (WHERE NOT (total_amount > 0 AND total_amount <= 1000))                   AS r6_total_invalido,
       (SELECT count(*) FROM trips_clean c WHERE c.taxi_type = t.taxi_type)                      AS registros_conservados
FROM trips t
GROUP BY taxi_type;

-- name: q4_p10_tarifa_por_milla
-- pregunta: P10 La tarifa crece de forma coherente con la distancia?
-- objetivo: tarifa mediana y total medio por tramo de distancia (viajes cortos tienen minimos y recargos)
-- fuente: trips_clean
SELECT taxi_type,
       CASE WHEN trip_distance < 1 THEN '0-1' WHEN trip_distance < 3 THEN '1-3' WHEN trip_distance < 5 THEN '3-5'
            WHEN trip_distance < 10 THEN '5-10' WHEN trip_distance < 20 THEN '10-20' ELSE '20+' END AS tramo_millas,
       count(*)                                          AS viajes,
       round(quantile_cont(fare_amount, 0.5), 2)         AS tarifa_mediana,
       round(avg(fare_amount / trip_distance), 2)        AS tarifa_por_milla_media
FROM trips_clean
GROUP BY ALL
ORDER BY taxi_type, min(trip_distance);

-- name: q4_p11_zonas_recogida
-- pregunta: P11 Donde recogen pasajeros los taxis amarillos y los verdes?
-- objetivo: participacion por borough de recogida (requiere data/raw/zones/taxi_zone_lookup.csv)
-- fuente: trips_clean + zones
SELECT t.taxi_type,
       coalesce(z.borough, 'Sin zona') AS borough,
       count(*)                        AS viajes,
       round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY t.taxi_type), 2) AS pct
FROM trips_clean t LEFT JOIN zones z ON z.location_id = t.pu_location_id
GROUP BY t.taxi_type, z.borough
ORDER BY t.taxi_type, viajes DESC;
