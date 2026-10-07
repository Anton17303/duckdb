-- ============================================================================
-- 05_indicadores.sql  -  Ejercicios 7 y 8: indicadores del tablero
-- Cada consulta se materializa como tabla ind_* en data/processed/indicadores.duckdb
-- (scripts/build_indicators.py). Metabase lee esas tablas pequenas en modo solo
-- lectura. Todas leen DuckDB/Parquet sobre trips_clean (ver docs/transformaciones.md)
-- y cubren automaticamente todos los anios presentes en data/raw/.
-- ============================================================================

-- name: ind_01_viajes_mensuales
-- pregunta: Como evoluciona el volumen de viajes de cada taxi mes a mes?
-- objetivo: serie mensual de viajes por tipo de taxi
-- visualizacion: lineas (x = mes, y = viajes, serie = tipo)
-- fuente: trips_clean
SELECT taxi_type, make_date(src_year, src_month, 1) AS periodo, count(*) AS viajes
FROM trips_clean
GROUP BY taxi_type, src_year, src_month
ORDER BY taxi_type, periodo;

-- name: ind_02_ingreso_mensual
-- pregunta: Cuanto ingreso generan los viajes y cuanto deja cada uno?
-- objetivo: ingreso total (USD) e ingreso medio por viaje, mensual y por tipo
-- visualizacion: barras o lineas (x = mes, y = ingreso)
-- fuente: trips_clean
SELECT taxi_type, make_date(src_year, src_month, 1) AS periodo,
       round(sum(total_amount), 2) AS ingreso_total,
       round(avg(total_amount), 2) AS ingreso_por_viaje
FROM trips_clean
GROUP BY taxi_type, src_year, src_month
ORDER BY taxi_type, periodo;

-- name: ind_03_demanda_por_hora
-- pregunta: A que horas se concentra la demanda y cambia entre dias laborales y fines de semana?
-- objetivo: participacion porcentual de viajes por hora, por tipo de taxi y tipo de dia
-- visualizacion: lineas (x = hora, y = % de viajes, serie = tipo de dia)
-- fuente: trips_clean
SELECT taxi_type,
       CASE WHEN isodow(pickup_ts) >= 6 THEN 'fin de semana' ELSE 'laboral' END AS dia_tipo,
       hour(pickup_ts) AS hora,
       count(*) AS viajes,
       round(100.0 * count(*) / sum(count(*)) OVER (
             PARTITION BY taxi_type, CASE WHEN isodow(pickup_ts) >= 6 THEN 'fin de semana' ELSE 'laboral' END), 2) AS pct_viajes
FROM trips_clean
GROUP BY taxi_type, CASE WHEN isodow(pickup_ts) >= 6 THEN 'fin de semana' ELSE 'laboral' END, hour(pickup_ts)
ORDER BY taxi_type, dia_tipo, hora;

-- name: ind_04_viaje_tipico_mensual
-- pregunta: Como cambia el viaje tipico (tarifa, distancia, duracion) con el tiempo?
-- objetivo: tarifa, distancia y duracion medias por mes y tipo de taxi
-- visualizacion: lineas (x = mes, y = tarifa media; distancia/duracion como series adicionales)
-- fuente: trips_clean
SELECT taxi_type, make_date(src_year, src_month, 1) AS periodo,
       round(avg(fare_amount), 2)   AS tarifa_media,
       round(avg(trip_distance), 2) AS distancia_media_mi,
       round(avg(duration_min), 1)  AS duracion_media_min
FROM trips_clean
GROUP BY taxi_type, src_year, src_month
ORDER BY taxi_type, periodo;

-- name: ind_05_metodo_pago_anual
-- pregunta: Como pagan los pasajeros y ha cambiado la preferencia entre anios?
-- objetivo: participacion de cada metodo de pago por tipo de taxi y anio
-- visualizacion: barras apiladas al 100 % (x = tipo-anio, color = metodo)
-- fuente: trips_clean
SELECT taxi_type, src_year,
       CASE payment_type WHEN 1 THEN 'tarjeta' WHEN 2 THEN 'efectivo' WHEN 3 THEN 'sin cargo'
            WHEN 4 THEN 'disputa' ELSE 'otro/desconocido' END AS metodo,
       count(*) AS viajes,
       round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY taxi_type, src_year), 2) AS pct
FROM trips_clean
GROUP BY taxi_type, src_year,
         CASE payment_type WHEN 1 THEN 'tarjeta' WHEN 2 THEN 'efectivo' WHEN 3 THEN 'sin cargo'
              WHEN 4 THEN 'disputa' ELSE 'otro/desconocido' END
ORDER BY taxi_type, src_year, viajes DESC;

