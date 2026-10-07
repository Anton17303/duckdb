-- ============================================================================
-- 00_vistas.sql  -  Vistas base del laboratorio (se crean como TEMP en cada
-- conexion; no se persisten rutas dentro de ningun archivo .duckdb).
--
-- IMPORTANTE: las rutas son relativas a la RAIZ del proyecto. scripts/db.py
-- cambia el directorio de trabajo a la raiz antes de ejecutar este archivo
-- (en Docker: /workspace). Desde la CLI de DuckDB ejecute desde la raiz.
--
-- Diseno para incorporar datos nuevos sin cambiar consultas:
--   * Los comodines  data/raw/<tipo>/*/*.parquet  recogen automaticamente
--     cualquier anio/mes que aparezca en disco.
--   * union_by_name = true tolera columnas que aparecen o cambian de tipo entre
--     archivos (p. ej. cbd_congestion_fee desde 2025, passenger_count BIGINT vs
--     DOUBLE, Airport_fee vs airport_fee).
--   * filename = true expone la ruta de origen; de ella se derivan src_year y
--     src_month, que permiten podar archivos al filtrar por periodo.
-- ============================================================================

CREATE OR REPLACE TEMP VIEW yellow_raw AS
SELECT * FROM read_parquet('data/raw/yellow/*/*.parquet', union_by_name = true, filename = true);

CREATE OR REPLACE TEMP VIEW green_raw AS
SELECT * FROM read_parquet('data/raw/green/*/*.parquet', union_by_name = true, filename = true);

-- Vista unificada y normalizada: mismos nombres y tipos para ambos taxis.
-- Solo se incluyen columnas comunes y estables entre anios (las tarifas que
-- aparecen/desaparecen -Airport_fee, cbd_congestion_fee, ehail_fee- se omiten
-- aqui; total_amount ya las incluye).
CREATE OR REPLACE TEMP VIEW trips AS
SELECT
    'yellow'                                   AS taxi_type,
    CAST(VendorID AS INTEGER)                  AS vendor_id,
    CAST(tpep_pickup_datetime  AS TIMESTAMP)   AS pickup_ts,
    CAST(tpep_dropoff_datetime AS TIMESTAMP)   AS dropoff_ts,
    CAST(passenger_count AS INTEGER)           AS passenger_count,
    CAST(trip_distance   AS DOUBLE)            AS trip_distance,
    CAST(RatecodeID      AS INTEGER)           AS ratecode_id,
    CAST(PULocationID    AS INTEGER)           AS pu_location_id,
    CAST(DOLocationID    AS INTEGER)           AS do_location_id,
    CAST(payment_type    AS INTEGER)           AS payment_type,
    CAST(fare_amount     AS DOUBLE)            AS fare_amount,
    CAST(tip_amount      AS DOUBLE)            AS tip_amount,
    CAST(tolls_amount    AS DOUBLE)            AS tolls_amount,
    CAST(total_amount    AS DOUBLE)            AS total_amount,
    CAST(regexp_extract(filename, '_(\d{4})-(\d{2})\.parquet$', 1) AS INTEGER) AS src_year,
    CAST(regexp_extract(filename, '_(\d{4})-(\d{2})\.parquet$', 2) AS INTEGER) AS src_month,
    filename
FROM yellow_raw
UNION ALL
SELECT
    'green',
    CAST(VendorID AS INTEGER),
    CAST(lpep_pickup_datetime  AS TIMESTAMP),
    CAST(lpep_dropoff_datetime AS TIMESTAMP),
    CAST(passenger_count AS INTEGER),
    CAST(trip_distance   AS DOUBLE),
    CAST(RatecodeID      AS INTEGER),
    CAST(PULocationID    AS INTEGER),
    CAST(DOLocationID    AS INTEGER),
    CAST(payment_type    AS INTEGER),
    CAST(fare_amount     AS DOUBLE),
    CAST(tip_amount      AS DOUBLE),
    CAST(tolls_amount    AS DOUBLE),
    CAST(total_amount    AS DOUBLE),
    CAST(regexp_extract(filename, '_(\d{4})-(\d{2})\.parquet$', 1) AS INTEGER),
    CAST(regexp_extract(filename, '_(\d{4})-(\d{2})\.parquet$', 2) AS INTEGER),
    filename
FROM green_raw;

-- Vista limpia: aplica las reglas documentadas en docs/transformaciones.md.
-- Los umbrales son decisiones del analista; sus efectos se cuantifican en
-- sql/02_eda.sql (consulta q4_reglas_limpieza).
CREATE OR REPLACE TEMP VIEW trips_clean AS
SELECT
    *,
    date_diff('second', pickup_ts, dropoff_ts) / 60.0 AS duration_min
FROM trips
WHERE year(pickup_ts)  = src_year                         -- R1: viaje dentro del periodo del archivo
  AND month(pickup_ts) = src_month
  AND dropoff_ts > pickup_ts                              -- R2: llegada posterior a la salida
  AND date_diff('second', pickup_ts, dropoff_ts) <= 6 * 3600   -- R3: duracion <= 6 h
  AND trip_distance > 0 AND trip_distance <= 100          -- R4: distancia en (0, 100] millas
  AND fare_amount > 0                                     -- R5: tarifa positiva
  AND total_amount > 0 AND total_amount <= 1000;          -- R6: total en (0, 1000] USD
