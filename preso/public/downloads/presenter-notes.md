# Contoso .NET APM — presenter notes (high level)

Public deck: https://ziftech.github.io/dotnetapm/

## One-liner
Install the agent on the host. Weave business DLLs once. Keep method bodies clean (C# + VB).

## 7 scenes
1. **Hero** — Per-method APM does not scale.
2. **Layers** — A agent · B aspects · C optional labels.
3. **Agent** — Profiler or EDOT: HTTP/SQL/map without business edits.
4. **Aspects** — One assembly Trace filter; C# and VB bodies stay clean.
5. **Backends** — Same weave → Elastic APM or EDOT/OTLP.
6. **Proof** — ShipmentsWeb Checkout waterfall: LegacyShipmentService + ShipmentService.
7. **Close** — Agent + aspects; labels/EDOT optional.

## Finding VB in Elastic
VB is **not** a separate service. Open **ShipmentsWeb** → `POST Checkout/Index` → waterfall → `LegacyShipmentService.*`.
