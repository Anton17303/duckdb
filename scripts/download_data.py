#!/usr/bin/env python3
"""Descarga los archivos Parquet del NYC TLC Trip Record Data.

Descarga los registros de viajes de taxis amarillos (yellow) y verdes (green)
para los anios configurados en ``ANIOS_POR_DEFECTO`` (o los indicados con
``--years``) y la tabla de zonas ``taxi_zone_lookup.csv``.

Fuente oficial de los datos:
    https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page

Uso:
    python scripts/download_data.py                       # anios por defecto
    python scripts/download_data.py --years 2024 2025     # anios especificos
    python scripts/download_data.py --taxi yellow
    python scripts/download_data.py --taxi green --years 2026
    python scripts/download_data.py --no-zones

Los archivos se guardan en:
    data/raw/<tipo>/<anio>/<nombre-original>.parquet
    data/raw/zones/taxi_zone_lookup.csv

Comportamiento:
  - La TLC publica cada mes con varias semanas de atraso, por lo que no todos
    los meses del anio en curso existen todavia. El script consulta al servidor
    que meses estan publicados en lugar de suponerlos.
  - Un archivo que ya existe localmente no se vuelve a descargar (idempotente).
  - La descarga se hace sobre un nombre temporal y solo se renombra al
    terminar, de modo que una interrupcion no deja archivos .parquet a medias.
  - Para comprobar que la descarga esta completa use scripts/verify_data.py.

Para incorporar un anio nuevo basta agregarlo a ``ANIOS_POR_DEFECTO`` o pasarlo
con ``--years``; el resto del flujo (vistas SQL con comodines) no cambia.
"""

import argparse
import sys
from pathlib import Path

import requests

ANIOS_POR_DEFECTO = (2026,)
TIPOS_TAXI = ("yellow", "green")
URL_BASE = "https://d37ci6vzurychx.cloudfront.net/trip-data"
URL_ZONAS = "https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv"
RAIZ = Path(__file__).resolve().parent.parent
DIR_DESTINO = RAIZ / "data" / "raw"
RUTA_ZONAS = DIR_DESTINO / "zones" / "taxi_zone_lookup.csv"

TIEMPO_ESPERA = 60          # segundos por peticion
INTENTOS = 3                # intentos por archivo antes de darse por vencido
BLOQUE = 1024 * 1024        # 1 MiB por bloque de descarga
SUFIJO_TEMPORAL = ".part"


def construir_nombre(tipo: str, anio: int, mes: int) -> str:
    """Nombre del archivo publicado por la TLC, p. ej. yellow_tripdata_2026-01.parquet."""
    return f"{tipo}_tripdata_{anio}-{mes:02d}.parquet"


def construir_url(tipo: str, anio: int, mes: int) -> str:
    """URL completa del archivo Parquet mensual."""
    return f"{URL_BASE}/{construir_nombre(tipo, anio, mes)}"


def ruta_destino(tipo: str, anio: int, mes: int) -> Path:
    """Ruta local donde se guarda el archivo."""
    return DIR_DESTINO / tipo / str(anio) / construir_nombre(tipo, anio, mes)


def esta_publicado(url: str) -> bool:
    """Indica si el archivo existe en el servidor (sin descargarlo)."""
    try:
        respuesta = requests.head(url, timeout=TIEMPO_ESPERA, allow_redirects=True)
    except requests.RequestException:
        return False
    return respuesta.ok


def formato_tamanio(n: float) -> str:
    for unidad in ("B", "KiB", "MiB", "GiB"):
        if n < 1024 or unidad == "GiB":
            return f"{n:.1f} {unidad}"
        n /= 1024
    return f"{n:.1f} GiB"


def descargar_archivo(url: str, destino: Path) -> int:
    """Descarga `url` en `destino`. Devuelve la cantidad de bytes escritos."""
    destino.parent.mkdir(parents=True, exist_ok=True)
    temporal = destino.with_name(destino.name + SUFIJO_TEMPORAL)

    ultimo_error = None
    for intento in range(1, INTENTOS + 1):
        try:
            with requests.get(url, stream=True, timeout=TIEMPO_ESPERA) as respuesta:
                respuesta.raise_for_status()
                esperado = int(respuesta.headers.get("Content-Length", 0))
                escritos = 0
                with temporal.open("wb") as archivo:
                    for bloque in respuesta.iter_content(chunk_size=BLOQUE):
                        if bloque:
                            archivo.write(bloque)
                            escritos += len(bloque)
            if escritos == 0:
                raise requests.RequestException("el servidor devolvio un archivo vacio")
            if esperado and escritos != esperado:
                raise requests.RequestException(
                    f"descarga incompleta ({escritos} de {esperado} bytes)"
                )
            temporal.replace(destino)
            return escritos
        except requests.RequestException as error:
            ultimo_error = error
            temporal.unlink(missing_ok=True)
            if intento < INTENTOS:
                print(f"      intento {intento}/{INTENTOS} fallido ({error}); reintentando")

    raise requests.RequestException(f"no se pudo descargar {url}: {ultimo_error}")


