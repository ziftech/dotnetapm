# Overhead 10m @ 10 req/s (k6 constant-arrival-rate)

| Stage | med | p95 | max | fail_rate | throughput | checks |
|---|---|---|---|---|---|---|
| B0 | 43.26ms | 101.11ms | 8422.42ms | 1.99% | 29.881/s | 100.00% |
| S1 | 39.99ms | 101.46ms | 5305.93ms | 1.96% | 29.980/s | 100.00% |
| narrow | 46.84ms | 110.96ms | 4079.65ms | 1.97% | 29.971/s | 100.00% |
| broad | 40.64ms | 111.15ms | 3224.40ms | 2.01% | 29.995/s | 100.00% |

Stages: B0=DisableWeaving+no profiler; S1=DisableWeaving+profiler; narrow=assembly Trace Service$; broad=Service$+Pricing/CallChain/Repository.
Gate: checks rate must be >95% for the stage numbers to count.
Warm-up: Prepare-OverheadStage warms home/tracking/checkout and gates checkout ≥9/10 before k6.
