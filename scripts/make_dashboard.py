#!/usr/bin/env python3
"""Genera el tablero de indicadores (evidencia estatica) con matplotlib.

Lee las tablas ind_* de data/processed/indicadores.duckdb (ver
scripts/build_indicators.py) y compone 12 paneles en una sola figura.
El tablero interactivo equivalente se arma en Metabase (docs/07_indicadores.md).

Uso:
    python scripts/make_dashboard.py                    # escribe docs/tablero.png
    python scripts/make_dashboard.py --salida /tmp/t.png
"""

import argparse
import sys
from pathlib import Path

import duckdb
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

RAIZ = Path(__file__).resolve().parent.parent
BASE = RAIZ / "data" / "processed" / "indicadores.duckdb"
COLOR = {"yellow": "#f2b705", "green": "#2e8b57"}


def leer(con, tabla):
    return con.execute(f"SELECT * FROM {tabla}").df()


def lineas(ax, df, x, y, titulo, ylabel):
    for tipo, g in df.groupby("taxi_type"):
        ax.plot(g[x], g[y], marker="o", ms=3, label=tipo, color=COLOR.get(tipo))
    ax.set_title(titulo, fontsize=10, fontweight="bold")
    ax.set_ylabel(ylabel, fontsize=8)
    ax.tick_params(labelsize=7)
    ax.grid(alpha=0.3)
    ax.legend(fontsize=7)
    if x == "periodo":
        for t in ax.get_xticklabels():
            t.set_rotation(45)
            t.set_ha("right")


def construir(salida: Path) -> None:
    if not BASE.exists():
        sys.exit(f"No existe {BASE}. Ejecute primero: python scripts/build_indicators.py")
    con = duckdb.connect(str(BASE), read_only=True)
    d = {n: leer(con, n) for n in (
        "ind_01_viajes_mensuales", "ind_02_ingreso_mensual", "ind_03_demanda_por_hora",
        "ind_04_viaje_tipico_mensual", "ind_05_metodo_pago_anual", "ind_06_propina_mensual",
        "ind_07_distribucion_distancia", "ind_08_top_zonas_recogida",
        "ind_09_velocidad_por_hora", "ind_10_calidad_mensual")}

    fig, axs = plt.subplots(4, 3, figsize=(20, 22))
    ax = axs.flatten()

    # Panel 0: KPIs
    v, i, c = d["ind_01_viajes_mensuales"], d["ind_02_ingreso_mensual"], d["ind_10_calidad_mensual"]
    periodos = sorted(v["periodo"].unique())
    texto = [f"Periodo: {periodos[0]:%Y-%m} a {periodos[-1]:%Y-%m}", ""]
    for tipo in ("yellow", "green"):
        texto.append(f"{tipo.upper()}: {v[v.taxi_type == tipo].viajes.sum():,.0f} viajes | "
                     f"${i[i.taxi_type == tipo].ingreso_total.sum():,.0f}")
    reg, con_ = c.registros.sum(), c.conservados.sum()
    texto += ["", f"Registros descartados por calidad: {100 * (reg - con_) / reg:.2f} %"]
    ax[0].axis("off")
    ax[0].set_title("KPIs generales", fontsize=10, fontweight="bold")
    ax[0].text(0.02, 0.9, "\n".join(texto), va="top", fontsize=11, family="monospace")

    lineas(ax[1], d["ind_01_viajes_mensuales"], "periodo", "viajes", "1. Viajes por mes", "viajes")
    ax[1].set_yscale("log"); ax[1].set_ylabel("viajes (escala log)", fontsize=8)
    lineas(ax[2], d["ind_02_ingreso_mensual"], "periodo", "ingreso_total", "2. Ingreso total por mes", "USD")
    ax[2].set_yscale("log"); ax[2].set_ylabel("USD (escala log)", fontsize=8)

    # 3: demanda por hora (laboral vs fin de semana)
    h = d["ind_03_demanda_por_hora"]
    for (tipo, dia), g in h.groupby(["taxi_type", "dia_tipo"]):
        ax[3].plot(g.hora, g.pct_viajes, label=f"{tipo} - {dia}", color=COLOR[tipo],
                   ls="-" if dia == "laboral" else "--")
    ax[3].set_title("3. Demanda por hora (% de viajes)", fontsize=10, fontweight="bold")
    ax[3].legend(fontsize=7); ax[3].grid(alpha=0.3); ax[3].tick_params(labelsize=7)

    lineas(ax[4], d["ind_04_viaje_tipico_mensual"], "periodo", "tarifa_media", "4. Tarifa media por viaje", "USD")

    # 5: metodo de pago (apiladas)
    p = d["ind_05_metodo_pago_anual"]
    p["grupo"] = p.taxi_type + " " + p.src_year.astype(str)
    piv = p.pivot_table(index="grupo", columns="metodo", values="pct", aggfunc="sum", fill_value=0)
    piv.plot(kind="bar", stacked=True, ax=ax[5], width=0.8, colormap="tab20")
    ax[5].set_title("5. Método de pago (% de viajes)", fontsize=10, fontweight="bold")
    ax[5].tick_params(labelsize=7); ax[5].legend(fontsize=7); ax[5].set_xlabel("")

    lineas(ax[6], d["ind_06_propina_mensual"], "periodo", "pct_propina_medio",
           "6. Propina media (% de tarifa, tarjeta)", "%")

    # 7: distribucion de distancia (barras agrupadas)
    dist = d["ind_07_distribucion_distancia"].pivot_table(index=["orden", "tramo_millas"], columns="taxi_type", values="pct")
    dist.index = [t for _, t in dist.index]
    dist.plot(kind="bar", ax=ax[7], color=[COLOR.get(c) for c in dist.columns], width=0.8)
    ax[7].set_title("7. Distribución por distancia (% de viajes)", fontsize=10, fontweight="bold")
    ax[7].set_xlabel("millas"); ax[7].tick_params(labelsize=7, rotation=0)

    # 8-9: top zonas
    z = d["ind_08_top_zonas_recogida"]
    for k, tipo in ((8, "yellow"), (9, "green")):
        g = z[z.taxi_type == tipo].sort_values("posicion", ascending=False)
        ax[k].barh(g.zona + " (" + g.borough + ")", g.viajes, color=COLOR[tipo])
        ax[k].set_title(f"8{'ab'[k - 8]}. Top 10 zonas de recogida - {tipo}", fontsize=10, fontweight="bold")
        ax[k].tick_params(labelsize=7)

    # 10: velocidad por hora
    vel = d["ind_09_velocidad_por_hora"]
    for tipo, g in vel.groupby("taxi_type"):
        ax[10].plot(g.hora, g.velocidad_media_mph, marker="o", ms=3, label=tipo, color=COLOR[tipo])
    ax[10].set_title("9. Velocidad media por hora (mph)", fontsize=10, fontweight="bold")
    ax[10].legend(fontsize=7); ax[10].grid(alpha=0.3); ax[10].tick_params(labelsize=7)

    lineas(ax[11], d["ind_10_calidad_mensual"], "periodo", "pct_descartado", "10. % de registros descartados por calidad", "%")

    fig.suptitle("Tablero de indicadores - viajes de taxi NYC (TLC)", fontsize=16, fontweight="bold")
    fig.tight_layout(rect=(0, 0, 1, 0.97))
    salida.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(salida, dpi=110)
    print(f"Tablero escrito en {salida}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Genera el tablero estatico (PNG).")
    parser.add_argument("--salida", type=Path, default=RAIZ / "docs" / "tablero.png")
    construir(parser.parse_args().salida)
