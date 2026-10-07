# Indicadores materializados

Generado: 2026-10-07 03:29 con `python scripts/build_indicators.py`. Tablas en `data/processed/indicadores.duckdb`.

## ind_01_viajes_mensuales
- **Pregunta:** Como evoluciona el volumen de viajes de cada taxi mes a mes?
- **Objetivo:** serie mensual de viajes por tipo de taxi
- **Visualizacion:** lineas (x = mes, y = viajes, serie = tipo)
- **Fuente:** trips_clean
- **Tiempo:** 2.43 s, 64 filas

```sql
SELECT taxi_type, make_date(src_year, src_month, 1) AS periodo, count(*) AS viajes
FROM trips_clean
GROUP BY taxi_type, src_year, src_month
ORDER BY taxi_type, periodo;
```

| taxi_type | periodo | viajes |
|---|---|---|
| green | 2024-01-01 00:00:00 | 53302 |
| green | 2024-02-01 00:00:00 | 50394 |
| green | 2024-03-01 00:00:00 | 54094 |
| green | 2024-04-01 00:00:00 | 52931 |
| green | 2024-05-01 00:00:00 | 57455 |
| green | 2024-06-01 00:00:00 | 51671 |
| green | 2024-07-01 00:00:00 | 48484 |
| green | 2024-08-01 00:00:00 | 48658 |
| green | 2024-09-01 00:00:00 | 51241 |
| green | 2024-10-01 00:00:00 | 53155 |
| green | 2024-11-01 00:00:00 | 49065 |
| green | 2024-12-01 00:00:00 | 50580 |

_Se muestran 12 de 64 filas._


## ind_02_ingreso_mensual
- **Pregunta:** Cuanto ingreso generan los viajes y cuanto deja cada uno?
- **Objetivo:** ingreso total (USD) e ingreso medio por viaje, mensual y por tipo
- **Visualizacion:** barras o lineas (x = mes, y = ingreso)
- **Fuente:** trips_clean
- **Tiempo:** 1.65 s, 64 filas

```sql
SELECT taxi_type, make_date(src_year, src_month, 1) AS periodo,
       round(sum(total_amount), 2) AS ingreso_total,
       round(avg(total_amount), 2) AS ingreso_por_viaje
FROM trips_clean
GROUP BY taxi_type, src_year, src_month
ORDER BY taxi_type, periodo;
```

| taxi_type | periodo | ingreso_total | ingreso_por_viaje |
|---|---|---|---|
| green | 2024-01-01 00:00:00 | 1183294.21 | 22.2 |
| green | 2024-02-01 00:00:00 | 1132751.26 | 22.48 |
| green | 2024-03-01 00:00:00 | 1231554.24 | 22.77 |
| green | 2024-04-01 00:00:00 | 1233211.1 | 23.3 |
| green | 2024-05-01 00:00:00 | 1408094.5 | 24.51 |
| green | 2024-06-01 00:00:00 | 1281056.72 | 24.79 |
| green | 2024-07-01 00:00:00 | 1187855.05 | 24.5 |
| green | 2024-08-01 00:00:00 | 1260952.95 | 25.91 |
| green | 2024-09-01 00:00:00 | 1361258.04 | 26.57 |
| green | 2024-10-01 00:00:00 | 1329416.35 | 25.01 |
| green | 2024-11-01 00:00:00 | 1178053.59 | 24.01 |
| green | 2024-12-01 00:00:00 | 1205132.0 | 23.83 |

_Se muestran 12 de 64 filas._


## ind_03_demanda_por_hora
- **Pregunta:** A que horas se concentra la demanda y cambia entre dias laborales y fines de semana?
- **Objetivo:** participacion porcentual de viajes por hora, por tipo de taxi y tipo de dia
- **Visualizacion:** lineas (x = hora, y = % de viajes, serie = tipo de dia)
- **Fuente:** trips_clean
- **Tiempo:** 1.86 s, 96 filas

