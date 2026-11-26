# Instrumenting Contoso Shipments (.NET Framework 4.8)

This sample shows how to get business-method visibility in Elastic Observability for legacy ASP.NET apps **without editing every method body**. It covers C# and Visual Basic class libraries, and both the Elastic .NET APM profiler and EDOT (OpenTelemetry).

Related deck: https://ziftech.github.io/dotnetapm/

---

## Three layers

| Layer | What changes | What you get |
|---|---|---|
| **A — Agent on the host** | IIS app-pool profiler **or** EDOT / OpenTelemetry on the pool | HTTP transactions, SQL, outbound HTTP, errors, service map |
| **B — Aspect on business DLLs** | One shared library + an assembly-level `Trace` filter | Named business spans (`ShipmentService.*`, `LegacyShipmentService.*`) with **no APM calls in method bodies** |
| **C — Optional values** | A few `SetLabel` / Activity tags at choke points | Filterable fields such as `tracking_id`, `lane`, `weight_kg`, `quote_price` |

Layers A and B are enough for named business timing. Layer C is optional.

---

## Shared aspect (C# and VB)

Traditional APM and EDOT reuse the **same** build-time weave:

1. Add NuGet `MethodBoundaryAspect.Fody` and `FodyWeavers.xml` with `<MethodBoundaryAspect />`.
2. Reference `Contoso.Observability`, which defines `TraceAttribute` (`OnEntry` / `OnExit` / `OnException`).
3. Apply the attribute once at assembly level with namespace / type / method filters.
4. At runtime the aspect calls `TraceBackends.Current.StartSpanOrTransaction(...)`.
5. The host selects the backend:
   - **Profiler path:** `ElasticApmTraceBackend` → Elastic APM Agent API
   - **EDOT path:** `ActivitySourceTraceBackend` → `ActivitySource("Contoso.Observability")` exported over OTLP

```
HTTP request
  └─ Layer A: profiler or EDOT ASP.NET instrumentation  → transaction / server span
       └─ Layer B: Fody-woven business methods           → child spans
            └─ Layer C (optional): labels / tags         → transaction metadata
```

### C# filter example

```csharp
[assembly: Trace(
    NamespaceFilter = @"^Contoso\.Shipments",
    TypeNameFilter = @"Service$",
    MethodNameFilter = @"^(?!MoveNext$|SetStateMachine$).+",
    AttributeTargetMemberAttributes = MulticastAttributes.Public)]
```

### VB.NET filter example (`My Project/AssemblyInfo.vb`)

```vb
<Assembly: Trace(
    NamespaceFilter:="^Contoso\.Shipments\.LegacyVb",
    TypeNameFilter:="Service$",
    MethodNameFilter:="^(?!MoveNext$|SetStateMachine$).+",
    AttributeTargetMemberAttributes:=MulticastAttributes.Public)>
```

The VB sample is `src/Contoso.Shipments.LegacyVb` (`LegacyShipmentService`). Method bodies contain no APM API calls. Checkout calls `EnrichQuoteNote`, so the waterfall shows `LegacyShipmentService.*` next to the C# `ShipmentService.*` spans under the **ShipmentsWeb** service (VB is not a separate APM service).

> **VB on .NET Framework 4.8:** use MethodBoundaryAspect.Fody **3.6.0** (earlier 2.x builds can fail VB attribute resolution). Keep explicit `mscorlib` and `System` references on Framework VB projects so Fody can resolve `System.Object`.

---

## Profiler path (ShipmentsWeb)

`ShipmentsWeb` runs on IIS with the Elastic .NET APM profiler attached to the app pool.

| Piece | How this sample wires it |
|---|---|
| Profiler | App-pool env: `COR_ENABLE_PROFILING`, `COR_PROFILER`, profiler path (`scripts/Install-ApmProfiler.ps1`, `scripts/Configure-ApmPool.ps1`) |
| Service name | `ElasticApm:ServiceName` = `ShipmentsWeb` in `Web.config` |
| Auto instrumentation | ASP.NET MVC, SqlClient, HttpClient / HttpWebRequest |
| Business spans | Fody → `ElasticApmTraceBackend` |
| Optional labels | `CheckoutLabelsHttpModule` registered in `Web.config` (request form/query fields) |
| Logs | log4net layout converters `%apm_trace_id` / `%apm_transaction_id` |

**Labels caveat:** the HTTP module can only promote values that exist on the request (form / query). Response-time fields such as `quote_price` still need one app touchpoint (this sample sets `HttpContext.Items["quote_price"]` in the controller so the module can attach them on the way out). For apps you cannot recompile, stick to request-derived labels.

**What to look for in Elastic APM**

1. Source: `ShipmentService.cs` / `LegacyShipmentService.vb` — no APM API in bodies.
2. `POST /web/Checkout`
3. Service **ShipmentsWeb** → transaction `POST Checkout/Index`:
   - `LegacyShipmentService.EnrichQuoteNote` (and nested helpers)
   - `ShipmentService.CreateQuoteAsync`
   - SQL and outbound HTTP to Tracking
