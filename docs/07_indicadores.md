# Ejercicio 7 — Indicadores y tablero

Consultas: [`sql/05_indicadores.sql`](../sql/05_indicadores.sql) (cada indicador es
una consulta nombrada `ind_*` con su pregunta, objetivo y visualización).

```bash
docker compose exec lab python scripts/build_indicators.py     # crea data/processed/indicadores.duckdb
docker compose exec lab python scripts/make_dashboard.py       # docs/tablero.png (evidencia estática)
```

## 7.1 – 7.2 Preguntas e indicadores (10)

| # | Pregunta de análisis | Indicador (tabla) | Visualización |
|---|---|---|---|
| 1 | ¿Cómo evoluciona el volumen de viajes de cada taxi? | `ind_01_viajes_mensuales` | Líneas |
| 2 | ¿Cuánto ingreso generan los viajes y cuánto deja cada uno? | `ind_02_ingreso_mensual` | Líneas / barras |
| 3 | ¿A qué horas se concentra la demanda y cambia en fin de semana? | `ind_03_demanda_por_hora` | Líneas |
| 4 | ¿Cómo cambia el viaje típico (tarifa, distancia, duración)? | `ind_04_viaje_tipico_mensual` | Líneas |
| 5 | ¿Cómo pagan los pasajeros y cambió la preferencia? | `ind_05_metodo_pago_anual` | Barras apiladas 100 % |
| 6 | ¿Cuánta propina dejan quienes pagan con tarjeta? | `ind_06_propina_mensual` | Líneas |
| 7 | ¿Qué tan largos son los viajes en cada taxi? | `ind_07_distribucion_distancia` | Barras agrupadas |
| 8 | ¿Dónde se recogen más pasajeros? | `ind_08_top_zonas_recogida` | Barras horizontales |
| 9 | ¿Cómo varía la velocidad (congestión) durante el día? | `ind_09_velocidad_por_hora` | Líneas |
| 10 | ¿Qué proporción de registros se descarta por calidad y cómo evoluciona? | `ind_10_calidad_mensual` | Líneas |

Se construyen **10 indicadores** (el mínimo era 6) y cada uno responde una de las
10 preguntas.

## 7.3 – 7.4 SQL y visualizaciones

El SQL de cada indicador está en `sql/05_indicadores.sql`; su resultado, tiempo y
muestra se generan en `docs/resultados/indicadores.md`. Los datos provienen de
DuckDB (`trips_clean` sobre los Parquet) y se materializan en tablas pequeñas
`ind_*` para que el tablero responda al instante.

## 7.5 Tablero en Metabase (herramienta proporcionada)

1. Levantar el ambiente: `docker compose up -d` y abrir <http://127.0.0.1:3000>
   (crear la cuenta de administrador la primera vez).
2. Ejecutar `python scripts/build_indicators.py` en el contenedor `lab`
   (y no dejar abierta ninguna conexión de escritura a esa base).
3. En Metabase: **Admin → Databases → Add database → DuckDB**.
   - Database file: `/workspace/data/processed/indicadores.duckdb`
     (la carpeta `data/` está montada en el contenedor de Metabase).
   - Activar el modo de **solo lectura** (opción *read only*, o `access_mode=read_only`
     en las opciones adicionales de conexión), como advierte el README.
4. Para cada indicador: **New → SQL query** → `SELECT * FROM ind_XX_...` → elegir la
   visualización de la tabla anterior → *Save*. (Para series por tipo, usar la
   columna `taxi_type` como serie.)
5. Crear el dashboard **"Taxis NYC (TLC)"**, agregar las 10 tarjetas y un filtro
   de fecha/tipo de taxi si se desea.
6. Tomar una captura del tablero y guardarla en `docs/tablero_metabase.png`.

Si no se dispone de Metabase, `docs/tablero.png` (generado con
`make_dashboard.py` a partir de las mismas tablas) sirve como evidencia estática.

> **Evidencia pendiente:** captura del tablero real en Metabase.

## 7.6 Justificación de los indicadores

Cubren las dimensiones pedidas en el Ejercicio 4: **temporal** (1, 2, 3, 4, 6),
**características del viaje** (4, 7, 9), **diferencias entre taxis** (todos están
desglosados por `taxi_type`, y 8 compara geografía), **pago** (5, 6) y
**calidad/atípicos** (10). Se eligieron métricas simples y comparables (conteos,
medias, porcentajes) para que el tablero sea legible; las que dependen de colas
(tarifa) se contrastan con percentiles en el EDA. El indicador 10 es deliberado:
una métrica de calidad evita interpretar cambios de calidad de captura como
cambios de comportamiento.

## 7.7 Documentación de consultas

Cada indicador está documentado en `sql/05_indicadores.sql` (pregunta, objetivo,
visualización, fuente) y en `docs/resultados/indicadores.md` (SQL + resultado).

## 7.8 Interpretación

La interpretación de cada indicador y los hallazgos principales dependen de los
datos reales y se redactan en `docs/informe.md` (sección *Ejercicio 7*) a partir
de `docs/tablero.png` / Metabase.
