# Ejercicio 2 — Sistema de descarga

## 2.1 Análisis del script proporcionado

`scripts/download_data.py` (versión del docente) ya implementa: descarga por
streaming a un archivo temporal `.part` con renombrado atómico, reintentos,
consulta `HEAD` para saber si un mes está publicado y omisión de archivos
existentes. Las partes que **debían modificarse** para el laboratorio completo:

| Parte original | Problema | Cambio |
|---|---|---|
| `ANIO = 2026` global usado en `construir_nombre/url/ruta_destino` | El año está fijo; no permite 2024 ni 2025 | El año pasa a ser parámetro de cada función |
| Bucle solo sobre meses de un año | No itera por varios años | `--years` (lista) y constante `ANIOS_POR_DEFECTO` |
| Solo `yellow` y `green` Parquet | Falta la tabla de zonas para analizar por barrio | `descargar_zonas()` descarga `taxi_zone_lookup.csv` a `data/raw/zones/` |
| Descarga se daba por buena si `escritos > 0` | Una conexión cortada podía dejar un archivo truncado "válido" | Se compara con `Content-Length` y se reintenta si no coincide |
| Sin forma de comprobar completitud | Requisito 2.7 | Nuevo `scripts/verify_data.py` |

## 2.2 – 2.4 Comportamiento resultante

- Obtiene automáticamente los 12 meses de cada tipo/año que la TLC haya
  publicado (los no publicados se consultan con `HEAD`, no se suponen).
- Guarda en `data/raw/<tipo>/<año>/<nombre-original>.parquet`.
- Idempotente: si el archivo existe y no está vacío, se omite (`ya existe`).
- `.gitignore` excluye `data/raw/**` y `data/processed/**`.

## 2.5 Ejecución y verificación

```bash
docker compose exec lab python scripts/download_data.py --years 2026
docker compose exec lab python scripts/verify_data.py --years 2026 \
    --salida docs/resultados/verificacion_descarga.md
```

> **Evidencia pendiente:** pegar la salida del resumen de ambos comandos
> (ejecutados en su máquina con acceso a la red de la TLC) y volver a ejecutar
> la descarga para mostrar que todos los archivos aparecen como `ya existe`.

## 2.6 Cambios realizados (resumen)

1. Año parametrizable (`--years`, `ANIOS_POR_DEFECTO`).
2. Descarga de `taxi_zone_lookup.csv` (`--no-zones` para omitirla).
3. Validación de tamaño contra `Content-Length` al descargar.
4. Aviso cuando no se obtiene ningún archivo (CloudFront devuelve 403 tanto para
   archivos inexistentes como para bloqueos de red).
5. Nuevo `verify_data.py`.

## 2.7 ¿Cómo se determina que el conjunto está completo?

Se definen los archivos **esperados** como (tipo × año × mes) para los meses que
ya ocurrieron y se contrastan tres fuentes:

1. **Presencia local** de cada archivo esperado.
2. **Servidor**: `HEAD` indica si el mes está publicado. Un mes publicado y ausente
   localmente es `FALTA`; un mes ausente y no publicado es `NO_PUBLICADO` (normal
   solo para los meses más recientes por el retraso de la TLC).
3. **Integridad**: el tamaño local debe igualar el `Content-Length` remoto y el
   pie del Parquet debe poder leerse con DuckDB (`parquet_file_metadata`), lo que
   además entrega el número de filas por archivo. En el Ejercicio 3 se verifica
   que `sum(num_rows)` de los metadatos coincide con `count(*)` real.

El conjunto está completo cuando `verify_data.py` termina con código 0 y todos los
meses esperados de años cerrados (2024, 2025) están en `OK`.