```sql
SELECT taxi_type,
       CASE WHEN isodow(pickup_ts) >= 6 THEN 'fin de semana' ELSE 'laboral' END AS dia_tipo,
       hour(pickup_ts) AS hora,
       count(*) AS viajes,
       round(100.0 * count(*) / sum(count(*)) OVER (
             PARTITION BY taxi_type, CASE WHEN isodow(pickup_ts) >= 6 THEN 'fin de semana' ELSE 'laboral' END), 2) AS pct_viajes
FROM trips_clean
GROUP BY taxi_type, CASE WHEN isodow(pickup_ts) >= 6 THEN 'fin de semana' ELSE 'laboral' END, hour(pickup_ts)
ORDER BY taxi_type, dia_tipo, hora;
```

| taxi_type | dia_tipo | hora | viajes | pct_viajes |
|---|---|---|---|---|
| green | fin de semana | 0 | 10812 | 3.01 |
| green | fin de semana | 1 | 8547 | 2.38 |
| green | fin de semana | 2 | 7087 | 1.97 |
| green | fin de semana | 3 | 6067 | 1.69 |
| green | fin de semana | 4 | 4667 | 1.3 |
| green | fin de semana | 5 | 2773 | 0.77 |
| green | fin de semana | 6 | 3454 | 0.96 |
| green | fin de semana | 7 | 6218 | 1.73 |
| green | fin de semana | 8 | 8516 | 2.37 |
| green | fin de semana | 9 | 12774 | 3.55 |
| green | fin de semana | 10 | 15649 | 4.36 |
| green | fin de semana | 11 | 18590 | 5.17 |

_Se muestran 12 de 96 filas._


## ind_04_viaje_tipico_mensual
- **Pregunta:** Como cambia el viaje tipico (tarifa, distancia, duracion) con el tiempo?
- **Objetivo:** tarifa, distancia y duracion medias por mes y tipo de taxi
- **Visualizacion:** lineas (x = mes, y = tarifa media; distancia/duracion como series adicionales)
- **Fuente:** trips_clean
- **Tiempo:** 1.63 s, 64 filas

```sql
SELECT taxi_type, make_date(src_year, src_month, 1) AS periodo,
       round(avg(fare_amount), 2)   AS tarifa_media,
       round(avg(trip_distance), 2) AS distancia_media_mi,
       round(avg(duration_min), 1)  AS duracion_media_min
FROM trips_clean
GROUP BY taxi_type, src_year, src_month
ORDER BY taxi_type, periodo;
```

| taxi_type | periodo | tarifa_media | distancia_media_mi | duracion_media_min |
|---|---|---|---|---|
| green | 2024-01-01 00:00:00 | 16.59 | 2.76 | 13.9 |
| green | 2024-02-01 00:00:00 | 16.77 | 2.79 | 14.0 |
| green | 2024-03-01 00:00:00 | 17.03 | 2.77 | 14.3 |
| green | 2024-04-01 00:00:00 | 17.3 | 2.81 | 14.3 |
| green | 2024-05-01 00:00:00 | 18.33 | 2.94 | 15.3 |
| green | 2024-06-01 00:00:00 | 18.65 | 3.03 | 15.1 |
| green | 2024-07-01 00:00:00 | 18.34 | 3.03 | 14.5 |
| green | 2024-08-01 00:00:00 | 19.56 | 3.26 | 15.0 |
| green | 2024-09-01 00:00:00 | 20.13 | 3.25 | 15.9 |
| green | 2024-10-01 00:00:00 | 18.75 | 3.01 | 15.2 |
| green | 2024-11-01 00:00:00 | 17.93 | 2.86 | 15.0 |
| green | 2024-12-01 00:00:00 | 17.78 | 2.81 | 14.9 |

_Se muestran 12 de 64 filas._


## ind_05_metodo_pago_anual
- **Pregunta:** Como pagan los pasajeros y ha cambiado la preferencia entre anios?
- **Objetivo:** participacion de cada metodo de pago por tipo de taxi y anio
- **Visualizacion:** barras apiladas al 100 % (x = tipo-anio, color = metodo)
- **Fuente:** trips_clean
- **Tiempo:** 1.70 s, 30 filas

```sql
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
```

| taxi_type | src_year | metodo | viajes | pct |
|---|---|---|---|---|
| green | 2024 | tarjeta | 426982 | 68.75 |
| green | 2024 | efectivo | 167933 | 27.04 |
| green | 2024 | otro/desconocido | 23465 | 3.78 |
| green | 2024 | sin cargo | 1969 | 0.32 |
| green | 2024 | disputa | 681 | 0.11 |
| green | 2025 | tarjeta | 387074 | 69.29 |
| green | 2025 | efectivo | 124587 | 22.3 |
| green | 2025 | otro/desconocido | 44873 | 8.03 |
| green | 2025 | sin cargo | 1564 | 0.28 |
| green | 2025 | disputa | 520 | 0.09 |
| green | 2026 | tarjeta | 211691 | 66.57 |
| green | 2026 | efectivo | 62586 | 19.68 |

