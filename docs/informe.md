# Informe — Laboratorio 8: DuckDB (CC3084)

Este informe reúne las respuestas conceptuales y los espacios para los resultados
numéricos. Las secciones marcadas **[COMPLETAR]** dependen de los datos reales de la
TLC: se redactan después de ejecutar el flujo completo (ver `README.md`) usando los
reportes de `docs/resultados/` y el tablero. Todo lo demás está respondido a partir
del diseño del sistema.

---

## Ejercicio 1 — Ambiente
Procedimiento: `README.md` (*Cómo levantar el ambiente*). Herramientas, propósito de
directorios y por qué un ambiente reproducible importa: [`01_ambiente.md`](01_ambiente.md).

**[COMPLETAR]** salida de `docker compose ps` y de la verificación de servicios.

## Ejercicio 2 — Descarga
Análisis y cambios al script: [`02_descarga.md`](02_descarga.md).
Cómo se determinó que la descarga está completa (2.7): `verify_data.py` contrasta
archivos esperados vs. locales vs. publicados, tamaño local = `Content-Length`, y
lectura del pie Parquet; luego `q3_2b_registros_metadatos` confirma que
`sum(num_rows)` de los metadatos coincide con `count(*)`.

**[COMPLETAR]** resumen de la primera y segunda corrida de `download_data.py` y salida de `verify_data.py`.

## Ejercicio 3 — Consultas directas
Consultas y mapa de requisitos: [`03_consultas_directas.md`](03_consultas_directas.md).
Explicación de consultar Parquet directamente (3.9): ver ese documento.

