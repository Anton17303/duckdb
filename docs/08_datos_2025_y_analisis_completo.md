# Ejercicio 8 — Incorporación de 2025 y análisis completo

## 8.1 – 8.2 Cambio en el sistema de descarga

Igual que con 2024, solo cambia la constante de años (la lógica no se toca):

```python
ANIOS_POR_DEFECTO = (2024, 2025, 2026)   # antes: (2024, 2026)
```

```bash
docker compose exec lab python scripts/download_data.py     # baja solo 2025; 2024 y 2026 -> "ya existe"
docker compose exec lab python scripts/download_data.py     # segunda corrida: nada que descargar
docker compose exec lab python scripts/verify_data.py --salida docs/resultados/verificacion_descarga.md
```

> **Evidencia pendiente:** salida de las dos corridas (la segunda debe mostrar
> `descargados: 0`).

## 8.3 Las consultas siguen funcionando

Ninguna consulta de los ejercicios 3–7 menciona un año. Se comprobó ejecutando todos
los archivos `sql/*.sql` con 1 año (2026), con 3 años (2024–2026) y reconstruyendo
los indicadores, sin editar ninguna consulta:

```bash
docker compose exec lab python scripts/run_analysis.py     # 01, 02, 03 y 06
docker compose exec lab python scripts/build_indicators.py
```

## 8.4 Indicadores y visualizaciones con los tres años

Los indicadores (`sql/05_indicadores.sql`) agrupan por `periodo`/`src_year` y
leen con comodines, por lo que **se actualizan al reconstruirlos**:

```bash
docker compose exec lab python scripts/build_indicators.py
docker compose exec lab python scripts/make_dashboard.py
```

En Metabase basta con refrescar las tarjetas (las tablas `ind_*` cambian de
contenido, no de estructura).

## 8.5 – 8.7 Evolución, patrones y consultas

Consultas en [`sql/06_evolucion.sql`](../sql/06_evolucion.sql) (resultado en
`docs/resultados/06_evolucion.md`):

| Consulta | Qué permite ver |
|---|---|
| `q8_0_meses_comunes` | qué meses existen en todos los años (base de una comparación justa) |
| `q8_1_resumen_anual_mismos_meses` | viajes, ingreso, tarifa, distancia, duración, % tarjeta y propina por año |
| `q8_2_variacion_interanual` | variación % año contra año de viajes, tarifa y distancia |
| `q8_3_hora_pico_por_anio` | cambios en el patrón horario |
| `q8_4_mezcla_de_pago_por_anio` | cambios en la mezcla de métodos de pago |
| `q8_5_calidad_por_anio` | cambios en el % de registros descartados |
| `q8_6_participacion_verde` | peso relativo de los taxis verdes mes a mes |

> **Cuidado con 2026**: la TLC publica con retraso, por lo que 2026 tiene menos
> meses. Comparar un año completo con uno parcial infla las diferencias; por eso
> las consultas `q8_1`–`q8_5` usan solo los **meses comunes a todos los años**.
> `q8_6` y los indicadores 1–2 y 10 muestran la serie completa por mes.

Los **tres cambios o patrones** (8.6) se redactan con los números reales en
`docs/informe.md` (sección *Ejercicio 8*), a partir de las consultas `q8_*` y del
tablero. Los candidatos naturales a revisar son: variación interanual del volumen
y de la tarifa, cambio en la mezcla de pago (tarjeta vs. efectivo), cambios en el
indicador de calidad y diferencias entre años en los cargos que aparecen en
archivos recientes (p. ej. `cbd_congestion_fee`, visibles en `q3_4`/`q5_5`).
