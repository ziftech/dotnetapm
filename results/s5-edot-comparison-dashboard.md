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

## Panel fix (2026-11-11)

EDOT volume chart was empty because the xy layer used an aliased `time_bucket` column with hardcoded `NOW()-7d` and `ignore_global_filters=false`. Panels now use Kibana time params (`?_tstart` / `?_tend`) and `BUCKET(@timestamp, 1 hour, ?_tstart, ?_tend)` with the bar series for sparse EDOT data.

## Volume panel fix (categorical hours)

Date-axis `BUCKET(@timestamp, 1 hour)` bars were blanked when the dashboard time picker (e.g. Last 3 days) did not align with sparse EDOT buckets. Panels now use `DATE_FORMAT(... )` keyword hours so bars always render.
