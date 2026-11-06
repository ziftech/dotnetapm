# Overhead 10m @ 10 req/s (k6 constant-arrival-rate)

| Stage | med | p95 | max | fail_rate | throughput |
|---|---|---|---|---|---|
| B0 | 84.31ms | 712.21ms | 60005.46ms | 2.68% | 25.387/s |
| S1 | 64.70ms | 132.25ms | 7536.92ms | 1.97% | 29.869/s |
| narrow | 37.31ms | 76.28ms | 364.24ms | 35.29% | 29.995/s |
| broad | 45.56ms | 120.44ms | 8807.00ms | 1.99% | 29.861/s |

Stages: **B0**=`[assembly: DisableWeaving]` + profiler cleared; **S1**=DisableWeaving + profiler; **narrow**=assembly `Trace` `TypeNameFilter=Service$`; **broad**=Service$ + PricingCalculator/CallChain/ShipmentRepository.

Built-in Fody attribute: `MethodBoundaryAspect.Fody.Attributes.DisableWeavingAttribute`.
