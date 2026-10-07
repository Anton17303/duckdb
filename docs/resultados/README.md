# Resultados generados

Esta carpeta se llena al ejecutar (con los datos reales descargados):

```bash
python scripts/verify_data.py --salida docs/resultados/verificacion_descarga.md
python scripts/run_analysis.py            # 01_exploracion.md y 02_eda.md
python scripts/run_analysis.py 03_incorporacion.sql
python scripts/benchmark.py --rebuild     # benchmark.md + data/processed/benchmark_resultados.csv
python scripts/build_indicators.py        # indicadores.md
```

Cada archivo incluye la consulta SQL, su objetivo, la fuente, el tiempo y el resultado.
**Súbalos al fork** una vez generados con los datos reales (son la evidencia del laboratorio).
