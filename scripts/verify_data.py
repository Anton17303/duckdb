#!/usr/bin/env python3
"""Verifica que el conjunto de datos descargado este completo y sea legible.

Para cada combinacion (tipo, anio, mes) comprueba:
  1. que el archivo exista localmente;
  2. que el servidor de la TLC lo tenga publicado (HEAD) y que el tamano local
     coincida con el Content-Length remoto (detecta descargas truncadas);
  3. que sea un Parquet valido: se lee el pie del archivo con DuckDB
     (parquet_file_metadata) y se obtiene el numero de filas sin escanear datos.

Estados posibles:
    OK              archivo presente, legible y con el tamano remoto
    FALTA           publicado en la TLC pero no existe localmente
    NO_PUBLICADO    ni local ni publicado (normal solo para meses futuros)
    TAMANO_DISTINTO el tamano local difiere del remoto (re-descargar)
    ILEGIBLE        existe pero DuckDB no puede leerlo
    SOLO_LOCAL      existe localmente y no se pudo consultar al servidor
    FALTA?          no existe localmente y no se pudo consultar al servidor
                    (sin red o --offline): no se puede descartar que falte

Uso:
    python scripts/verify_data.py                      # anios 2024-2026
    python scripts/verify_data.py --years 2026
    python scripts/verify_data.py --offline            # sin consultar al servidor
    python scripts/verify_data.py --salida docs/resultados/verificacion_descarga.md

Codigo de salida: 0 si todo OK (los meses futuros no cuentan como error), 1 si
hay FALTA, FALTA?, TAMANO_DISTINTO o ILEGIBLE.
"""

import argparse
import sys
from datetime import date
from pathlib import Path

import duckdb
import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
from download_data import (  # noqa: E402
    RUTA_ZONAS, TIEMPO_ESPERA, TIPOS_TAXI, construir_url, ruta_destino,
)

ANIOS_VERIFICACION = (2024, 2025, 2026)


def tamano_remoto(url: str):
    """Devuelve (publicado, bytes) o (None, None) si no se pudo consultar."""
    try:
        r = requests.head(url, timeout=TIEMPO_ESPERA, allow_redirects=True)
    except requests.RequestException:
        return None, None
    if not r.ok:
        return False, None
    return True, int(r.headers.get("Content-Length", 0)) or None


def filas_parquet(ruta: Path):
    """Numero de filas segun el pie del Parquet, o None si es ilegible."""
    try:
        fila = duckdb.execute(
            "SELECT sum(num_rows) FROM parquet_file_metadata(?)", [str(ruta)]
        ).fetchone()
        return int(fila[0])
    except Exception:
        return None


def verificar(tipo: str, anio: int, mes: int, offline: bool) -> dict:
    ruta = ruta_destino(tipo, anio, mes)
    existe = ruta.exists() and ruta.stat().st_size > 0
    tam_local = ruta.stat().st_size if existe else None

    publicado, tam_remoto = (None, None) if offline else tamano_remoto(construir_url(tipo, anio, mes))

    filas = filas_parquet(ruta) if existe else None

    if existe:
        if filas is None:
            estado = "ILEGIBLE"
        elif publicado and tam_remoto and tam_local != tam_remoto:
            estado = "TAMANO_DISTINTO"
        elif publicado is None:
            estado = "SOLO_LOCAL"
        else:
            estado = "OK"
    else:
        estado = "NO_PUBLICADO" if publicado is False else ("FALTA" if publicado else "FALTA?")

    return {
        "tipo": tipo, "periodo": f"{anio}-{mes:02d}", "estado": estado,
        "bytes_local": tam_local, "bytes_remoto": tam_remoto, "filas": filas,
    }


def tabla_markdown(filas: list) -> str:
    cab = "| tipo | periodo | estado | bytes local | bytes remoto | filas |\n|---|---|---|---:|---:|---:|\n"
    cuerpo = "\n".join(
        f"| {f['tipo']} | {f['periodo']} | {f['estado']} | "
        f"{f['bytes_local'] or ''} | {f['bytes_remoto'] or ''} | {f['filas'] if f['filas'] is not None else ''} |"
        for f in filas
    )
    return cab + cuerpo + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Verifica la integridad de la descarga.")
    parser.add_argument("--years", type=int, nargs="+", default=list(ANIOS_VERIFICACION))
    parser.add_argument("--taxi", choices=(*TIPOS_TAXI, "all"), default="all")
    parser.add_argument("--offline", action="store_true", help="no consultar al servidor")
    parser.add_argument("--salida", type=Path, help="escribir el reporte en Markdown")
    args = parser.parse_args()

    tipos = TIPOS_TAXI if args.taxi == "all" else (args.taxi,)
    hoy = date.today()
    resultados = []
    for tipo in tipos:
        for anio in sorted(set(args.years)):
            for mes in range(1, 13):
                if date(anio, mes, 1) > hoy:      # mes que aun no ocurre
                    continue
                resultados.append(verificar(tipo, anio, mes, args.offline))

    print(f"{'tipo':7} {'periodo':8} {'estado':16} {'filas':>12}")
    for r in resultados:
        print(f"{r['tipo']:7} {r['periodo']:8} {r['estado']:16} {r['filas'] if r['filas'] is not None else '-':>12}")

    conteo = {}
    for r in resultados:
        conteo[r["estado"]] = conteo.get(r["estado"], 0) + 1
    total_filas = sum(r["filas"] or 0 for r in resultados)
    print("\nResumen:", ", ".join(f"{k}={v}" for k, v in sorted(conteo.items())))
    print(f"Filas totales segun metadatos Parquet: {total_filas:,}")
    print(f"taxi_zone_lookup.csv: {'presente' if RUTA_ZONAS.exists() else 'AUSENTE'}")

    if args.salida:
        args.salida.parent.mkdir(parents=True, exist_ok=True)
        args.salida.write_text(
            f"# Verificación de la descarga ({hoy.isoformat()})\n\n"
            f"Resumen: {', '.join(f'{k}={v}' for k, v in sorted(conteo.items()))}  \n"
            f"Filas totales según metadatos Parquet: {total_filas:,}\n\n" + tabla_markdown(resultados),
            encoding="utf-8",
        )
        print(f"Reporte escrito en {args.salida}")

    problemas = [r for r in resultados if r["estado"] in ("FALTA", "FALTA?", "TAMANO_DISTINTO", "ILEGIBLE")]
    return 1 if problemas else 0


if __name__ == "__main__":
    sys.exit(main())
