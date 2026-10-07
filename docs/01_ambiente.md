# Ejercicio 1 — Preparación del ambiente

## 1.1 – 1.3 Fork, clonado y servicios

El procedimiento exacto está en la sección *Cómo levantar el ambiente* del
`README.md`. La verificación de los servicios (1.3) se hace con
`docker compose ps`, importando `duckdb` dentro del contenedor `lab` y
consultando `/api/health` de Metabase.

> **Evidencia pendiente:** pegar aquí la salida de `docker compose ps` y de los
> comandos de verificación ejecutados en su máquina.

## 1.4 Herramientas disponibles

| Herramienta | Dónde | Uso en el laboratorio |
|---|---|---|
| Python 3.11 | `lab` | scripts de descarga, verificación y benchmark |
| DuckDB 1.5.5 | `lab` (y driver en `metabase`) | motor analítico sobre Parquet |
| JupyterLab 4 | `lab` (puerto 8888) | notebooks de exploración y análisis |
| pandas / pyarrow | `lab` | manejo de resultados y lectura de Parquet |
| matplotlib | `lab` | visualizaciones en notebooks |
| requests | `lab` | descarga de archivos |
| Metabase 0.63 + driver DuckDB | `metabase` (puerto 3000) | tablero de indicadores (Ejercicio 7) |

## Propósito de cada directorio

| Ruta | Propósito |
|---|---|
| `data/raw/` | Datos originales descargados, **sin modificar**, organizados `data/raw/<tipo>/<año>/`. Ignorados por Git. |
| `data/processed/` | Resultados derivados reproducibles: base DuckDB materializada, tablas de indicadores, CSV de benchmark. Ignorados por Git. |
| `notebooks/` | Análisis interactivo y narrativa (exploración, EDA, benchmark, tablero). |
| `scripts/` | Código reutilizable y ejecutable: descarga, verificación, benchmark, construcción de indicadores. |
| `sql/` | Consultas SQL versionadas y documentadas (objetivo, fuente, pregunta). |
| `docs/` | Documentación, resultados generados y respuestas del informe. |
| `Dockerfile`, `docker-compose.yml`, `metabase.Dockerfile` | Definición del ambiente reproducible. |
| `README.md` | Punto de entrada para reproducir el proyecto. |

La separación `raw/` vs `processed/` garantiza que lo original nunca se
sobrescriba y que todo lo derivado pueda regenerarse con los scripts.

## 1.6 ¿Por qué importa un ambiente reproducible?

Un análisis solo es confiable si otra persona (o uno mismo meses después) puede
obtener los mismos resultados. Con Docker se fijan las versiones del sistema,
de Python y de las librerías (`requirements.txt` con versiones exactas), de modo
que "en mi computadora funciona" deja de ser un problema: DuckDB 1.5.5 se
comporta igual para todo el equipo, y la versión del driver de Metabase queda
alineada con la del motor. Además reduce el tiempo de incorporación de nuevas
personas (un comando levanta todo), evita contaminar el sistema anfitrión y
permite auditar qué entorno produjo cada resultado.
