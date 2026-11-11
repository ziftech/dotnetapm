# Contoso APM — Profiler vs EDOT dashboard

- **Kibana:** [Contoso APM — Profiler vs EDOT](https://apm-yk-f7bd37.kb.europe-west4.gcp.elastic.cloud/app/dashboards#/view/8f6a0e24-e9a9-447b-b3d4-671575d996ee)
- **ID:** `8f6a0e24-e9a9-447b-b3d4-671575d996ee`
- **Definition (recreate):** `kibana/contoso-profiler-vs-edot-dashboard.json`
- **Screenshot:** `screenshots/14-profiler-vs-edot-dashboard.png`

Panels use ES|QL against `traces-apm*` and `traces-*.otel*` (EDOT uses root field `kind` / `scope.name`, not APM `span.*`).

## Live binding for demo

`/tracking` is on **TrackingEdotPool** (`TrackingApi-EDOT`) so the EDOT panels have live data. `/web` stays on SharedPool profiler (`ShipmentsWeb`).

Restore profiler-only TrackingApi after the demo:

```powershell
powershell -File C:\lab\src\scripts\Restore-ProfilerTrackingApi.ps1
```