4. Optional labels: `tracking_id`, `lane`, `weight_kg` (and `quote_price` when the controller/Items hook is present)
5. Logs correlated by the same `trace.id`

Product docs: [Profiler auto instrumentation](https://www.elastic.co/docs/reference/apm/agents/dotnet/setup-auto-instrumentation) · [ASP.NET / IIS](https://www.elastic.co/docs/reference/apm/agents/dotnet/setup-asp-dot-net)

---

## EDOT path (TrackingApi)

`TrackingApi` runs on a **dedicated** IIS pool (`TrackingEdotPool`) with OpenTelemetry .NET AutoInstrumentation (zero-code). ShipmentsWeb stays on `SharedPool` with the Elastic .NET APM profiler.

> **One profiler per process:** the CLR loads a single native profiler. Do **not** mix Elastic APM profiler and OTel auto-instrumentation on the same app pool / `w3wp` process. In this lab, EDOT is isolated on `TrackingEdotPool`. Moving shared-pool apps to EDOT means moving **the whole pool** together — never half Elastic / half EDOT on one pool.

| Piece | How this sample wires it |
|---|---|
| Trigger | IIS zero-code: `Install-OpenTelemetryCore` + `Register-OpenTelemetryForIIS`, then pool-scoped `OTEL_*` / `COR_*` (see `scripts/Install-EdotZeroCodeIis.ps1`) |
| Auto instrumentation | OpenTelemetry .NET AutoInstrumentation profiler — **no** `OpenTelemetrySdk` bootstrap in `Global.asax` |
| Business spans | Same Fody aspects → `ActivitySource("Contoso.Observability")` via `OTEL_DOTNET_AUTO_TRACES_ADDITIONAL_SOURCES=Contoso.Observability` |
| Service name | `OTEL_SERVICE_NAME` → `TrackingApi-EDOT` |
| `Global.asax` | Still present only to pick an exception logger. Traces work without SDK code there. Without a `Global.asax` at all, rely on automatic capture for **unhandled** exceptions only. |
| Fallback | If OTEL env is unset, `TraceBackends` selects `ElasticApmTraceBackend` (classic profiler path) |

**What to look for**

1. Service **TrackingApi-EDOT** (agent name around `opentelemetry/dotnet/...`)
2. Dashboard NDJSON under `kibana/contoso-profiler-vs-edot-dashboard.json`
3. Tracking request traces: server span plus woven business spans such as `ShipmentService.LookupStatus`

**Evidence note:** the zero-code / labels checks are smoke proofs (small document counts), not overhead benchmarks. For latency overhead, use the earlier 10-minute stage runs under `results/overhead-*`.

Product docs: [EDOT .NET](https://www.elastic.co/docs/reference/opentelemetry/edot-sdks/dotnet) · [Migrate from the APM .NET agent](https://www.elastic.co/docs/reference/opentelemetry/edot-sdks/dotnet/migration)

---

## Walkthrough

1. Open `LegacyShipmentService.vb` and `ShipmentService.cs` — method bodies have no APM calls.
2. Open each assembly’s `Trace` filter in `AssemblyInfo`.
3. Submit Checkout (for example `lane=DXB-AMM`) and confirm the page shows the VB enrich note.
4. In APM, open **ShipmentsWeb** → `POST Checkout/Index` and find both VB and C# business spans.
5. Optionally inspect labels and log lines for the same `trace.id`.
6. Optionally open **TrackingApi-EDOT** and the Profiler vs EDOT dashboard to compare backends with the same aspect library.

---

## Takeaway

Install the agent on the host (Web.config / IIS). Add one shared aspect package to each business DLL build and set assembly filters. Method bodies stay clean for C# and VB. Labels and OpenTelemetry are optional next steps.

---

## Repository map

| Item | Path |
|---|---|
| Aspect + backends | `src/Contoso.Observability/` |
| C# woven business DLL | `src/Contoso.Shipments.Business/` |
| VB woven business DLL | `src/Contoso.Shipments.LegacyVb/` |
| Profiler web app | `src/ShipmentsWeb/` |
| EDOT-capable web API | `src/TrackingApi/` |
| Build / deploy | `scripts/Build-And-Deploy.ps1` (re-run `Install-EdotTrackingApi.ps1` afterward if `/tracking` should stay on the EDOT pool) |
| Weave checks | `scripts/Verify-AssemblyWeave.ps1`, `scripts/Verify-VbAssemblyWeave.ps1` |
| Comparison dashboard | `kibana/contoso-profiler-vs-edot-dashboard.json` |
| Business-values dashboard | `kibana/contoso-business-values-dashboard.json` |
| Presentation | https://ziftech.github.io/dotnetapm/ (`preso/`) |

```sh
cd preso && npm ci && npm run dev -- --port 4175
```
