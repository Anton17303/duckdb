# Ejercicio 5 — Incorporación de datos de 2024

## 5.1 – 5.3 Cambios en el sistema de descarga

La generalización por año ya se hizo en el Ejercicio 2 (`--years`,
`ANIOS_POR_DEFECTO`). Para incorporar 2024 solo se cambió la constante:

```python
ANIOS_POR_DEFECTO = (2024, 2026)   # antes: (2026,)
```

- **5.2 Conserva 2026**: el script solo escribe en `data/raw/<tipo>/<año>/`; nunca
  borra ni reescribe lo existente.
- **5.3 No re-descarga**: un archivo existente y no vacío se omite (`ya existe`).

## 5.4 – 5.5 Ejecución y verificación

```bash
docker compose exec lab python scripts/download_data.py            # baja 2024; 2026 aparece como "ya existe"
docker compose exec lab python scripts/download_data.py            # segunda corrida: todo "ya existe"
docker compose exec lab python scripts/verify_data.py --years 2024 2026
docker compose exec lab python scripts/run_analysis.py 03_incorporacion.sql
```

> **Evidencia pendiente:** pegar la salida de las dos corridas de descarga y de
> `verify_data.py` (ejecutadas en su máquina).

## 5.6 Consulta conjunta 2024 + 2026

`q5_2_consulta_conjunta_por_mes` (en `sql/03_incorporacion.sql`) pivotea viajes
por mes con una columna por año, usando una sola consulta sobre la vista `trips`.

## 5.7 ¿Hubo que modificar las consultas anteriores?

**No.** Ninguna consulta de `01_exploracion.sql` ni `02_eda.sql` menciona un año
concreto; leen vistas con comodines (`data/raw/yellow/*/*.parquet`). Se comprobó
ejecutando `02_eda.sql` y `03_incorporacion.sql` primero con solo el año 2026 en
disco y luego con 2024–2026: ambos sin errores y sin editar el SQL.
Los cambios de esquema entre años (columnas nuevas como `cbd_congestion_fee`,
`passenger_count` entero vs. decimal, `Airport_fee`/`airport_fee`) los absorbe
`union_by_name = true` y la normalización de tipos de la vista `trips`
(`q5_5_consistencia_esquema_por_anio` y `q3_4_deriva_de_esquema` lo evidencian).
Lo único que **sí** cambia con más años es el resultado (más filas) y el tiempo.

## 5.8 Consultas de validación

`q5_1` (archivos y filas por año), `q5_2` (consulta conjunta), `q5_3` (sin
periodos duplicados; se esperan 0 filas), `q5_4` (meses presentes) y `q5_5`
(consistencia de esquema) en [`sql/03_incorporacion.sql`](../sql/03_incorporacion.sql).

## 5.9 Características del diseño que permiten incorporar archivos nuevos

1. **Convención de directorios** `data/raw/<tipo>/<año>/` + comodines en las vistas.
2. **Año como parámetro**, no como constante dentro de la lógica.
3. **Descarga idempotente** (omite lo existente, escritura atómica `.part`).
4. **Capa de normalización única** (`trips`): el resto del análisis no conoce los
   nombres originales de columnas (`tpep_`/`lpep_`) ni sus variaciones.
5. **Separación datos/código**: los datos no están en Git; el código es el mismo.
6. **Verificación automática** (`verify_data.py`) que confirma completitud tras
   cada incorporación.
