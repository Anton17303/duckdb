"""Utilidades comunes: conexion a DuckDB, carga de consultas SQL documentadas.

Formato de los archivos de consultas (sql/*.sql):

    -- name: q3_2_registros
    -- pregunta: texto opcional
    -- objetivo: para que sirve la consulta
    -- fuente: archivos o tablas utilizados
    SELECT ... ;

Cada bloque `-- name:` es una consulta con nombre; las demas lineas `-- clave:`
son metadatos que se copian a la documentacion generada.
"""

import os
import re
from dataclasses import dataclass, field
from pathlib import Path

import duckdb

RAIZ = Path(__file__).resolve().parent.parent
DIR_SQL = RAIZ / "sql"
CLAVES = ("pregunta", "objetivo", "fuente", "visualizacion")


@dataclass
class Consulta:
    nombre: str
    sql: str
    meta: dict = field(default_factory=dict)


def leer_consultas(archivo) -> dict:
    """Devuelve {nombre: Consulta} a partir de un archivo con bloques `-- name:`."""
    ruta = Path(archivo)
    if not ruta.is_absolute():
        ruta = DIR_SQL / ruta
    consultas, actual, lineas = {}, None, []

    def cerrar():
        if actual is not None:
            actual.sql = "\n".join(lineas).strip().rstrip(";").strip()
            consultas[actual.nombre] = actual

    for linea in ruta.read_text(encoding="utf-8").splitlines():
        m = re.match(r"--\s*name:\s*(\S+)", linea)
        if m:
            cerrar()
            actual, lineas = Consulta(m.group(1), ""), []
            continue
        if actual is None:
            continue
        m = re.match(r"--\s*(\w+):\s*(.*)", linea)
        if m and m.group(1) in CLAVES:
            actual.meta[m.group(1)] = m.group(2).strip()
        elif not linea.strip().startswith("--"):
            lineas.append(linea)
    cerrar()
    return consultas


def ejecutar_script(con, archivo) -> None:
    """Ejecuta un script SQL simple (sentencias separadas por ';')."""
    ruta = Path(archivo)
    if not ruta.is_absolute():
        ruta = DIR_SQL / ruta
    texto = "\n".join(l for l in ruta.read_text(encoding="utf-8").splitlines()
                      if not l.strip().startswith("--"))
    for sentencia in texto.split(";"):
        if sentencia.strip():
            con.execute(sentencia)


def configurar_recursos(con) -> None:
    """Limita la memoria de DuckDB y permite desbordar a disco (evita que el SO mate el proceso).

    Variables de entorno opcionales:
        DUCKDB_MEMORY_LIMIT  (default 3GB)   p. ej. 2GB, 6GB
        DUCKDB_THREADS       (default: todos los nucleos)
    """
    tmp = RAIZ / "data" / "processed" / "duckdb_tmp"
    tmp.mkdir(parents=True, exist_ok=True)
    con.execute(f"SET memory_limit = '{os.environ.get('DUCKDB_MEMORY_LIMIT', '3GB')}'")
    con.execute(f"SET temp_directory = '{tmp}'")
    con.execute("SET preserve_insertion_order = false")   # menos memoria al materializar tablas
    if os.environ.get("DUCKDB_THREADS"):
        con.execute(f"SET threads = {int(os.environ['DUCKDB_THREADS'])}")


def conectar(base=":memory:", read_only=False, vistas=True):
    """Abre una conexion DuckDB con las vistas base (TEMP) ya creadas.

    `base` relativo se resuelve respecto a la raiz del proyecto. Se fija el
    directorio de trabajo en la raiz para que las rutas relativas de las vistas
    (data/raw/...) funcionen igual desde scripts, notebooks o Docker.
    """
    os.chdir(RAIZ)
    destino = base if base == ":memory:" else str((RAIZ / base).resolve())
    if destino != ":memory:":
        Path(destino).parent.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect(destino, read_only=read_only)
    configurar_recursos(con)
    if vistas:
        ejecutar_script(con, "00_vistas.sql")
        if (RAIZ / "data/raw/zones/taxi_zone_lookup.csv").exists():
            ejecutar_script(con, "00b_zonas.sql")
    return con


def correr(con, consultas: dict, nombre: str):
    """Ejecuta la consulta `nombre` de un dict de `leer_consultas` y devuelve un DataFrame.

    Pensada para notebooks: imprime pregunta/objetivo/fuente y devuelve el resultado.
    """
    c = consultas[nombre]
    for clave in ("pregunta", "objetivo", "fuente"):
        if clave in c.meta:
            print(f"{clave.capitalize()}: {c.meta[clave]}")
    return con.execute(c.sql).df()
