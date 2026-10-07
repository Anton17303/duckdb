#!/usr/bin/env python3
"""Benchmark: consultar archivos Parquet directamente vs. tabla materializada en DuckDB.

Flujo:
  1. Construye (o reutiliza) la tabla `trips_tbl` en data/processed/taxi.duckdb a
     partir de la vista `trips` (todos los archivos descargados) y mide el tiempo
     de construccion y el tamano en disco frente a los Parquet.
  2. Para subconjuntos crecientes de datos (primeros k periodos mensuales) crea dos
     vistas con el mismo esquema y el mismo filtro (filename IN (...)):
        bench_pq  -> lectura directa de los archivos Parquet
        bench_tbl -> la tabla materializada
  3. Ejecuta cada consulta de sql/04_benchmark.sql sobre ambas, `--reps` veces,
     alternando estrategias; verifica que los resultados sean equivalentes.
  4. Escribe data/processed/benchmark_resultados.csv y docs/resultados/benchmark.md.

Uso:
    python scripts/benchmark.py                 # 5 repeticiones, reutiliza la tabla si existe
    python scripts/benchmark.py --rebuild       # reconstruye la tabla
    python scripts/benchmark.py --reps 3 --subsets 1 6 12

Notas de interpretacion:
  * La primera repeticion se reporta aparte (`primera_s`): incluye lecturas de disco
    aun no cacheadas por el sistema operativo. Las siguientes son "calientes".
  * Para una comparacion fria real, vacie la cache del SO entre corridas (en Linux:
    `sync; echo 3 | sudo tee /proc/sys/vm/drop_caches`, fuera de Docker).
"""

import argparse
import csv
import math
import re
import statistics
import sys
import time
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from db import RAIZ, conectar, leer_consultas  # noqa: E402

BASE = "data/processed/taxi.duckdb"
CSV_SALIDA = RAIZ / "data" / "processed" / "benchmark_resultados.csv"
MD_SALIDA = RAIZ / "docs" / "resultados" / "benchmark.md"
TAMANOS_PREDETERMINADOS = (1, 3, 6, 12, 24)


def mib(n: float) -> float:
    return n / 1048576


def tabla_existe(con) -> bool:
    return con.execute(
        "SELECT count(*) FROM duckdb_tables() WHERE table_name = 'trips_tbl'"
    ).fetchone()[0] == 1


def construir_tabla(con) -> dict:
    """Materializa trips en trips_tbl. Devuelve tiempos y tamanos."""
    print("Construyendo tabla trips_tbl ...", flush=True)
    con.execute("DROP TABLE IF EXISTS trips_tbl")
    t0 = time.perf_counter()
    con.execute("CREATE TABLE trips_tbl AS SELECT * FROM trips")
    con.execute("CHECKPOINT")
    seg = time.perf_counter() - t0
    filas = con.execute("SELECT count(*) FROM trips_tbl").fetchone()[0]
    print(f"  {filas:,} filas en {seg:.1f} s")
    return {"segundos_construccion": seg, "filas": filas}


def periodos(con) -> list:
    """[(periodo 'YYYY-MM', [archivos])] ordenado cronologicamente."""
    por_periodo = {}
    for (ruta,) in con.execute("SELECT file FROM glob('data/raw/*/*/*.parquet')").fetchall():
        m = re.search(r"_(\d{4}-\d{2})\.parquet$", ruta)
        if m:
            por_periodo.setdefault(m.group(1), []).append(ruta)
    return sorted(por_periodo.items())


def tamanos_subconjuntos(total: int, pedidos) -> list:
    ks = sorted({k for k in pedidos if 0 < k < total})
    return ks + [total]


def crear_vistas(con, archivos: list) -> None:
    lista = ", ".join("'" + a.replace("'", "''") + "'" for a in archivos)
    con.execute(f"CREATE OR REPLACE TEMP VIEW bench_pq  AS SELECT * FROM trips     WHERE filename IN ({lista})")
    con.execute(f"CREATE OR REPLACE TEMP VIEW bench_tbl AS SELECT * FROM trips_tbl WHERE filename IN ({lista})")


def iguales(a, b, tol=1e-6) -> bool:
    if len(a) != len(b):
        return False
    for fa, fb in zip(a, b):
        for x, y in zip(fa, fb):
            if isinstance(x, float) or isinstance(y, float):
                if x is None or y is None:
                    if x is not y:
                        return False
                elif not math.isclose(x, y, rel_tol=tol, abs_tol=1e-9):
                    return False
            elif x != y:
                return False
    return True


def medir(con, sql: str, reps: int):
    tiempos, resultado = [], None
    for i in range(reps):
        t0 = time.perf_counter()
        filas = con.execute(sql).fetchall()
        tiempos.append(time.perf_counter() - t0)
        if i == 0:
            resultado = filas
    return tiempos, resultado