_Se muestran 12 de 30 filas._


## ind_06_propina_mensual
- **Pregunta:** Cuanta propina dejan los pasajeros que pagan con tarjeta y como evoluciona?
- **Objetivo:** propina media como % de la tarifa (solo tarjeta) y % de viajes sin propina, por mes y tipo
- **Visualizacion:** lineas (x = mes, y = % de propina)
- **Fuente:** trips_clean (payment_type = 1)
- **Tiempo:** 1.68 s, 64 filas

```sql
SELECT taxi_type, make_date(src_year, src_month, 1) AS periodo,
       round(100 * avg(tip_amount / fare_amount), 2)                         AS pct_propina_medio,
       round(100.0 * count(*) FILTER (WHERE tip_amount = 0) / count(*), 2)   AS pct_sin_propina
FROM trips_clean
WHERE payment_type = 1
GROUP BY taxi_type, src_year, src_month
ORDER BY taxi_type, periodo;
```

| taxi_type | periodo | pct_propina_medio | pct_sin_propina |
|---|---|---|---|
| green | 2024-01-01 00:00:00 | 22.77 | 8.46 |
| green | 2024-02-01 00:00:00 | 22.46 | 8.77 |
| green | 2024-03-01 00:00:00 | 22.42 | 8.61 |
| green | 2024-04-01 00:00:00 | 22.5 | 8.38 |
| green | 2024-05-01 00:00:00 | 22.25 | 8.56 |
| green | 2024-06-01 00:00:00 | 22.08 | 8.94 |
| green | 2024-07-01 00:00:00 | 22.36 | 8.74 |
| green | 2024-08-01 00:00:00 | 22.18 | 9.72 |
| green | 2024-09-01 00:00:00 | 22.09 | 9.08 |
| green | 2024-10-01 00:00:00 | 22.31 | 8.59 |
| green | 2024-11-01 00:00:00 | 22.41 | 8.76 |
| green | 2024-12-01 00:00:00 | 22.63 | 8.78 |

_Se muestran 12 de 64 filas._


## ind_07_distribucion_distancia
- **Pregunta:** Que tan largos son los viajes y se diferencian los dos tipos de taxi?
- **Objetivo:** distribucion de viajes por tramo de distancia
- **Visualizacion:** barras agrupadas (x = tramo, y = % de viajes, serie = tipo)
- **Fuente:** trips_clean
- **Tiempo:** 2.07 s, 12 filas

```sql
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
```

| taxi_type | tramo_millas | orden | viajes | pct |
|---|---|---|---|---|
| green | 0-1 | 1 | 223920 | 14.95 |
| green | 1-3 | 2 | 808088 | 53.96 |
| green | 3-5 | 3 | 229902 | 15.35 |
| green | 5-10 | 4 | 168707 | 11.26 |
| green | 10-20 | 5 | 60205 | 4.02 |
| green | 20+ | 6 | 6813 | 0.45 |
| yellow | 0-1 | 1 | 23857298 | 21.29 |
| yellow | 1-3 | 2 | 53476756 | 47.72 |
| yellow | 3-5 | 3 | 14049405 | 12.54 |
| yellow | 5-10 | 4 | 11719133 | 10.46 |
| yellow | 10-20 | 5 | 7917074 | 7.07 |
| yellow | 20+ | 6 | 1037910 | 0.93 |


## ind_08_top_zonas_recogida
- **Pregunta:** Cuales son las zonas donde mas pasajeros se recogen en cada tipo de taxi?
- **Objetivo:** las 10 zonas con mas recogidas por tipo de taxi (nombre de zona y borough)
- **Visualizacion:** barras horizontales (una por tipo)
- **Fuente:** trips_clean + zones (taxi_zone_lookup.csv)
- **Tiempo:** 1.59 s, 20 filas

```sql
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
```

