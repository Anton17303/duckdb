# Ejercicio 6 — Parquet directo vs tabla DuckDB

## Diseño del benchmark (6.1 – 6.8)

| Elemento | Decisión |
|---|---|
| Tabla materializada (6.2) | `trips_tbl` = `SELECT * FROM trips` (todos los años descargados, esquema normalizado) en `data/processed/taxi.duckdb`. Se mide el tiempo de construcción y el tamaño en disco. |
| Consultas (6.3) | 7 consultas representativas (`sql/04_benchmark.sql`): conteo, agregado simple, agrupación por hora, serie mensual por pago, alta cardinalidad (pares origen-destino), filtro selectivo y percentiles exactos. Cubren los patrones del EDA y de los indicadores. |
| Equivalencia (6.4) | Ambas estrategias ejecutan **el mismo texto SQL**; solo cambia la fuente: `bench_pq` (vista sobre los Parquet, filtrada con `filename IN (...)`, lo que hace que DuckDB solo abra esos archivos) y `bench_tbl` (misma condición sobre `trips_tbl`). El script compara los resultados de ambas y marca `NO` si difieren. |
| Tiempos (6.5) | `time.perf_counter()` por ejecución, 5 repeticiones: se reporta la primera (más "fría") y la mediana. Estrategias alternadas por consulta. |
| Distintas cantidades de datos (6.6) | Subconjuntos crecientes: los primeros 1, 3, 6, 12, 24 periodos mensuales y *todos*. |
| Tabla de resultados (6.7) | `docs/resultados/benchmark.md` y `data/processed/benchmark_resultados.csv`. |
| Documentación de consultas (6.8) | `sql/04_benchmark.sql` (cada consulta con su objetivo). |

## Cómo ejecutarlo

```bash
docker compose exec lab python scripts/benchmark.py --rebuild --reps 5
```

> La corrida debe hacerse con los datos reales de 2024–2026. Tenga presente que
> el ambiente Docker comparte CPU/RAM con su máquina: cierre otras cargas pesadas
> y anote los hilos y memoria que imprime el reporte.

## 6.9 Análisis de resultados (guía para interpretar su tabla)

Complete esta sección **con sus números reales**. Las preguntas que la tabla
debe permitir responder y las explicaciones esperadas son:

1. **¿La tabla es más rápida que el Parquet?** Normalmente sí en consultas que
   escanean muchas filas, porque DuckDB guarda su propio formato columnar
   sin la decodificación de Parquet (descompresión, conversión de tipos y de
   timestamps) y mantiene estadísticas por bloque. El factor `Parquet/Tabla`
   suele crecer con el volumen.
2. **¿Dónde casi no hay diferencia o gana el Parquet?** En `b1_conteo` y filtros
   sobre columnas con estadísticas útiles, Parquet puede responder con
   metadatos del pie del archivo; y en subconjuntos pequeños el costo fijo de
   abrir archivos domina sobre el escaneo.
3. **Primera vs. mediana**: la primera ejecución del Parquet incluye lectura de
   disco no cacheada y lectura de metadatos; si la tabla cabe en memoria las
   siguientes corridas se benefician del *buffer manager* de DuckDB.
4. **Costo de la tabla**: tiempo de construcción y espacio adicional en disco
   (`tamaño .duckdb` vs. Parquet). Una tabla duplica los datos y hay que
   reconstruirla o actualizarla cuando llegan archivos nuevos.
5. **Consultas de alta cardinalidad o percentiles** (`b5`, `b7`) dependen más del
   algoritmo de agregación y la memoria que del formato de origen: espere
   diferencias menores.

> Antes de escribir conclusiones, revise que la columna *equivalentes* diga "sí"
> en todas las filas; si no, la comparación no es válida.

## 6.10 ¿Cuándo consultar Parquet directamente y cuándo materializar?

**Consultar Parquet directamente conviene cuando:**
- se hace exploración puntual o análisis ad hoc, y se consulta cada dato pocas veces;
- los datos crecen con archivos nuevos y se quiere verlos de inmediato, sin ETL;
- el espacio en disco o el tiempo de carga son limitados;
- las consultas filtran por periodo (se podan archivos) o usan pocas columnas;
- los Parquet son la fuente de verdad compartida con otras herramientas (Spark, pandas).

**Materializar una tabla DuckDB conviene cuando:**
- las mismas consultas se repiten muchas veces (tableros, indicadores, benchmarks);
- se necesitan tiempos de respuesta bajos y predecibles;
- se quiere aplicar transformaciones/limpieza una vez y reutilizar el resultado
  (por ejemplo `trips_clean` o las tablas de indicadores);
- se requieren índices/ordenamiento, `JOIN`s repetidos o consultas concurrentes
  de solo lectura desde otra herramienta (Metabase);
- la fuente está en almacenamiento remoto/lento y conviene traerla una vez.

**Enfoque híbrido usado en este proyecto:** análisis exploratorio sobre Parquet
(flexible), y tablas pequeñas pre-agregadas (`ind_*`) para el tablero.
