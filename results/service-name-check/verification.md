# Per-app ServiceName verification

## Config on VM

- `ShipmentsWeb` Web.config: `ElasticApm:ServiceName=ShipmentsWeb`
- `TrackingApi` Web.config: `ElasticApm:ServiceName=TrackingApi`
- SharedPool `ELASTIC_APM_SERVICE_NAME`: absent (no pool override)

## Load

- k6 5m @ 10/s (`results/service-name-check/window.txt`)
- checks ≈ 99.94% (8992/8997)

## Elasticsearch `service.name` (last 5m, traces-apm*)

| service.name | docs |
|---|---|
| ShipmentsWeb | 10009 |
| TrackingApi | 9694 |

**No `Shipments_SharedPool`.**

## Screenshots (last 15m)

| File | Content |
|---|---|
| `screenshots/10-service-inventory-last-15m.png` | Service inventory — ShipmentsWeb + TrackingApi only |
| `screenshots/11-checkout-trace-waterfall-last-15m.png` | POST Checkout waterfall with business spans + TrackingApi children |
| `screenshots/12-slow-sql-span-stacktrace-last-15m.png` | WAITFOR SQL span details + Stack Trace tab |
| `screenshots/13-service-map-last-15m.png` | Service map ShipmentsWeb → TrackingApi → mssql |

Sample trace: `ba6a3a839d8a18faf4a005388bd1b026` / WAITFOR span `6e891179a1e9e3da` (stack includes `Contoso.Shipments.Business.ShipmentRepository.RunSlowQuery`).