def descargar(tipo: str, anio: int) -> dict:
    """Descarga todos los meses publicados de un tipo de taxi y un anio."""
    print(f"\n=== {tipo.upper()} {anio} ===")
    resumen = {"descargados": 0, "omitidos": 0, "no_publicados": [], "fallidos": []}

    for mes in range(1, 13):
        etiqueta = f"{anio}-{mes:02d}"
        destino = ruta_destino(tipo, anio, mes)

        if destino.exists() and destino.stat().st_size > 0:
            print(f"  {etiqueta}  ya existe, se omite")
            resumen["omitidos"] += 1
            continue

        url = construir_url(tipo, anio, mes)
        if not esta_publicado(url):
            print(f"  {etiqueta}  aun no publicado por la TLC")
            resumen["no_publicados"].append(etiqueta)
            continue

        print(f"  {etiqueta}  descargando...")
        try:
            escritos = descargar_archivo(url, destino)
        except requests.RequestException as error:
            print(f"  {etiqueta}  ERROR: {error}")
            resumen["fallidos"].append(etiqueta)
        else:
            print(f"  {etiqueta}  listo ({formato_tamanio(escritos)}) -> {destino}")
            resumen["descargados"] += 1

    return resumen


def descargar_zonas() -> bool:
    """Descarga la tabla de zonas (si no existe). Devuelve False si fallo."""
    print("\n=== ZONAS ===")
    if RUTA_ZONAS.exists() and RUTA_ZONAS.stat().st_size > 0:
        print("  taxi_zone_lookup.csv  ya existe, se omite")
        return True
    try:
        escritos = descargar_archivo(URL_ZONAS, RUTA_ZONAS)
    except requests.RequestException as error:
        print(f"  taxi_zone_lookup.csv  ERROR: {error}")
        return False
    print(f"  taxi_zone_lookup.csv  listo ({formato_tamanio(escritos)}) -> {RUTA_ZONAS}")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Descarga los datos de taxis del NYC TLC (idempotente)."
    )
    parser.add_argument(
        "--taxi", choices=(*TIPOS_TAXI, "all"), default="all",
        help="tipo de taxi a descargar (por defecto: all)",
    )
    parser.add_argument(
        "--years", type=int, nargs="+", default=list(ANIOS_POR_DEFECTO), metavar="ANIO",
        help=f"anios a descargar (por defecto: {' '.join(map(str, ANIOS_POR_DEFECTO))})",
    )
    parser.add_argument(
        "--no-zones", action="store_true",
        help="no descargar taxi_zone_lookup.csv",
    )
    argumentos = parser.parse_args()

    tipos = TIPOS_TAXI if argumentos.taxi == "all" else (argumentos.taxi,)
    anios = sorted(set(argumentos.years))

    total = {"descargados": 0, "omitidos": 0, "no_publicados": [], "fallidos": []}
    for tipo in tipos:
        for anio in anios:
            resumen = descargar(tipo, anio)
            total["descargados"] += resumen["descargados"]
            total["omitidos"] += resumen["omitidos"]
            total["no_publicados"] += [f"{tipo} {m}" for m in resumen["no_publicados"]]
            total["fallidos"] += [f"{tipo} {m}" for m in resumen["fallidos"]]

    zonas_ok = True if argumentos.no_zones else descargar_zonas()

    print("\n" + "=" * 60)
    print("RESUMEN")
    print("=" * 60)
    print(f"  anios         : {', '.join(map(str, anios))}")
    print(f"  descargados   : {total['descargados']}")
    print(f"  ya existian   : {total['omitidos']}")
    print(f"  no publicados : {len(total['no_publicados'])}")
    if total["no_publicados"]:
        print(f"      {', '.join(total['no_publicados'])}")
    print(f"  fallidos      : {len(total['fallidos'])}")
    if total["fallidos"]:
        print(f"      {', '.join(total['fallidos'])}")
    print("=" * 60)
    if total["descargados"] + total["omitidos"] == 0 and total["no_publicados"]:
        print("AVISO: no se obtuvo ningun archivo. CloudFront responde 403 tanto para meses no")
        print("       publicados como para bloqueos de red; revise su conexion antes de asumir")
        print("       que los datos no existen.")
    print("Siguiente paso: python scripts/verify_data.py --years " + " ".join(map(str, anios)))

    return 1 if (total["fallidos"] or not zonas_ok) else 0


if __name__ == "__main__":
    sys.exit(main())
