# Business labels + log correlation (demo)

## Continuous load
Background loop on VM: `C:\lab\src\scripts\Demo-Load-Loop.ps1` (checkout + tracking every 2–6s).

## Log ↔ trace correlation
- **TrackingApi (NLog):** `trace.id=${ContosoApmTraceId}|transaction.id=${ContosoApmTransactionId}` in `NLog.config`.
- Renderers fall back to `Activity.Current` so IDs populate under **EDOT** as well as the Elastic APM profiler.
- Logs ship via Elastic Agent as `logs-contoso_app-*` (message text still carries `trace.id=…` — Discover search works; ECS `trace.id` field not parsed yet).
- **ShipmentsWeb (log4net):** checkout lines now include `trace.id=` / `transaction.id=` in the message.

## Business values on transactions
`Contoso.Observability.ApmBusiness` sets:
| Field | Where |
|---|---|
| `tracking_id`, `lane` | APM `labels.*` on ShipmentsWeb checkout |
| `weight_kg`, `quote_price` | APM `numeric_labels.*` |
| `tracking_id`, `shipment_status` | EDOT `attributes.*` on TrackingApi-EDOT |

In Kibana: open a `POST Checkout/Index` trace → **Metadata → Labels**.