def main() -> int:
    parser = argparse.ArgumentParser(description="Benchmark Parquet directo vs tabla DuckDB.")
    parser.add_argument("--reps", type=int, default=5, help="repeticiones por consulta (default 5)")
    parser.add_argument("--rebuild", action="store_true", help="reconstruir trips_tbl")
    parser.add_argument("--subsets", type=int, nargs="+", default=list(TAMANOS_PREDETERMINADOS),
                        help="numero de periodos mensuales por subconjunto (se agrega siempre 'todos')")
    args = parser.parse_args()

    con = conectar(BASE)
    info = {"segundos_construccion": None}
    if args.rebuild or not tabla_existe(con):
        info = construir_tabla(con)
    else:
        print("Reutilizando trips_tbl existente (use --rebuild para reconstruir).")

    pers = periodos(con)
    if not pers:
        print("No hay archivos Parquet en data/raw/. Ejecute scripts/download_data.py primero.")
        return 1

    tam_parquet = sum(Path(RAIZ / a).stat().st_size for _, fs in pers for a in fs)
    tam_db = (RAIZ / BASE).stat().st_size
    hilos = con.execute("SELECT current_setting('threads')").fetchone()[0]
    memoria = con.execute("SELECT current_setting('memory_limit')").fetchone()[0]
    consultas = leer_consultas("04_benchmark.sql")

    filas_csv, resumen = [], []
    for k in tamanos_subconjuntos(len(pers), args.subsets):
        sel = pers[:k]
        archivos = [a for _, fs in sel for a in fs]
        crear_vistas(con, archivos)
        n = con.execute("SELECT count(*) FROM bench_tbl").fetchone()[0]
        etiqueta = f"{k} periodo(s) [{sel[0][0]} .. {sel[-1][0]}]"
        print(f"\n== Subconjunto: {etiqueta} - {n:,} filas, {len(archivos)} archivos ==")
        for c in consultas.values():
            t_pq, r_pq = medir(con, c.sql.replace("{{T}}", "bench_pq"), args.reps)
            t_tb, r_tb = medir(con, c.sql.replace("{{T}}", "bench_tbl"), args.reps)
            ok = iguales(r_pq, r_tb)
            for estrategia, ts in (("parquet", t_pq), ("tabla", t_tb)):
                for i, t in enumerate(ts, 1):
                    filas_csv.append([estrategia, k, etiqueta, n, c.nombre, i, f"{t:.6f}"])
            resumen.append({
                "k": k, "etiqueta": etiqueta, "filas": n, "consulta": c.nombre,
                "pq_primera": t_pq[0], "pq_mediana": statistics.median(t_pq),
                "tb_primera": t_tb[0], "tb_mediana": statistics.median(t_tb), "ok": ok,
            })
            print(f"  {c.nombre:24} parquet {statistics.median(t_pq):7.3f}s | tabla {statistics.median(t_tb):7.3f}s | "
                  f"{'equivalentes' if ok else 'RESULTADOS DISTINTOS'}")

    CSV_SALIDA.parent.mkdir(parents=True, exist_ok=True)
    with CSV_SALIDA.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["estrategia", "periodos", "subconjunto", "filas", "consulta", "repeticion", "segundos"])
        w.writerows(filas_csv)

    # ---- Reporte Markdown -------------------------------------------------
    L = [f"# Benchmark Parquet directo vs tabla DuckDB\n",
         f"Generado: {datetime.now():%Y-%m-%d %H:%M} con `python scripts/benchmark.py --reps {args.reps}`.\n",
         "## Entorno y construcción de la tabla\n",
         f"- DuckDB hilos: **{hilos}**, límite de memoria: **{memoria}**",
         f"- Archivos Parquet: **{sum(len(f) for _, f in pers)}** ({mib(tam_parquet):,.0f} MiB en disco)",
         f"- Base DuckDB `{BASE}`: **{mib(tam_db):,.0f} MiB** (incluye `trips_tbl`)",
         (f"- Tiempo de construcción de `trips_tbl`: **{info['segundos_construccion']:.1f} s**"
          if info["segundos_construccion"] is not None else "- Tabla reutilizada (use `--rebuild` para medir la construcción)"),
         f"- Repeticiones por consulta: {args.reps}. Se reporta la **mediana**; `1ª` es la primera ejecución.\n",
         "Consultas: [`sql/04_benchmark.sql`](../../sql/04_benchmark.sql).\n"]
    for k in sorted({r["k"] for r in resumen}):
        grupo = [r for r in resumen if r["k"] == k]
        L.append(f"\n## {grupo[0]['etiqueta']} — {grupo[0]['filas']:,} filas\n")
        L.append("| consulta | Parquet 1ª (s) | Parquet mediana (s) | Tabla 1ª (s) | Tabla mediana (s) | Parquet / Tabla | equivalentes |")
        L.append("|---|---:|---:|---:|---:|---:|:---:|")
        for r in grupo:
            razon = r["pq_mediana"] / r["tb_mediana"] if r["tb_mediana"] else float("nan")
            L.append(f"| {r['consulta']} | {r['pq_primera']:.3f} | {r['pq_mediana']:.3f} | {r['tb_primera']:.3f} | "
                     f"{r['tb_mediana']:.3f} | {razon:.2f}x | {'sí' if r['ok'] else 'NO'} |")
    L.append("\n## Total de medianas por subconjunto\n")
    L.append("| periodos | filas | Parquet (s) | Tabla (s) | Parquet / Tabla |")
    L.append("|---:|---:|---:|---:|---:|")
    for k in sorted({r["k"] for r in resumen}):
        g = [r for r in resumen if r["k"] == k]
        sp, st = sum(r["pq_mediana"] for r in g), sum(r["tb_mediana"] for r in g)
        L.append(f"| {k} | {g[0]['filas']:,} | {sp:.2f} | {st:.2f} | {sp / st if st else float('nan'):.2f}x |")
    MD_SALIDA.parent.mkdir(parents=True, exist_ok=True)
    MD_SALIDA.write_text("\n".join(L) + "\n", encoding="utf-8")
    print(f"\nCSV: {CSV_SALIDA}\nReporte: {MD_SALIDA}")
    return 0 if all(r["ok"] for r in resumen) else 2


if __name__ == "__main__":
    sys.exit(main())
