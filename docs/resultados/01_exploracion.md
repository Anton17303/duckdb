# Resultados de `sql/01_exploracion.sql`
Generado: 2026-10-07 03:08 con `python scripts/run_analysis.py 01_exploracion.sql`.  
Cada bloque documenta: pregunta, objetivo, fuente, consulta SQL, tiempo y resultado. La **decisión/interpretación** de cada resultado se redacta en `docs/informe.md`.

## q3_1_archivos_por_tipo_anio
- **Pregunta:** 3.1 Cuantos archivos hay disponibles?
- **Objetivo:** contar los archivos Parquet por tipo de taxi y anio
- **Fuente:** data/raw/*/*/*.parquet (funcion glob)
- **Tiempo:** 2.10 s, 6 filas

```sql
SELECT split_part(file, '/', 3) AS taxi_type,
       split_part(file, '/', 4) AS anio,
       count(*)                 AS archivos
FROM glob('data/raw/*/*/*.parquet') t(file)
GROUP BY ALL
ORDER BY ALL;
```

**Resultado**

| taxi_type | anio | archivos |
|---|---|---|
| green | 2024 | 12 |
| green | 2025 | 12 |
| green | 2026 | 8 |
| yellow | 2024 | 12 |
| yellow | 2025 | 12 |
| yellow | 2026 | 8 |


## q3_1b_total_archivos
- **Pregunta:** 3.1 Cuantos archivos hay disponibles? (total)
- **Objetivo:** total de archivos Parquet encontrados por el comodin
- **Fuente:** data/raw/*/*/*.parquet
- **Tiempo:** 0.01 s, 1 filas

```sql
SELECT count(*) AS total_archivos FROM glob('data/raw/*/*/*.parquet');
```

**Resultado**

| total_archivos |
|---|
| 64 |


