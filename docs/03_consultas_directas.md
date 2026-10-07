# Ejercicio 3 — Consultas directas sobre archivos Parquet

Todas las consultas están en [`sql/01_exploracion.sql`](../sql/01_exploracion.sql)
con su pregunta, objetivo y fuente. Se ejecutan y documentan (SQL + tiempo +
resultado) con:

```bash
docker compose exec lab python scripts/run_analysis.py 01_exploracion.sql
# -> docs/resultados/01_exploracion.md
```

El notebook [`notebooks/01_exploracion.ipynb`](../notebooks/01_exploracion.ipynb)
ejecuta las mismas consultas de forma interactiva.

## Mapa de requisitos → consultas

| Requisito | Consulta(s) |
|---|---|
| 3.1 Cantidad de archivos | `q3_1_archivos_por_tipo_anio`, `q3_1b_total_archivos` |
| 3.2 Cantidad de registros | `q3_2_registros_por_tipo_anio`, `q3_2b_registros_metadatos`, `q3_2c_filas_por_archivo` |
| 3.3 Columnas | `q3_3_columnas_yellow`, `q3_3_columnas_green` |
| 3.4 Tipos de datos | las mismas `DESCRIBE` + `q3_4_deriva_de_esquema` |
| 3.5 Muestra | `q3_5_muestra_aleatoria`, `q3_5b_primeros_por_tipo` |
| 3.6 Calidad de datos | `q3_6_resumen_estadistico`, `q3_6b_nulos_por_tipo`, `q3_6c_anomalias_basicas`, `q3_7_rango_fechas`, `q3_7b_catalogos` |
| 3.7 Consultas sobre Parquet directo | todas (vistas `TEMP` sobre `read_parquet`, sin tablas) |

## 3.8 Documentación por consulta

El archivo generado `docs/resultados/01_exploracion.md` contiene, para cada
consulta: SQL, objetivo, archivos fuente, resultado y tiempo. Las **decisiones**
tomadas a partir de los resultados están en `docs/informe.md` (sección Ejercicio 3).

## Problemas de calidad que las consultas buscan (3.6)

Las consultas están diseñadas para detectar los problemas típicos documentados
por la TLC para este dataset. Su magnitud real en los archivos descargados debe
leerse en `docs/resultados/01_exploracion.md`:

- **Deriva de esquema entre archivos** (`q3_4`): columnas con distinto tipo físico
  (p. ej. `passenger_count` entero vs. decimal), nombres con distinta
  capitalización (`Airport_fee`/`airport_fee`) y columnas que aparecen solo en
  ciertos periodos (`cbd_congestion_fee`). `union_by_name = true` lo absorbe.
- **Fechas fuera del periodo del archivo** o llegada anterior a la salida.
- **Distancias en cero o extremas**, **tarifas/totales negativos o nulos**.
- **Pasajeros nulos o en cero** y **códigos de pago/tarifa fuera del catálogo**.

## 3.9 ¿Qué significa consultar directamente un Parquet y por qué ayuda con volúmenes grandes?

Consultar directamente significa que DuckDB lee los archivos `.parquet` en el
momento de ejecutar la consulta (`FROM 'ruta/*.parquet'` o `read_parquet(...)`),
**sin importarlos antes a una tabla**. Es útil con datos grandes porque:

1. **Formato columnar**: solo se leen las columnas que la consulta usa
   (*projection pushdown*); un `AVG(fare_amount)` no toca las demás ~18 columnas.
2. **Estadísticas por *row group***: el pie del archivo guarda mínimos/máximos y
   conteos; DuckDB descarta bloques que no cumplen un filtro (*filter pushdown*)
   y responde `count(*)` o `min/max` casi solo con metadatos.
3. **Procesamiento en streaming y paralelo** por *row group*: no hace falta que
   todo quepa en RAM, a diferencia de cargar todo en pandas.
4. **Sin costo ni mantenimiento de carga**: un archivo nuevo en `data/raw/` es
   visible en la siguiente consulta gracias al comodín (`*`), sin ETL ni servidor.
5. **Los datos originales no se duplican**: una sola copia, comprimida.