-- name: ind_06_propina_mensual
-- pregunta: Cuanta propina dejan los pasajeros que pagan con tarjeta y como evoluciona?
-- objetivo: propina media como % de la tarifa (solo tarjeta) y % de viajes sin propina, por mes y tipo
-- visualizacion: lineas (x = mes, y = % de propina)
-- fuente: trips_clean (payment_type = 1)
SELECT taxi_type, make_date(src_year, src_month, 1) AS periodo,
       round(100 * avg(tip_amount / fare_amount), 2)                         AS pct_propina_medio,
       round(100.0 * count(*) FILTER (WHERE tip_amount = 0) / count(*), 2)   AS pct_sin_propina
FROM trips_clean
WHERE payment_type = 1
GROUP BY taxi_type, src_year, src_month
ORDER BY taxi_type, periodo;

-- name: ind_07_distribucion_distancia
-- pregunta: Que tan largos son los viajes y se diferencian los dos tipos de taxi?
-- objetivo: distribucion de viajes por tramo de distancia
-- visualizacion: barras agrupadas (x = tramo, y = % de viajes, serie = tipo)
-- fuente: trips_clean
SELECT taxi_type,
       CASE WHEN trip_distance < 1 THEN '0-1' WHEN trip_distance < 3 THEN '1-3' WHEN trip_distance < 5 THEN '3-5'
            WHEN trip_distance < 10 THEN '5-10' WHEN trip_distance < 20 THEN '10-20' ELSE '20+' END AS tramo_millas,
       CASE WHEN trip_distance < 1 THEN 1 WHEN trip_distance < 3 THEN 2 WHEN trip_distance < 5 THEN 3
            WHEN trip_distance < 10 THEN 4 WHEN trip_distance < 20 THEN 5 ELSE 6 END AS orden,
       count(*) AS viajes,
       round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY taxi_type), 2) AS pct
FROM trips_clean
GROUP BY taxi_type, 2, 3
ORDER BY taxi_type, orden;

-- name: ind_08_top_zonas_recogida
-- pregunta: Cuales son las zonas donde mas pasajeros se recogen en cada tipo de taxi?
-- objetivo: las 10 zonas con mas recogidas por tipo de taxi (nombre de zona y borough)
-- visualizacion: barras horizontales (una por tipo)
-- fuente: trips_clean + zones (taxi_zone_lookup.csv)
WITH conteo AS (
    SELECT taxi_type, pu_location_id, count(*) AS viajes FROM trips_clean GROUP BY taxi_type, pu_location_id
), ranking AS (
    SELECT *, row_number() OVER (PARTITION BY taxi_type ORDER BY viajes DESC, pu_location_id) AS posicion,
           round(100.0 * viajes / sum(viajes) OVER (PARTITION BY taxi_type), 2) AS pct
    FROM conteo
)
SELECT r.taxi_type, r.posicion, r.pu_location_id AS location_id,
       coalesce(z.zone, 'Zona ' || r.pu_location_id) AS zona,
       coalesce(z.borough, 'N/D') AS borough, r.viajes, r.pct
FROM ranking r LEFT JOIN zones z ON z.location_id = r.pu_location_id
WHERE r.posicion <= 10
ORDER BY r.taxi_type, r.posicion;

-- name: ind_09_velocidad_por_hora
-- pregunta: Como cambia la velocidad media de los viajes a lo largo del dia (congestion)?
-- objetivo: velocidad media (mph) por hora de recogida y tipo (viajes con duracion >= 1 min)
-- visualizacion: lineas (x = hora, y = mph)
-- fuente: trips_clean
SELECT taxi_type, hour(pickup_ts) AS hora,
       round(avg(trip_distance / (duration_min / 60.0)), 2) AS velocidad_media_mph,
       count(*) AS viajes
FROM trips_clean
WHERE duration_min >= 1
GROUP BY taxi_type, hour(pickup_ts)
ORDER BY taxi_type, hora;

-- name: ind_10_calidad_mensual
-- pregunta: Que proporcion de los registros se descarta por calidad y mejora o empeora con el tiempo?
-- objetivo: registros totales, conservados y % descartado por mes y tipo
-- visualizacion: lineas o barras (x = mes, y = % descartado)
-- fuente: trips (sin depurar) y trips_clean
WITH total AS (
    SELECT taxi_type, src_year, src_month, count(*) AS registros FROM trips GROUP BY ALL
), limpios AS (
    SELECT taxi_type, src_year, src_month, count(*) AS conservados FROM trips_clean GROUP BY ALL
)
SELECT t.taxi_type, make_date(t.src_year, t.src_month, 1) AS periodo,
       t.registros, coalesce(l.conservados, 0) AS conservados,
       round(100.0 * (t.registros - coalesce(l.conservados, 0)) / t.registros, 2) AS pct_descartado
FROM total t LEFT JOIN limpios l USING (taxi_type, src_year, src_month)
ORDER BY t.taxi_type, periodo;
