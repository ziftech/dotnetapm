# Overhead (measured 90s k6, 4 VUs)

| Run | med | p95 | max | fail | throughput |
|---|---|---|---|---|---|
| B0-no-agent | 89.56ms | 144.43ms | 10.63s | 6.52% | 14.904336/s |
| B1-profiler | 97.73ms | 152.82ms | 5.44s | 6.60% | 15.41791/s |
| S1 | 57.54ms | 137.91ms | 11.75s | 6.78% | 18.395842/s |
| S2-repaired | 98.57ms | 151.25ms | 10.12s | 6.59% | 14.751863/s |

Note: short runs; do not extrapolate. B0 was before agent; S2-repaired is profiler+Fody+per-app names.
