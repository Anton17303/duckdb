# Lab 8 - DuckDB

Repositorio base del laboratorio 8 del curso **CC3084 - Data Science**
(Universidad del Valle de Guatemala, Ciclo 2, 2026).

Este es el repositorio **proporcionado por el docente**. Contiene la estructura
del proyecto, el ambiente de ejecucion basado en Docker y un script que descarga
los datos de **2026**. Todo lo demas debe ser construido por cada equipo.

## Trabajo con fork

El laboratorio se desarrolla y se entrega sobre un **fork** de este repositorio.
No se trabaja directamente sobre el repositorio del docente.

1. Realice un fork de este repositorio:
   <https://github.com/menene/duckdb>

2. Clone **su propio fork** (no el del docente):

   ```bash
   git clone https://github.com/<su-usuario>/duckdb.git
   cd duckdb
   ```

3. Opcional, para recibir correcciones publicadas por el docente:

   ```bash
   git remote add upstream https://github.com/menene/duckdb.git
   git fetch upstream
   ```

Realice commits frecuentes y descriptivos: el historial del repositorio es parte
de la evaluacion. **La entrega del laboratorio es la URL de su fork.**

## Estructura

```text
duckdb/
|
+-- data/
|   +-- raw/
|   +-- processed/
|
+-- notebooks/
|
+-- scripts/
|
+-- sql/
|
+-- docs/
|
+-- Dockerfile
+-- metabase.Dockerfile
+-- docker-compose.yml
+-- README.md
```

## Requisitos

- Docker, con Docker Compose
- Git

La primera construccion del ambiente descarga varios cientos de MB y puede
tardar algunos minutos.

Considere el espacio en disco: las imagenes de Docker ocupan unos 3 GB y los
datos de los tres anios del laboratorio superan 1.5 GB, a los que se suma la
base materializada del Ejercicio 6. Se recomienda tener al menos 10 GB libres.

## Datos

El repositorio incluye `scripts/download_data.py`, que descarga los archivos de
2026 publicados por la TLC (`--help` muestra las opciones disponibles). Los
archivos se guardan en `data/raw/<tipo>/<anio>/`.

La TLC publica cada mes con varias semanas de atraso, por lo que los ultimos
meses de 2026 todavia no existen. El script consulta al servidor que meses estan
publicados, de modo que vuelve a ejecutarse sin problema conforme aparezcan
nuevos archivos.

Los datos descargados **no deben incluirse en el repositorio Git**. El archivo
`.gitignore` ya esta configurado para evitarlo.

Fuente de datos: NYC TLC Trip Record Data
<https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page>

Dentro de los contenedores, la carpeta `data/` del proyecto esta montada en
`/workspace/data`. Esa es la ruta que deben usar las herramientas que corren
dentro del ambiente, no la ruta de su computadora.

> **Nota sobre DuckDB:** un archivo `.duckdb` admite un solo proceso con permiso
> de escritura a la vez. Si conecta una herramienta externa a su base de datos,
> use el modo de solo lectura (`read_only`) en esa conexion; de lo contrario los
> demas procesos no podran abrir el archivo.

## Material a entregar

Al finalizar, su fork debe contener:

- el codigo fuente modificado y los scripts de descarga;
- las consultas SQL desarrolladas;
- el notebook o notebooks utilizados;
- la documentacion de las consultas;
- los scripts utilizados para los benchmarks;
- el codigo de los indicadores y visualizaciones;
- el tablero o la evidencia del tablero desarrollado;
- este `README.md`, completado segun la siguiente seccion.

Los archivos de datos descargados **no** deben incluirse.

---

# Documentacion del equipo

Las siguientes secciones deben ser completadas por cada equipo. El README final
debe permitir que una persona que no participo en el desarrollo pueda levantar el
ambiente, descargar los datos, ejecutar el analisis, reproducir los benchmarks y
generar los resultados principales.

## Como levantar el ambiente