**[COMPLETAR]** por cada consulta relevante de `docs/resultados/01_exploracion.md`:
resultado obtenido y **decisión tomada** (p. ej. "se descartan los viajes fuera del
periodo del archivo → regla R1"; "se conservan los pasajeros nulos y se reportan").
Problemas de calidad encontrados (3.6): enumerar con sus cifras.

## Ejercicio 4 — EDA
Preguntas, justificación y consultas: [`04_eda.md`](04_eda.md); reglas de limpieza:
[`transformaciones.md`](transformaciones.md).

**[COMPLETAR] Hallazgos (mínimo 3)**, cada uno con la consulta que lo respalda:

| # | Hallazgo (con cifras) | Consulta | Implicación |
|---|---|---|---|
| 1 | | | |
| 2 | | | |
| 3 | | | |

## Ejercicio 5 — Incorporación de 2024
[`05_incorporacion_2024.md`](05_incorporacion_2024.md). Respuesta a 5.7: **no** hubo que
modificar las consultas (no mencionan años; comodines + `union_by_name`). Respuesta a
5.9: convención de directorios, año como parámetro, descarga idempotente, capa de
normalización `trips`, separación datos/código y verificación automática.

## Ejercicio 6 — Benchmark
Diseño y guía: [`06_benchmark.md`](06_benchmark.md). Resultados: `docs/resultados/benchmark.md`.

**[COMPLETAR]**
- Tabla de resultados (copiar la de `benchmark.md`) y el entorno (hilos, memoria).
- 6.9: explicar las diferencias observadas **con sus números** (qué consultas ganan con la
  tabla y por cuánto, cómo escala con el volumen, tiempo y espacio de construir la tabla).
- Confirmar que la columna *equivalentes* es "sí" en todas las filas.

**6.10 (respuesta de diseño):** consultar Parquet directamente conviene para
exploración ad hoc, datos que llegan continuamente, poco espacio/tiempo de carga y
consultas con filtros por periodo o pocas columnas; materializar conviene cuando
las consultas se repiten (tableros, indicadores), se necesitan tiempos predecibles,
se reutilizan transformaciones o se consulta desde otra herramienta (Metabase).

## Ejercicio 7 — Indicadores
Diseño, justificación (7.6) y guía de Metabase: [`07_indicadores.md`](07_indicadores.md).

**[COMPLETAR]** captura del tablero y, por cada indicador, una interpretación breve
(7.8) con las cifras observadas; principales hallazgos.

## Ejercicio 8 — Datos de 2025 y análisis completo
[`08_datos_2025_y_analisis_completo.md`](08_datos_2025_y_analisis_completo.md).

**[COMPLETAR] Tres cambios o patrones entre 2024, 2025 y 2026 (8.6)**, usando solo
meses comunes (consultas `q8_*`):

| # | Cambio o patrón (con cifras) | Consulta | Posible explicación (distinguir dato de hipótesis) |
|---|---|---|---|
| 1 | | | |
| 2 | | | |
| 3 | | | |

---

## Ejercicio 9 — Discusión

> Estas respuestas parten del diseño y de lo que se sabe de DuckDB/Parquet. **Ajústelas
> con lo que su equipo observó realmente** (tiempos, tamaños, problemas) antes de
> entregar; donde dice *[cifra]* inserte su medición.

**9.1 ¿Qué características de DuckDB resultaron más útiles?**
Consultar archivos Parquet directamente con comodines (`read_parquet('…/*.parquet')`)
sin cargar nada; `union_by_name` para tolerar cambios de esquema entre años; SQL
analítico completo (ventanas, `PIVOT`, `FILTER`, `quantile_cont`, `USING SAMPLE`);
`DESCRIBE`/`SUMMARIZE` y `parquet_file_metadata`/`parquet_schema` para auditar
archivos; ejecución columnar paralela sin servidor ni configuración; y el formato de
base propio para materializar tablas que Metabase puede leer.

**9.2 Ventajas y limitaciones al consultar Parquet directamente**
*Ventajas:* cero carga, los datos nuevos están disponibles de inmediato, se leen solo
las columnas y archivos necesarios (poda por columnas, estadísticas y `filename`), una
sola copia de los datos. *Limitaciones:* cada consulta vuelve a abrir y decodificar
los archivos; no hay índices ni estadísticas globales; el esquema puede cambiar entre
archivos (deriva de tipos y nombres, p. ej. `Airport_fee`/`airport_fee`), y la
validación y limpieza hay que repetirlas en cada consulta (se resolvió con vistas);
el rendimiento depende del disco; abrir miles de archivos añade latencia de metadatos.

**9.3 Ventajas y limitaciones de las tablas materializadas**
*Ventajas:* tipos fijos y normalizados, almacenamiento columnar propio con
estadísticas por bloque, consultas repetidas más rápidas y predecibles, se puede
guardar el resultado de la limpieza. *Limitaciones:* duplican el espacio (*[cifra]*),
cuestan tiempo de construcción (*[cifra]*), quedan desactualizadas cuando llegan
archivos nuevos y hay que reconstruirlas, y un archivo `.duckdb` admite un solo
escritor (bloquea la conexión desde Metabase si no se abre en solo lectura).

**9.4 Ventajas frente a cargar todo con Pandas**
Tres años de dos tipos de taxi son del orden de cientos de millones de filas; pandas
necesita todo en RAM (varias veces el tamaño del archivo) y procesa de forma
mayormente secuencial. DuckDB lee solo las columnas necesarias, procesa por bloques en
paralelo y puede derramar a disco, por lo que funciona con memoria acotada. Además el
SQL es declarativo y versionable. Pandas sigue siendo útil para el resultado final
(ya agregado y pequeño) y para graficar.

**9.5 Características que permiten incorporar datos con cambios mínimos**
Convención `data/raw/<tipo>/<año>/`; descarga parametrizada por año e idempotente;
vistas con comodines y normalización de esquema; consultas sin años fijos;
indicadores que se regeneran con un comando; `verify_data.py` para validar cada
incorporación.

**9.6 ¿Qué automatizar en producción?**
La descarga programada (detectar meses nuevos publicados), la verificación de
integridad con alerta, las pruebas de calidad con umbrales (p. ej. % descartado,
deriva de esquema), la reconstrucción *incremental* de tablas e indicadores (solo
archivos nuevos), el refresco del tablero, el almacenamiento en un almacén de objetos
con particionado y el registro de versiones/linaje de cada corrida.

**9.7 Decisiones de diseño para la reproducibilidad**
Docker con versiones exactas (y DuckDB alineado con el driver de Metabase); datos
fuera de Git y `raw/` inmutable; scripts idempotentes con escritura atómica; SQL
versionado y documentado (pregunta/objetivo/fuente); vistas `TEMP` con rutas
relativas a la raíz (sin rutas absolutas dentro de archivos `.duckdb`); reglas de
limpieza explícitas; resultados generados por scripts; historial de Git por ejercicio.

**9.8 ¿Qué se aprende con datos grandes que no se vería con datos pequeños?**
Que no se puede asumir que todo cabe en memoria ni releer sin costo; que a esta escala
*siempre* hay registros anómalos y hay que cuantificarlos (no basta mirar una muestra);
que los esquemas derivan entre archivos; que una descarga puede quedar truncada y hay
que verificarla; que los años recientes están incompletos y comparar sin ajustar sesga;
y que la estrategia de almacenamiento (Parquet vs tabla) cambia el tiempo de respuesta
de forma medible. **[COMPLETAR]** con un ejemplo concreto de su ejecución.
