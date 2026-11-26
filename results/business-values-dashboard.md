# Contoso dashboards

## Business values
- **URL:** <redacted-project-url>
- **ID:** `619d4d9b-70b4-40dd-8920-6adf47f68c65`
- Definition: `kibana/contoso-business-values-dashboard.json`

## Profiler vs EDOT (re-fixed)
- **URL:** <redacted-project-url>
- **ID:** `8f6a0e24-e9a9-447b-b3d4-671575d996ee`
- EDOT volume now queries `traces-generic.otel-default` with aliased `time_bucket = BUCKET(@timestamp, 1 hour)` (no `?_tstart` — those broke the xy panel).
