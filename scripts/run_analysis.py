#!/usr/bin/env python3
"""Ejecuta los archivos de consultas y genera la documentacion con resultados.

Para cada consulta nombrada de sql/<archivo>.sql escribe, en
docs/resultados/<archivo>.md: la pregunta/objetivo, la fuente, la consulta SQL,
el tiempo de ejecucion y el resultado (primeras filas). Asi la documentacion de
consultas (requisito 3.8) se regenera con un comando.

Uso:
    python scripts/run_analysis.py                    # 01_exploracion y 02_eda
    python scripts/run_analysis.py 01_exploracion.sql
    python scripts/run_analysis.py 02_eda.sql --filas 40
"""

import argparse
import sys
import time
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from db import RAIZ, conectar, leer_consultas  # noqa: E402

POR_DEFECTO = ("01_exploracion.sql", "02_eda.sql")
DIR_SALIDA = RAIZ / "docs" / "resultados"


def a_markdown(df, max_filas: int) -> str:
    if df.empty:
        return "_(sin filas)_"
    corte = df.head(max_filas)
    fmt = lambda v: "" if v is None or (isinstance(v, float) and v != v) else str(v).replace("|", "\\|")
    cab = "| " + " | ".join(map(str, corte.columns)) + " |\n"
    sep = "|" + "|".join("---" for _ in corte.columns) + "|\n"
    filas = "".join("| " + " | ".join(fmt(v) for v in fila) + " |\n" for fila in corte.itertuples(index=False))
    extra = f"\n_Se muestran {max_filas} de {len(df)} filas._\n" if len(df) > max_filas else ""
    return cab + sep + filas + extra


def ejecutar_archivo(con, nombre_archivo: str, max_filas: int) -> Path:
    consultas = leer_consultas(nombre_archivo)
    partes = [
        f"# Resultados de `sql/{nombre_archivo}`\n",
        f"Generado: {datetime.now():%Y-%m-%d %H:%M} con `python scripts/run_analysis.py {nombre_archivo}`.  \n"
        "Cada bloque documenta: pregunta, objetivo, fuente, consulta SQL, tiempo y resultado. "
        "La **decisión/interpretación** de cada resultado se redacta en `docs/informe.md`.\n",
    ]
    for c in consultas.values():
        print(f"  {c.nombre} ...", end=" ", flush=True)
        t0 = time.perf_counter()
        try:
            df = con.execute(c.sql).df()
            seg = time.perf_counter() - t0
            cuerpo, estado = a_markdown(df, max_filas), f"{seg:.2f} s, {len(df)} filas"
        except Exception as error:  # se documenta el fallo en vez de abortar todo
            seg = time.perf_counter() - t0
            cuerpo, estado = f"**ERROR:** `{error}`", "ERROR"
        print(estado)
        partes.append(f"\n## {c.nombre}\n")
        for clave in ("pregunta", "objetivo", "fuente", "visualizacion"):
            if clave in c.meta:
                partes.append(f"- **{clave.capitalize()}:** {c.meta[clave]}\n")
        partes.append(f"- **Tiempo:** {estado}\n\n```sql\n{c.sql};\n```\n\n**Resultado**\n\n{cuerpo}\n")
    DIR_SALIDA.mkdir(parents=True, exist_ok=True)
    salida = DIR_SALIDA / (Path(nombre_archivo).stem + ".md")
    salida.write_text("".join(partes), encoding="utf-8")
    return salida


def main() -> int:
    parser = argparse.ArgumentParser(description="Ejecuta consultas SQL y documenta resultados.")
    parser.add_argument("archivos", nargs="*", default=list(POR_DEFECTO))
    parser.add_argument("--filas", type=int, default=25, help="filas maximas por resultado")
    args = parser.parse_args()

    con = conectar()
    for archivo in args.archivos:
        print(f"\n{archivo}")
        print("  ->", ejecutar_archivo(con, archivo, args.filas))
    return 0


if __name__ == "__main__":
    sys.exit(main())
