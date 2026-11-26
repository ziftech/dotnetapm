# Contoso.Observability — compatibility matrix

| Technology | Approach | Code change |
|---|---|---|
| ASP.NET MVC / Web API on .NET Framework 4.6.2+ | Profiler agent or EDOT zero-code, plus package in the business DLLs | None (package + rebuild) |
| App **without source** | Profiler agent or EDOT zero-code; `ApmContextHttpModule` and labels via `web.config` | None; no business-method spans |
| VB.NET libraries | Same package (generated `.vb` attribute) | None |
| Windows services / workers | Package with `ContosoTraceStartTransactions=true`, or `ApmEntryPoint` at the one entry method | None, or one line |
| WCF ⚠ | EDOT .NET has WCF instrumentation on .NET Framework; check the traditional agent's WCF coverage | None |
| .NET Core / .NET 8 ⚠ | EDOT .NET (NuGet or zero-code) with `ActivitySource` backend; package may need a `netstandard2.0` target | None to minimal |
| Angular v2–v16 | Elastic RUM agent (`@elastic/apm-rum-angular`), distributed tracing to the backend | A few lines in the app module |
| Classic ASP | Not .NET: IIS logs, IIS integration, synthetic monitors | None |

## Risks

- **"No code changes" still means a rebuild.** Vendor binaries and apps without source cannot be woven.
- Field-built **community sample**, not an Elastic-supported product — ownership must be agreed with the adopting team.
- **Fody / MethodBoundaryAspect** are MIT; Fody asks commercial users to back it on OpenCollective.
- **Broad filters can hit the 500-span cap.** Start with `*Service` types and widen.
- **Elastic.Apm NuGet must match the profiler version** (1.34.7 in the lab), or the DiagnosticSource conflict returns.
