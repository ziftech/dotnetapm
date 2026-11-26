# NuGet zero-code verification

Generated: 2026-11-26 16:25 Asia/Dubai

## Package install (lab)

- Contoso.Shipments.Business and Contoso.Shipments.LegacyVb consume Contoso.Observability 1.0.0 from `./artifacts`.
- Hand-written assembly Trace attributes removed; package targets generate them (`ContosoTraceTypeFilter=Service$`).

## Weave

See `weave-csharp.json` / `weave-vb.json`.

## Traffic smoke

- GET `/web/Checkout`: ok=20 fail=0 (20 tries)
- POST `/web/Checkout`: status=200

## Runtime kill switch

Proven on lab (`scripts/Prove-KillSwitch.ps1`), Asia/Dubai 2026-11-26 16:25:

| Step | Contoso:Trace:Enabled | POST /web/Checkout |
|---|---|---|
| baseline | `true` | 200 |
| kill | `false` | 200 (no rebuild; pool recycle only) |
| restored | `true` | 200 |

Config key is present in deployed `C:\lab\app\ShipmentsWeb\Web.config` and in source `src/ShipmentsWeb/Web.config`. Aspect honors `TraceSettings` so spans stop without a rebuild when set to `false`.

## Screenshots

Local only (gitignored under `screenshots/`). Present on this workstation:

- `screenshots/16-vb-legacyshipmentservice-waterfall.png` — LegacyVb / business spans under IIS transaction

Capture additional Kibana shots (per-app service names, log4net/NLog `trace.id`) on the lab workstation as needed; do not commit PNGs.

## Overhead (10m @ 10 req/s)

Existing suite results in `results/overhead-10m/` (also copied as `overhead-10m-table.md` here). k6 **checks = 100%** for all stages (gate >95% / plan 100% checkout checks):

| Stage | med | p95 | fail_rate | checks |
|---|---|---|---|---|
| B0 (no weave, no profiler) | 43.26ms | 101.11ms | 1.99% | 100.00% |
| S1 (no weave, profiler) | 39.99ms | 101.46ms | 1.96% | 100.00% |
| narrow (Service$ weave) | 46.84ms | 110.96ms | 1.97% | 100.00% |
| broad | 40.64ms | 111.15ms | 2.01% | 100.00% |

Driven by `scripts/drive_overhead_suite.sh` + `scripts/Run-Overhead10m.ps1` / `Prepare-OverheadStage.ps1`.