Requisitos: Docker con Docker Compose y Git.

```bash
# 1. Clonar el fork propio
git clone https://github.com/<su-usuario>/duckdb.git
cd duckdb

# 2. Construir y levantar los servicios (la primera vez tarda varios minutos)
docker compose up --build -d

# 3. Verificar que ambos servicios estan arriba
docker compose ps
```

Servicios proporcionados por el repositorio:

| Servicio   | Contenedor       | URL                    | Para que sirve                               |
|------------|------------------|------------------------|----------------------------------------------|
| `lab`      | `lab8-lab`       | http://127.0.0.1:8888  | JupyterLab con Python 3.11, DuckDB, pandas, pyarrow, matplotlib y requests |
| `metabase` | `lab8-metabase`  | http://127.0.0.1:3000  | Metabase con el driver de DuckDB (tablero del Ejercicio 7) |

Verificacion rapida:

```bash
docker compose exec lab python -c "import duckdb; print(duckdb.__version__)"   # 1.5.5
docker compose exec lab python -c "import duckdb; print(duckdb.sql('SELECT 42 AS ok').fetchall())"
curl -s http://127.0.0.1:3000/api/health                                        # {"status":"ok"}
```

Herramientas disponibles dentro del ambiente `lab`: Python 3.11, DuckDB 1.5.5,
JupyterLab, pandas, pyarrow, matplotlib, requests, `curl` (el codigo
se versiona desde la maquina anfitriona). La carpeta del proyecto se monta en
`/workspace` (`data/`, `notebooks/`, `scripts/`, `sql/` y `docs/`).

Para detener el ambiente: `docker compose down` (los datos en `data/` se conservan).


## Como descargar los datos

Todos los comandos se ejecutan dentro del contenedor `lab` (desde la raiz del proyecto):

```bash
docker compose exec lab python scripts/download_data.py      # taxis amarillos y verdes 2024, 2025 y 2026 + tabla de zonas
docker compose exec lab python scripts/verify_data.py        # comprueba que este completo
```

Opciones utiles:

```bash
python scripts/download_data.py --years 2026                 # solo un anio
python scripts/download_data.py --years 2024 2025 --taxi green
python scripts/download_data.py --no-zones                    # sin taxi_zone_lookup.csv
```

- Los archivos quedan en `data/raw/<yellow|green>/<anio>/*.parquet` y
  `data/raw/zones/taxi_zone_lookup.csv`. **No se versionan en Git.**
- El proceso es **idempotente**: un archivo existente no se vuelve a descargar, y
  puede ejecutarse de nuevo cuando la TLC publique meses nuevos.
- `verify_data.py` compara cada archivo esperado con el servidor (publicado, tamano)
  y lee su pie Parquet con DuckDB; termina con codigo 0 si todo esta completo.
- Para agregar un anio nuevo: pasarlo con `--years` o agregarlo a `ANIOS_POR_DEFECTO`
  en `scripts/download_data.py`. Las consultas no cambian (ver `docs/05_incorporacion_2024.md`).
- Historial de cambios al script: `docs/02_descarga.md`, `docs/05_incorporacion_2024.md`
  y `docs/08_datos_2025_y_analisis_completo.md`.

## Como ejecutar el analisis

Las consultas SQL estan en `sql/` (cada una con pregunta, objetivo y fuente):

| Archivo | Ejercicio | Contenido |
|---|---|---|
| `00_vistas.sql`, `00b_zonas.sql` | 3 | Vistas `TEMP` sobre los Parquet: `trips`, `trips_clean`, `zones` |
| `01_exploracion.sql` | 3 | Exploracion y calidad de datos |
| `02_eda.sql` | 4 | Analisis exploratorio (P1-P11) |
| `03_incorporacion.sql` | 5 y 8 | Validacion de incorporacion de anios |
| `04_benchmark.sql` | 6 | Consultas del benchmark |
| `05_indicadores.sql` | 7 y 8 | 10 indicadores del tablero |
| `06_evolucion.sql` | 8 | Evolucion 2024-2026 |

