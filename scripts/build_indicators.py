#!/usr/bin/env python3
"""Materializa los indicadores del tablero (sql/05_indicadores.sql).

Cada consulta `ind_*` se guarda como tabla en data/processed/indicadores.duckdb,
una base pequena que Metabase abre en modo solo lectura. Tambien escribe
docs/resultados/indicadores.md con SQL, tiempo y resultado de cada indicador.

Uso:
    python scripts/build_indicators.py
"""

import sys
import time
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from db import RAIZ, conectar, leer_consultas  # noqa: E402
from run_analysis import a_markdown  # noqa: E402

BASE = "data/processed/indicadores.duckdb"
SALIDA = RAIZ / "docs" / "resultados" / "indicadores.md"


def main() -> int:
    con = conectar(BASE)
    consultas = leer_consultas("05_indicadores.sql")
    partes = ["# Indicadores materializados\n\n",
              f"Generado: {datetime.now():%Y-%m-%d %H:%M} con `python scripts/build_indicators.py`. "
              f"Tablas en `{BASE}`.\n"]
    fallidos = []
    for c in consultas.values():
        print(f"  {c.nombre} ...", end=" ", flush=True)
        t0 = time.perf_counter()
        try:
            con.execute(f"CREATE OR REPLACE TABLE {c.nombre} AS {c.sql}")
            df = con.execute(f"SELECT * FROM {c.nombre}").df()
            estado = f"{time.perf_counter() - t0:.2f} s, {len(df)} filas"
            cuerpo = a_markdown(df, 12)
        except Exception as error:
            estado, cuerpo = "ERROR", f"**ERROR:** `{error}`"
            fallidos.append(c.nombre)
        print(estado)
        partes.append(f"\n## {c.nombre}\n")
        for clave in ("pregunta", "objetivo", "visualizacion", "fuente"):
            if clave in c.meta:
                partes.append(f"- **{clave.capitalize()}:** {c.meta[clave]}\n")
        partes.append(f"- **Tiempo:** {estado}\n\n```sql\n{c.sql};\n```\n\n{cuerpo}\n")
    con.execute("CHECKPOINT")
    con.close()
    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    SALIDA.write_text("".join(partes), encoding="utf-8")
    print(f"\nTablas en {BASE}; reporte en {SALIDA}")
    if fallidos:
        print("Indicadores con error:", ", ".join(fallidos))
    return 1 if fallidos else 0


if __name__ == "__main__":
    sys.exit(main())
