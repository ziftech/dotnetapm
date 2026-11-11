# APM Logs tab correlation

## Problem
ShipmentsWeb **Logs** tab showed “No results found” because `logs-contoso_app-*` had no ECS `service.name` / `trace.id` — only plaintext in `message`.

## Fix
Fleet package policy **`lab-app-logs`** (Custom Logs) processors (rev 2+):

- Set `service.name` from file path (`shipments-web.log` → `ShipmentsWeb`, `tracking-api.log` → `TrackingApi-EDOT`)
- Parse `trace.id` / `transaction.id` from the message into ECS fields

Source: `results/lab-app-logs-processors.yaml`

## Where to look
1. APM → **ShipmentsWeb** → **Logs** (Last 15 minutes, environment **lab** or All)
2. Or open a checkout waterfall → Logs / correlated logs once `trace.id` matches
3. Discover: `service.name: "ShipmentsWeb" and trace.id: *`

Verified after fix: ShipmentsWeb logs present in last 15m with `trace.id` populated on checkout lines.