## q3_2_registros_por_tipo_anio
- **Pregunta:** 3.2 Cuantos registros hay disponibles?
- **Objetivo:** contar registros reales (escaneo) por tipo de taxi y anio
- **Fuente:** yellow_raw y green_raw -> data/raw/{yellow,green}/*/*.parquet
- **Tiempo:** 0.09 s, 6 filas

```sql
SELECT taxi_type, src_year, count(*) AS registros
FROM trips
GROUP BY ALL
ORDER BY ALL;
```

**Resultado**

| taxi_type | src_year | registros |
|---|---|---|
| green | 2024 | 660218 |
| green | 2025 | 591375 |
| green | 2026 | 337114 |
| yellow | 2024 | 41169720 |
| yellow | 2025 | 48722602 |
| yellow | 2026 | 29703355 |


## q3_2b_registros_metadatos
- **Pregunta:** 3.2 Cuantos registros hay disponibles? (via metadatos)
- **Objetivo:** obtener el total leyendo solo el pie de cada Parquet (sin escanear datos) y compararlo con count(*)
- **Fuente:** parquet_file_metadata sobre data/raw/*/*/*.parquet
- **Tiempo:** 0.07 s, 1 filas

```sql
SELECT (SELECT CAST(sum(num_rows) AS BIGINT) FROM parquet_file_metadata('data/raw/*/*/*.parquet')) AS filas_segun_metadatos,
       (SELECT count(*) FROM trips)                                                  AS filas_segun_conteo,
       (SELECT sum(num_rows) FROM parquet_file_metadata('data/raw/*/*/*.parquet'))
         = (SELECT count(*) FROM trips)                                              AS coinciden;
```

**Resultado**

| filas_segun_metadatos | filas_segun_conteo | coinciden |
|---|---|---|
| 121184384 | 121184384 | True |


## q3_2c_filas_por_archivo
- **Pregunta:** 3.2 Cuantos registros hay por archivo?
- **Objetivo:** detectar archivos vacios o con volumen anomalo (insumo para el criterio de completitud)
- **Fuente:** parquet_file_metadata sobre data/raw/*/*/*.parquet
- **Tiempo:** 0.01 s, 64 filas

```sql
SELECT regexp_extract(file_name, '(yellow|green)_tripdata_(\d{4}-\d{2})', 1) AS taxi_type,
       regexp_extract(file_name, '(yellow|green)_tripdata_(\d{4}-\d{2})', 2) AS periodo,
       num_rows,
       num_row_groups,
       round(file_size_bytes / 1048576.0, 1)                                 AS mib
FROM parquet_file_metadata('data/raw/*/*/*.parquet')
ORDER BY taxi_type, periodo;
```

**Resultado**

| taxi_type | periodo | num_rows | num_row_groups | mib |
|---|---|---|---|---|
| green | 2024-01 | 56551 | 1 | 1.3 |
| green | 2024-02 | 53577 | 1 | 1.2 |
| green | 2024-03 | 57457 | 1 | 1.3 |
| green | 2024-04 | 56471 | 1 | 1.3 |
| green | 2024-05 | 61003 | 1 | 1.4 |
| green | 2024-06 | 54748 | 1 | 1.3 |
| green | 2024-07 | 51837 | 1 | 1.2 |
| green | 2024-08 | 51771 | 1 | 1.2 |
| green | 2024-09 | 54440 | 1 | 1.3 |
| green | 2024-10 | 56147 | 1 | 1.3 |
| green | 2024-11 | 52222 | 1 | 1.2 |
| green | 2024-12 | 53994 | 1 | 1.3 |
| green | 2025-01 | 48326 | 1 | 1.1 |
| green | 2025-02 | 46621 | 1 | 1.1 |
| green | 2025-03 | 51539 | 1 | 1.2 |
| green | 2025-04 | 52132 | 1 | 1.2 |
| green | 2025-05 | 55399 | 1 | 1.3 |
| green | 2025-06 | 49390 | 1 | 1.2 |
| green | 2025-07 | 48205 | 1 | 1.1 |
| green | 2025-08 | 46306 | 1 | 1.1 |
| green | 2025-09 | 48893 | 1 | 1.2 |
| green | 2025-10 | 49416 | 1 | 1.1 |
| green | 2025-11 | 46912 | 1 | 1.1 |
| green | 2025-12 | 48236 | 1 | 1.1 |
| green | 2026-01 | 40272 | 1 | 0.9 |

_Se muestran 25 de 64 filas._


## q3_3_columnas_yellow
- **Pregunta:** 3.3 / 3.4 Columnas y tipos de los taxis amarillos
- **Objetivo:** esquema que DuckDB infiere al unir todos los archivos amarillos (union_by_name)
- **Fuente:** data/raw/yellow/*/*.parquet
- **Tiempo:** 0.01 s, 21 filas

```sql
DESCRIBE SELECT * EXCLUDE (filename) FROM yellow_raw;
```

**Resultado**

| column_name | column_type | null | key | default | extra |
|---|---|---|---|---|---|
| VendorID | INTEGER | YES |  |  |  |
| tpep_pickup_datetime | TIMESTAMP | YES |  |  |  |
| tpep_dropoff_datetime | TIMESTAMP | YES |  |  |  |
| passenger_count | BIGINT | YES |  |  |  |
| trip_distance | DOUBLE | YES |  |  |  |
| RatecodeID | BIGINT | YES |  |  |  |
| store_and_fwd_flag | VARCHAR | YES |  |  |  |
| PULocationID | INTEGER | YES |  |  |  |
| DOLocationID | INTEGER | YES |  |  |  |
| payment_type | BIGINT | YES |  |  |  |
| fare_amount | DOUBLE | YES |  |  |  |
| extra | DOUBLE | YES |  |  |  |
| mta_tax | DOUBLE | YES |  |  |  |
| tip_amount | DOUBLE | YES |  |  |  |
| tolls_amount | DOUBLE | YES |  |  |  |
| improvement_surcharge | DOUBLE | YES |  |  |  |
| total_amount | DOUBLE | YES |  |  |  |
| congestion_surcharge | DOUBLE | YES |  |  |  |
| Airport_fee | DOUBLE | YES |  |  |  |
| cbd_congestion_fee | DOUBLE | YES |  |  |  |
| request_source | VARCHAR | YES |  |  |  |


