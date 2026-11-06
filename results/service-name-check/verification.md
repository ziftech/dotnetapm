# Per-app ServiceName + narrow checkout verification

## Config on VM

- Weave: **narrow** (`TypeNameFilter = Service$`) — `WEAVE_OK_ASSEMBLY_TRACE`
- `ShipmentsWeb` / `TrackingApi` Web.config: per-app `ElasticApm:ServiceName`
- SharedPool: `ELASTIC_APM_APPLICATION_NAMESPACES=Contoso.`, `ELASTIC_APM_SPAN_STACK_TRACE_MIN_DURATION=0ms`
- HttpWebRequest path: `GetResponseAsync` + distinct `-wr` URL; TrackingApi: 25 ms sleep (lab)

## Sample narrow checkout (clean)

- Trace: `b0ab8ed422b9f48703de78c3cc0a9790`
- Tx: `774d0a410e54f92e`
- WAITFOR span: `84c439d0540bd483` (~2011 ms) with `Contoso.Shipments.Business.ShipmentRepository.RunSlowQuery` on stack
- HTTP outbound: 41 ms + 51 ms (both non-zero); TrackingApi children match

## Screenshots (last 15–30m)

| File | Content |
|---|---|
| `screenshots/10-service-inventory-last-15m.png` | Service inventory — ShipmentsWeb + TrackingApi |
| `screenshots/11-checkout-trace-waterfall-last-15m.png` | POST Checkout waterfall: ShipmentService + WAITFOR + TrackingApi |
| `screenshots/12-slow-sql-span-stacktrace-last-15m.png` | WAITFOR Stack Trace with RunSlowQuery |
| `screenshots/13-service-map-last-15m.png` | ShipmentsWeb → TrackingApi → mssql |

See also `zero-us-http-spans.md` for the 0 µs HTTP investigation and ApplicationNamespaces/`library_frame` notes.
