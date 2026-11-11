# Contoso .NET APM — presenter notes

Public deck: https://ziftech.github.io/dotnetapm/

## One-liner
Install the agent on the host. Weave business DLLs once. Keep method bodies clean (C# + VB). Labels and EDOT are optional.

## Scene cues
1. **Hero** — Scaling problem first, not the product catalog.
2. **Concerns** — 500 methods / Web.config-only hosts / mixed VB+C#.
3. **Layers** — A agent · B aspects · C optional values.
4. **Lab map** — ShipmentsWeb profiler · TrackingApi-EDOT · shared Contoso.Observability.
5. **Profiler** — COR_* / Web.config; Global.asax not required for spans.
6. **EDOT** — OTEL_* flips TraceBackends; medium-term direction.
7. **Weave** — Fody OnEntry/OnExit; not wrappers/inheritance.
8. **C#** — AssemblyInfo Trace; ShipmentService bodies clean.
9. **VB** — AssemblyInfo.vb; MethodBoundaryAspect.Fody 3.6.0.
10. **Backends** — ElasticApmTraceBackend vs ActivitySourceTraceBackend.
11. **Waterfall** — Money slide: LegacyShipmentService + ShipmentService.
12. **Labels** — Optional choke-point SetLabel.
13. **Logs** — trace.id in layouts + log shipper processors.
14. **Demo script** — 15-minute discipline.
15. **Close** — One class library sample + host change surface (Web.config vs build).

## Live proof (optional, private lab)
1. Open `LegacyShipmentService.vb` / `ShipmentService.cs`
2. POST `/web/Checkout` on the lab host
3. APM → ShipmentsWeb → Checkout waterfall
4. TrackingApi-EDOT + Profiler vs EDOT dashboard
