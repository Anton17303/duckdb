# Transformaciones y reglas de limpieza

Los archivos de `data/raw/` **nunca se modifican**. Toda transformación se define
en SQL, versionada, y se aplica en tiempo de consulta mediante vistas `TEMP`
(`sql/00_vistas.sql`):

| Vista | Qué hace |
|---|---|
| `yellow_raw`, `green_raw` | `read_parquet` con comodín por tipo (`data/raw/<tipo>/*/*.parquet`), `union_by_name = true` y `filename = true`. |
| `trips` | Une amarillos y verdes con nombres/tipos normalizados (`pickup_ts`, `dropoff_ts`, `pu_location_id`, …). Agrega `taxi_type`, `src_year`, `src_month` (extraídos del nombre del archivo). Solo incluye columnas comunes y estables entre años. |
| `trips_clean` | `trips` + `duration_min`, filtrando las reglas R1–R6. |
| `zones` | `taxi_zone_lookup.csv` (si existe). |

## Reglas de `trips_clean`

| Regla | Condición que se conserva | Justificación |
|---|---|---|
| R1 | `year/month(pickup_ts)` = año/mes del archivo | La TLC advierte que los archivos contienen registros con fechas fuera de su periodo; contaminan series temporales. |
| R2 | `dropoff_ts > pickup_ts` | Un viaje no puede terminar antes de empezar. |
| R3 | duración ≤ 6 h | Duraciones mayores suelen ser taxímetros olvidados abiertos. |
| R4 | `0 < trip_distance ≤ 100` millas | Distancia cero no es un viaje medible; > 100 mi excede cualquier trayecto razonable de NYC. |
| R5 | `fare_amount > 0` | Tarifas negativas/cero corresponden a ajustes, disputas o errores. |
| R6 | `0 < total_amount ≤ 1000` | Importes extremos son errores de captura. |

> Los umbrales (6 h, 100 mi, 1000 USD) son **decisiones del analista**, no verdades
> de la TLC. Su efecto está cuantificado en `q4_p9_reglas_limpieza`
> (`docs/resultados/02_eda.md`); revíselos tras ver la magnitud real en sus datos.

## Qué no se limpia

- `passenger_count` nulo o 0 se **conserva** (se reporta en `q4_p4b_pasajeros`):
  eliminarlo sesgaría el conteo de viajes y el campo no interviene en los importes.
- `payment_type` fuera del catálogo se conserva y se etiqueta como `otro`.
- Las comparaciones de calidad (Ejercicio 3) usan `trips` (sin depurar); el EDA,
  el benchmark de consultas analíticas y los indicadores usan `trips_clean`, salvo
  indicación explícita.
