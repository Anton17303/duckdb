# Ejercicio 4 — Análisis exploratorio

Consultas: [`sql/02_eda.sql`](../sql/02_eda.sql). Resultados generados:
`docs/resultados/02_eda.md` (`python scripts/run_analysis.py 02_eda.sql`).
Notebook: `notebooks/02_eda.ipynb`.

## 4.1 Preguntas y justificación

| # | Pregunta | Por qué se plantea (a partir de la exploración) | Consulta |
|---|---|---|---|
| P1 | ¿Cómo evolucionan viajes e ingreso por mes y tipo? | Los datos son mensuales y crecen por periodos: es el eje temporal del caso. | `q4_p1_*` |
| P1b | ¿Hay días con volumen anómalo? | Detectar feriados, clima o fallas de captura. | `q4_p1b_*` |
| P2 | ¿A qué horas se concentra la demanda? | Patrón temporal intradía; puede diferir entre taxis. | `q4_p2_*` |
| P3 | ¿Laborales vs fin de semana? | Patrón semanal. | `q4_p3_*` |
| P4 | ¿Distancia, duración y tarifa típicas? ¿Pasajeros? | Describir el viaje típico y su dispersión. | `q4_p4_*`, `q4_p4b_*` |
| P5 | ¿En qué se diferencian amarillos y verdes? | Son servicios distintos (zonas de operación). | `q4_p5_*`, `q4_p11_*` |
| P6 | ¿Cómo pagan y cuánta propina dejan? | `payment_type` tiene varios códigos; la propina solo se registra con tarjeta. | `q4_p6_*`, `q4_p6b_*` |
| P7 | ¿Cómo se distribuyen tarifa y distancia? | Las colas largas sugieren outliers. | `q4_p7_*`, `q4_p7b_*` |
| P8 | ¿Qué atípicos quedan tras la limpieza? | Validar que R1–R6 son suficientes. | `q4_p8_*`, `q4_p8b_*` |
| P9 | ¿Cuántos registros elimina cada regla? | Transparentar el costo de la limpieza. | `q4_p9_*` |
| P10 | ¿La tarifa crece con la distancia? | Consistencia tarifaria; mínimos y recargos. | `q4_p10_*` |
| P11 | ¿Dónde recogen los taxis? | Complementa P5 con geografía. | `q4_p11_*` |

## 4.4 – 4.5 Resultados y hallazgos

Los resultados numéricos dependen de los archivos reales de la TLC, que deben
descargarse en el ambiente del equipo; por eso esta sección **se completa tras
ejecutar** `run_analysis.py`, en `docs/informe.md` (sección *Ejercicio 4*), con al
menos tres hallazgos respaldados por consultas concretas.
