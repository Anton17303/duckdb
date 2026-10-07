-- Tabla de zonas de la TLC (se crea solo si data/raw/zones/taxi_zone_lookup.csv existe).
CREATE OR REPLACE TEMP VIEW zones AS
SELECT
    CAST(LocationID AS INTEGER) AS location_id,
    Borough                     AS borough,
    Zone                        AS zone,
    service_zone
FROM read_csv('data/raw/zones/taxi_zone_lookup.csv', header = true);