| taxi_type | posicion | location_id | zona | borough | viajes | pct |
|---|---|---|---|---|---|---|
| green | 1 | 74 | East Harlem North | Manhattan | 376223 | 25.12 |
| green | 2 | 75 | East Harlem South | Manhattan | 212422 | 14.18 |
| green | 3 | 95 | Forest Hills | Queens | 72742 | 4.86 |
| green | 4 | 43 | Central Park | Manhattan | 72316 | 4.83 |
| green | 5 | 166 | Morningside Heights | Manhattan | 71177 | 4.75 |
| green | 6 | 41 | Central Harlem | Manhattan | 61878 | 4.13 |
| green | 7 | 82 | Elmhurst | Queens | 61076 | 4.08 |
| green | 8 | 97 | Fort Greene | Brooklyn | 48988 | 3.27 |
| green | 9 | 65 | Downtown Brooklyn/MetroTech | Brooklyn | 44546 | 2.97 |
| green | 10 | 130 | Jamaica | Queens | 41524 | 2.77 |
| yellow | 1 | 237 | Upper East Side South | Manhattan | 5121765 | 4.57 |
| yellow | 2 | 161 | Midtown Center | Manhattan | 4977394 | 4.44 |

_Se muestran 12 de 20 filas._


## ind_09_velocidad_por_hora
- **Pregunta:** Como cambia la velocidad media de los viajes a lo largo del dia (congestion)?
- **Objetivo:** velocidad media (mph) por hora de recogida y tipo (viajes con duracion >= 1 min)
- **Visualizacion:** lineas (x = hora, y = mph)
- **Fuente:** trips_clean
- **Tiempo:** 2.03 s, 48 filas

```sql
SELECT taxi_type, hour(pickup_ts) AS hora,
       round(avg(trip_distance / (duration_min / 60.0)), 2) AS velocidad_media_mph,
       count(*) AS viajes
FROM trips_clean
WHERE duration_min >= 1
GROUP BY taxi_type, hour(pickup_ts)
ORDER BY taxi_type, hora;
```

| taxi_type | hora | velocidad_media_mph | viajes |
|---|---|---|---|
| green | 0 | 14.61 | 23889 |
| green | 1 | 14.79 | 15824 |
| green | 2 | 15.71 | 11054 |
| green | 3 | 16.74 | 8463 |
| green | 4 | 18.0 | 7573 |
| green | 5 | 18.47 | 9072 |
| green | 6 | 14.63 | 25634 |
| green | 7 | 12.05 | 57123 |
| green | 8 | 11.04 | 73478 |
| green | 9 | 11.48 | 78784 |
| green | 10 | 11.55 | 77804 |
| green | 11 | 11.45 | 77635 |

_Se muestran 12 de 48 filas._


## ind_10_calidad_mensual
- **Pregunta:** Que proporcion de los registros se descarta por calidad y mejora o empeora con el tiempo?
- **Objetivo:** registros totales, conservados y % descartado por mes y tipo
- **Visualizacion:** lineas o barras (x = mes, y = % descartado)
- **Fuente:** trips (sin depurar) y trips_clean
- **Tiempo:** 1.49 s, 64 filas

```sql
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
```

| taxi_type | periodo | registros | conservados | pct_descartado |
|---|---|---|---|---|
| green | 2024-01-01 00:00:00 | 56551 | 53302 | 5.75 |
| green | 2024-02-01 00:00:00 | 53577 | 50394 | 5.94 |
| green | 2024-03-01 00:00:00 | 57457 | 54094 | 5.85 |
| green | 2024-04-01 00:00:00 | 56471 | 52931 | 6.27 |
| green | 2024-05-01 00:00:00 | 61003 | 57455 | 5.82 |
| green | 2024-06-01 00:00:00 | 54748 | 51671 | 5.62 |
| green | 2024-07-01 00:00:00 | 51837 | 48484 | 6.47 |
| green | 2024-08-01 00:00:00 | 51771 | 48658 | 6.01 |
| green | 2024-09-01 00:00:00 | 54440 | 51241 | 5.88 |
| green | 2024-10-01 00:00:00 | 56147 | 53155 | 5.33 |
| green | 2024-11-01 00:00:00 | 52222 | 49065 | 6.05 |
| green | 2024-12-01 00:00:00 | 53994 | 50580 | 6.32 |

_Se muestran 12 de 64 filas._