**Opcion A - notebooks** (JupyterLab en <http://127.0.0.1:8888>, carpeta `notebooks/`):
`01_exploracion` -> `02_eda` -> `03_incorporacion_y_evolucion` -> `04_benchmark` -> `05_indicadores_tablero`.

**Opcion B - linea de comandos** (genera la documentacion de cada consulta con su resultado):

```bash
docker compose exec lab python scripts/run_analysis.py                    # 01, 02, 03 y 06 -> docs/resultados/*.md
docker compose exec lab python scripts/run_analysis.py 02_eda.sql         # un solo archivo
```

Tambien se puede usar la CLI de DuckDB desde la raiz del proyecto: las rutas de las
vistas son relativas a la raiz (`data/raw/...`).

Las transformaciones aplicadas (reglas de limpieza R1-R6) estan en `docs/transformaciones.md`.

## Como reproducir los benchmarks

```bash
docker compose exec lab python scripts/benchmark.py --rebuild --reps 5
```

- Construye `trips_tbl` en `data/processed/taxi.duckdb`, ejecuta las 7 consultas de
  `sql/04_benchmark.sql` sobre Parquet directo y sobre la tabla, con subconjuntos
  crecientes de datos, y verifica que los resultados sean equivalentes.
- Salidas: `data/processed/benchmark_resultados.csv` y `docs/resultados/benchmark.md`.
- Sin `--rebuild` reutiliza la tabla existente. Otras opciones: `--reps N`, `--subsets 1 6 12`.
- Discusion y guia de interpretacion: `docs/06_benchmark.md`.

## Como generar los resultados principales

Flujo completo desde cero:

```bash
docker compose up --build -d
docker compose exec lab python scripts/download_data.py
docker compose exec lab python scripts/verify_data.py --salida docs/resultados/verificacion_descarga.md
docker compose exec lab python scripts/run_analysis.py
docker compose exec lab python scripts/benchmark.py --rebuild --reps 5
docker compose exec lab python scripts/build_indicators.py      # tablas ind_* en data/processed/indicadores.duckdb
docker compose exec lab python scripts/make_dashboard.py        # docs/tablero.png
```

**Tablero interactivo (Metabase)**: <http://127.0.0.1:3000>, conectar la base
`/workspace/data/processed/indicadores.duckdb` en modo solo lectura y crear una
tarjeta por indicador (pasos en `docs/07_indicadores.md`).

Resultados generados (se versionan una vez producidos con datos reales):

| Resultado | Ubicacion |
|---|---|
| Verificacion de la descarga | `docs/resultados/verificacion_descarga.md` |
| Consultas + resultados | `docs/resultados/01_exploracion.md`, `02_eda.md`, `03_incorporacion.md`, `06_evolucion.md` |
| Benchmark | `docs/resultados/benchmark.md`, `data/processed/benchmark_resultados.csv` |
| Indicadores | `docs/resultados/indicadores.md` |
| Tablero | `docs/tablero.png` (y captura de Metabase en `docs/tablero_metabase.png`) |
| Informe con respuestas, hallazgos y discusion | `docs/informe.md` |

> Detenga cualquier cuaderno que tenga abierta `indicadores.duckdb` en modo escritura
> antes de conectarla desde Metabase (un archivo `.duckdb` admite un solo escritor).

## Estructura final del proyecto

```text
data/raw/ , data/processed/     datos (ignorados por Git)
scripts/  download_data.py  verify_data.py  db.py  run_analysis.py  benchmark.py  build_indicators.py  make_dashboard.py
sql/      00_vistas.sql ... 06_evolucion.sql
notebooks/01_exploracion ... 05_indicadores_tablero
docs/     01_ambiente.md ... 08_*.md  transformaciones.md  informe.md  resultados/
```