## q3_3_columnas_green
- **Pregunta:** 3.3 / 3.4 Columnas y tipos de los taxis verdes
- **Objetivo:** esquema que DuckDB infiere al unir todos los archivos verdes
- **Fuente:** data/raw/green/*/*.parquet
- **Tiempo:** 0.01 s, 22 filas

```sql
DESCRIBE SELECT * EXCLUDE (filename) FROM green_raw;
```

**Resultado**

| column_name | column_type | null | key | default | extra |
|---|---|---|---|---|---|
| VendorID | INTEGER | YES |  |  |  |
| lpep_pickup_datetime | TIMESTAMP | YES |  |  |  |
| lpep_dropoff_datetime | TIMESTAMP | YES |  |  |  |
| store_and_fwd_flag | VARCHAR | YES |  |  |  |
| RatecodeID | BIGINT | YES |  |  |  |
| PULocationID | INTEGER | YES |  |  |  |
| DOLocationID | INTEGER | YES |  |  |  |
| passenger_count | BIGINT | YES |  |  |  |
| trip_distance | DOUBLE | YES |  |  |  |
| fare_amount | DOUBLE | YES |  |  |  |
| extra | DOUBLE | YES |  |  |  |
| mta_tax | DOUBLE | YES |  |  |  |
| tip_amount | DOUBLE | YES |  |  |  |
| tolls_amount | DOUBLE | YES |  |  |  |
| ehail_fee | DOUBLE | YES |  |  |  |
| improvement_surcharge | DOUBLE | YES |  |  |  |
| total_amount | DOUBLE | YES |  |  |  |
| payment_type | BIGINT | YES |  |  |  |
| trip_type | BIGINT | YES |  |  |  |
| congestion_surcharge | DOUBLE | YES |  |  |  |
| cbd_congestion_fee | DOUBLE | YES |  |  |  |
| request_source | VARCHAR | YES |  |  |  |


## q3_4_deriva_de_esquema
- **Pregunta:** 3.4 Los tipos y nombres son estables entre archivos?
- **Objetivo:** detectar columnas con mas de un tipo fisico o nombres con distinta capitalizacion entre archivos
- **Fuente:** parquet_schema sobre data/raw/*/*/*.parquet
- **Tiempo:** 0.04 s, 4 filas

```sql
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
```

**Resultado**

| taxi_type | columna | variantes_de_nombre | tipos_fisicos | archivos_con_la_columna | archivos_totales |
|---|---|---|---|---|---|
| green | cbd_congestion_fee | ['cbd_congestion_fee'] | ['DOUBLE'] | 20 | 32 |
| green | request_source | ['request_source'] | ['BYTE_ARRAY'] | 3 | 32 |
| yellow | cbd_congestion_fee | ['cbd_congestion_fee'] | ['DOUBLE'] | 20 | 32 |
| yellow | request_source | ['request_source'] | ['BYTE_ARRAY'] | 3 | 32 |


## q3_5_muestra_aleatoria
- **Pregunta:** 3.5 Muestra de registros
- **Objetivo:** inspeccionar 10 registros aleatorios de la vista unificada
- **Fuente:** vista trips (yellow + green)
- **Tiempo:** 4.55 s, 10 filas

```sql
SELECT * EXCLUDE (filename) FROM trips USING SAMPLE 10 ROWS;
```

**Resultado**

| taxi_type | vendor_id | pickup_ts | dropoff_ts | passenger_count | trip_distance | ratecode_id | pu_location_id | do_location_id | payment_type | fare_amount | tip_amount | tolls_amount | total_amount | src_year | src_month |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| yellow | 1 | 2024-03-02 19:57:34 | 2024-03-02 20:21:30 | <NA> | 0.0 | <NA> | 75 | 48 | 0 | 22.75 | 0.0 | 0.0 | 26.75 | 2024 | 3 |
| yellow | 2 | 2024-03-02 23:30:06 | 2024-03-02 23:42:03 | <NA> | 1.38 | <NA> | 246 | 79 | 0 | 12.34 | 0.0 | 0.0 | 16.34 | 2024 | 3 |
| yellow | 1 | 2024-03-02 18:23:47 | 2024-03-02 18:39:44 | <NA> | 0.0 | <NA> | 107 | 68 | 0 | 17.38 | 0.0 | 0.0 | 21.38 | 2024 | 3 |
| yellow | 2 | 2024-03-31 21:39:47 | 2024-03-31 21:50:24 | 2 | 1.25 | 1 | 68 | 170 | 1 | 10.7 | 2.5 | 0.0 | 18.2 | 2024 | 3 |
| yellow | 2 | 2024-03-01 19:48:02 | 2024-03-01 20:12:18 | <NA> | 2.63 | <NA> | 164 | 142 | 0 | 22.44 | 0.0 | 0.0 | 26.44 | 2024 | 3 |
| yellow | 2 | 2024-03-02 12:47:44 | 2024-03-02 13:07:19 | <NA> | 2.49 | <NA> | 163 | 158 | 0 | 21.79 | 0.0 | 0.0 | 25.79 | 2024 | 3 |
| yellow | 2 | 2024-03-02 01:32:08 | 2024-03-02 01:45:29 | <NA> | 3.04 | <NA> | 114 | 50 | 0 | 20.14 | 0.0 | 0.0 | 24.14 | 2024 | 3 |
| yellow | 2 | 2024-03-03 01:02:09 | 2024-03-03 01:11:12 | <NA> | 1.17 | <NA> | 249 | 234 | 0 | 12.0 | 0.0 | 0.0 | 16.0 | 2024 | 3 |
| yellow | 2 | 2024-03-03 12:55:48 | 2024-03-03 13:08:35 | <NA> | 2.58 | <NA> | 263 | 140 | 0 | 12.84 | 0.0 | 0.0 | 16.84 | 2024 | 3 |
| yellow | 2 | 2024-03-31 21:07:00 | 2024-03-31 21:34:38 | 3 | 9.92 | 1 | 138 | 231 | 1 | 39.4 | 9.88 | 0.0 | 61.03 | 2024 | 3 |


## q3_5b_primeros_por_tipo
- **Pregunta:** 3.5 Muestra de registros (primeros por tipo)
- **Objetivo:** ver 5 registros de cada tipo de taxi
- **Fuente:** vista trips
- **Tiempo:** 0.08 s, 10 filas

```sql
(SELECT * EXCLUDE (filename) FROM trips WHERE taxi_type = 'yellow' LIMIT 5)
UNION ALL
(SELECT * EXCLUDE (filename) FROM trips WHERE taxi_type = 'green' LIMIT 5);
```

**Resultado**

| taxi_type | vendor_id | pickup_ts | dropoff_ts | passenger_count | trip_distance | ratecode_id | pu_location_id | do_location_id | payment_type | fare_amount | tip_amount | tolls_amount | total_amount | src_year | src_month |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| yellow | 1 | 2024-03-31 20:20:38 | 2024-03-31 20:45:00 | 1 | 9.1 | 1 | 13 | 236 | 1 | 38.0 | 4.0 | 0.0 | 47.0 | 2024 | 3 |
| yellow | 2 | 2024-03-31 20:11:01 | 2024-03-31 20:29:34 | 1 | 5.04 | 1 | 138 | 202 | 1 | 24.0 | 6.3 | 0.0 | 39.55 | 2024 | 3 |
| yellow | 2 | 2024-03-31 20:04:57 | 2024-03-31 20:11:51 | 4 | 0.82 | 1 | 230 | 68 | 2 | 7.9 | 0.0 | 0.0 | 11.9 | 2024 | 3 |
| yellow | 2 | 2024-03-31 20:29:09 | 2024-03-31 20:45:20 | 2 | 2.77 | 1 | 230 | 113 | 1 | 17.0 | 4.4 | 0.0 | 26.4 | 2024 | 3 |
| yellow | 2 | 2024-03-31 20:19:22 | 2024-04-01 00:00:00 | 1 | 10.01 | 1 | 70 | 79 | 1 | 40.1 | 0.0 | 0.0 | 51.85 | 2024 | 3 |
| green | 2 | 2024-04-01 00:18:50 | 2024-04-01 00:19:48 | 1 | 0.15 | 1 | 146 | 146 | 2 | 3.7 | 0.0 | 0.0 | 6.2 | 2024 | 4 |
| green | 2 | 2024-04-01 00:56:16 | 2024-04-01 01:12:56 | 1 | 3.06 | 1 | 65 | 225 | 1 | 17.7 | 4.04 | 0.0 | 24.24 | 2024 | 4 |
| green | 2 | 2024-04-01 00:23:09 | 2024-04-01 00:33:03 | 1 | 1.95 | 1 | 226 | 146 | 1 | 11.4 | 3.48 | 0.0 | 17.38 | 2024 | 4 |
| green | 2 | 2024-03-31 22:34:23 | 2024-03-31 22:45:33 | 1 | 1.93 | 1 | 74 | 116 | 1 | 12.8 | 3.06 | 0.0 | 18.36 | 2024 | 4 |
| green | 2 | 2024-03-31 23:21:41 | 2024-03-31 23:29:40 | 1 | 1.5 | 1 | 236 | 238 | 1 | 10.7 | 0.8 | 0.0 | 16.75 | 2024 | 4 |


## q3_6_resumen_estadistico
- **Pregunta:** 3.6 Que problemas de calidad se observan?
- **Objetivo:** SUMMARIZE (min, max, nulos, cuantiles) de las columnas numericas y de fecha
- **Fuente:** vista trips
- **Tiempo:** 20.70 s, 10 filas

```sql
SUMMARIZE SELECT pickup_ts, dropoff_ts, passenger_count, trip_distance, ratecode_id,
                 payment_type, fare_amount, tip_amount, tolls_amount, total_amount
          FROM trips;
```

**Resultado**

| column_name | column_type | min | max | approx_unique | avg | std | q25 | q50 | q75 | count | null_percentage |
|---|---|---|---|---|---|---|---|---|---|---|---|
| pickup_ts | TIMESTAMP | 2001-01-01 09:23:58 | 2026-08-31 23:59:59 | 59913128 | 2025-05-15 05:10:26.6718 |  | 2024-09-29 10:20:13.160584 | 2025-05-23 18:54:28.451674 | 2025-12-28 22:47:45.930576 | 121184384 | 0.0 |
| dropoff_ts | TIMESTAMP | 2001-01-01 16:09:38 | 2026-09-02 09:39:37 | 57216129 | 2025-05-15 05:27:56.935022 |  | 2024-09-28 15:07:10.333284 | 2025-05-21 23:35:05.154361 | 2025-12-29 03:34:14.817042 | 121184384 | 0.0 |
| passenger_count | INTEGER | 0 | 9 | 11 | 1.2998431293420087 | 0.7520674969983786 | 1 | 1 | 1 | 121184384 | 19.43 |
| trip_distance | DOUBLE | 0.0 | 398608.62 | 11001 | 6.025503830509986 | 563.9447357473014 | 1.0291817155675909 | 1.8152065938042101 | 3.589719448405363 | 121184384 | 0.0 |
| ratecode_id | INTEGER | 1 | 99 | 7 | 3.145861557944567 | 14.01616827428712 | 1 | 1 | 1 | 121184384 | 19.43 |
| payment_type | INTEGER | 0 | 5 | 6 | 0.9807131754571384 | 0.6961368165442248 | 1 | 1 | 1 | 121184384 | 0.1 |
| fare_amount | DOUBLE | -2555.2 | 863372.12 | 26624 | 19.398765019875576 | 101.47400648515493 | 9.295994249211779 | 14.212519783027854 | 23.543870598375985 | 121184384 | 0.0 |
| tip_amount | DOUBLE | -333.33 | 999.99 | 8438 | 2.994752742238867 | 4.015956897618287 | 0.0 | 2.2951357039063525 | 4.042141256202735 | 121184384 | 0.0 |
| tolls_amount | DOUBLE | -148.17 | 1702.88 | 5456 | 0.526096986635493 | 2.181296672060264 | 0.0 | 0.0 | 0.0 | 121184384 | 0.0 |
| total_amount | DOUBLE | -2560.2 | 863380.37 | 61116 | 27.97082857608476 | 102.3751090693265 | 16.07473109477057 | 21.726456930765135 | 31.6516778559572 | 121184384 | 0.0 |


## q3_6b_nulos_por_tipo
- **Pregunta:** 3.6 Cuantos valores nulos hay en las columnas clave?
- **Objetivo:** cuantificar nulos por tipo de taxi
- **Fuente:** vista trips
- **Tiempo:** 0.74 s, 2 filas

```sql
SELECT taxi_type,
       count(*)                                    AS registros,
       count(*) - count(passenger_count)           AS passenger_count_nulos,
       count(*) - count(ratecode_id)               AS ratecode_nulos,
       count(*) - count(payment_type)              AS payment_type_nulos,
       count(*) - count(pickup_ts)                 AS pickup_nulos,
       count(*) - count(dropoff_ts)                AS dropoff_nulos
FROM trips
GROUP BY taxi_type;
```

**Resultado**

| taxi_type | registros | passenger_count_nulos | ratecode_nulos | payment_type_nulos | pickup_nulos | dropoff_nulos |
|---|---|---|---|---|---|---|
| green | 1588707 | 122983 | 122983 | 122983 | 0 | 0 |
| yellow | 119595677 | 23419814 | 23419814 | 0 | 0 | 0 |


## q3_6c_anomalias_basicas
- **Pregunta:** 3.6 Cuantos registros violan reglas basicas de coherencia?
- **Objetivo:** contar anomalias evidentes (fechas, distancias, importes, pasajeros) por tipo
- **Fuente:** vista trips
- **Tiempo:** 1.66 s, 2 filas

```sql
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
```

**Resultado**

| taxi_type | registros | fuera_del_periodo_del_archivo | llegada_antes_de_salida | duracion_mayor_24h | distancia_cero | distancia_mayor_100mi | tarifa_negativa | total_no_positivo | pasajeros_cero | pasajeros_nulo | pago_fuera_de_catalogo |
|---|---|---|---|---|---|---|---|---|---|---|---|
| green | 1588707 | 510 | 1351 | 5 | 71224 | 516 | 4879 | 6846 | 19575 | 122983 | 0 |
| yellow | 119595677 | 780 | 3820 | 800 | 3131494 | 5706 | 3737008 | 1762021 | 752775 | 23419814 | 23419814 |


## q3_7_rango_fechas
- **Pregunta:** 3.7 Que rango de fechas contiene realmente cada archivo?
- **Objetivo:** comparar el periodo del nombre del archivo con las fechas reales de recogida
- **Fuente:** vista trips
- **Tiempo:** 0.34 s, 64 filas

```sql
SELECT taxi_type, src_year, src_month,
       min(pickup_ts) AS primera_recogida,
       max(pickup_ts) AS ultima_recogida,
       count(*)       AS registros
FROM trips
GROUP BY ALL
ORDER BY ALL;
```

**Resultado**

| taxi_type | src_year | src_month | primera_recogida | ultima_recogida | registros |
|---|---|---|---|---|---|
| green | 2024 | 1 | 2023-12-31 14:38:47 | 2024-01-31 23:57:29 | 56551 |
| green | 2024 | 2 | 2024-01-25 19:10:32 | 2024-02-29 23:56:40 | 53577 |
| green | 2024 | 3 | 2008-12-31 23:02:24 | 2024-04-01 00:01:45 | 57457 |
| green | 2024 | 4 | 2024-03-31 22:34:23 | 2024-04-30 23:59:33 | 56471 |
| green | 2024 | 5 | 2009-01-01 00:27:54 | 2024-06-01 00:00:56 | 61003 |
| green | 2024 | 6 | 2024-05-24 17:04:38 | 2024-06-30 23:57:10 | 54748 |
| green | 2024 | 7 | 2024-06-30 23:55:13 | 2024-08-01 23:43:58 | 51837 |
| green | 2024 | 8 | 2024-07-25 22:29:43 | 2024-09-01 20:26:14 | 51771 |
| green | 2024 | 9 | 2008-12-31 00:00:00 | 2024-10-01 23:42:50 | 54440 |
| green | 2024 | 10 | 2024-09-26 01:59:36 | 2024-11-01 23:06:08 | 56147 |
| green | 2024 | 11 | 2024-10-26 01:18:56 | 2024-12-01 22:15:57 | 52222 |
| green | 2024 | 12 | 2008-12-31 23:08:01 | 2025-01-01 22:21:15 | 53994 |
| green | 2025 | 1 | 2024-12-25 23:13:15 | 2025-02-05 18:46:24 | 48326 |
| green | 2025 | 2 | 2025-01-31 22:34:50 | 2025-03-01 23:29:24 | 46621 |
| green | 2025 | 3 | 2025-02-25 18:10:10 | 2025-04-01 23:41:29 | 51539 |
| green | 2025 | 4 | 2025-03-25 22:50:59 | 2025-05-01 22:59:12 | 52132 |
| green | 2025 | 5 | 2025-04-29 21:06:34 | 2025-06-01 06:57:21 | 55399 |
| green | 2025 | 6 | 2025-05-29 19:20:43 | 2025-07-01 20:35:08 | 49390 |
| green | 2025 | 7 | 2025-06-24 21:06:31 | 2025-08-01 14:11:22 | 48205 |
| green | 2025 | 8 | 2025-07-26 17:19:43 | 2025-09-01 20:46:57 | 46306 |
| green | 2025 | 9 | 2025-08-25 16:23:11 | 2025-10-01 20:08:10 | 48893 |
| green | 2025 | 10 | 2025-09-24 22:46:18 | 2025-11-01 21:49:41 | 49416 |
| green | 2025 | 11 | 2025-10-26 20:23:16 | 2025-12-01 20:29:00 | 46912 |
| green | 2025 | 12 | 2008-12-31 15:13:04 | 2026-01-01 21:09:39 | 48236 |
| green | 2026 | 1 | 2025-12-27 16:49:41 | 2026-02-01 21:08:36 | 40272 |

_Se muestran 25 de 64 filas._


## q3_7b_catalogos
- **Pregunta:** 3.7 Que valores toman los codigos de pago y tarifa?
- **Objetivo:** revisar los catalogos payment_type y ratecode_id frente al diccionario de la TLC
- **Fuente:** vista trips
- **Tiempo:** 1.00 s, 28 filas

```sql
SELECT 'payment_type' AS campo, CAST(payment_type AS VARCHAR) AS valor, taxi_type, count(*) AS registros FROM trips GROUP BY ALL
UNION ALL
SELECT 'ratecode_id', CAST(ratecode_id AS VARCHAR), taxi_type, count(*) FROM trips GROUP BY ALL
ORDER BY campo, taxi_type, registros DESC;
```

**Resultado**

| campo | valor | taxi_type | registros |
|---|---|---|---|
| payment_type | 1 | green | 1081279 |
| payment_type | 2 | green | 370766 |
| payment_type |  | green | 122983 |
| payment_type | 3 | green | 10072 |
| payment_type | 4 | green | 3555 |
| payment_type | 5 | green | 52 |
| payment_type | 1 | yellow | 80447167 |
| payment_type | 0 | yellow | 23419814 |
| payment_type | 2 | yellow | 12902464 |
| payment_type | 4 | yellow | 2128195 |
| payment_type | 3 | yellow | 698028 |
| payment_type | 5 | yellow | 9 |
| ratecode_id | 1 | green | 1378324 |
| ratecode_id |  | green | 122983 |
| ratecode_id | 5 | green | 80074 |
| ratecode_id | 2 | green | 4188 |
| ratecode_id | 4 | green | 1762 |
| ratecode_id | 3 | green | 956 |
| ratecode_id | 99 | green | 409 |
| ratecode_id | 6 | green | 11 |
| ratecode_id | 1 | yellow | 89046084 |
| ratecode_id |  | yellow | 23419814 |
| ratecode_id | 2 | yellow | 3399740 |
| ratecode_id | 99 | yellow | 2041064 |
| ratecode_id | 5 | yellow | 1032983 |

_Se muestran 25 de 28 filas._

