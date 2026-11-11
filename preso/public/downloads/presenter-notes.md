# Contoso .NET APM — presenter notes

Evidence date: 11 Nov 2026 (Asia/Dubai). Lab: http://34.18.109.143

## One-liner
Install the agent on the host. Weave business DLLs once. Keep method bodies clean (C# + VB). Labels and EDOT are optional.

## Scene cues
1. **Hero** — Objection first, not product catalog.
2. **Objection** — Mirror 500 methods / Web.config / Dynatrace.
3. **Layers** — A agent · B aspects · C optional values.
4. **Lab map** — ShipmentsWeb profiler · TrackingApi-EDOT · shared Contoso.Observability.
5. **Profiler** — COR_* / Web.config; Global.asax not required for spans.
6. **EDOT** — OTEL_* flips TraceBackends; medium-term direction.
7. **Weave** — Fody OnEntry/OnExit; not wrappers/inheritance.
8. **C#** — AssemblyInfo Trace; ShipmentService bodies clean.
9. **VB** — AssemblyInfo.vb; MBA 3.6.0; ask for one real VB DLL.
10. **Backends** — ElasticApmTraceBackend vs ActivitySourceTraceBackend.
11. **Waterfall** — Money slide: LegacyShipmentService + ShipmentService.
12. **Labels** — Optional choke-point SetLabel.
13. **Logs** — trace.id in layouts + Fleet processors.
14. **Demo script** — 15-minute discipline.
15. **Close** — Ask for one class library + host change rights.

## Live proof (optional)
1. Open `LegacyShipmentService.vb` / `ShipmentService.cs`
2. POST http://34.18.109.143/web/Checkout
3. APM → ShipmentsWeb → Checkout waterfall
4. TrackingApi-EDOT + Profiler vs EDOT dashboard
