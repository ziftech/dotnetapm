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
| Service name | `ElasticApm:ServiceName` = `ShipmentsWeb` in `Web.config` (prefer also setting `ELASTIC_APM_SERVICE_NAME` on the pool) |
| Auto instrumentation | ASP.NET MVC, SqlClient, HttpClient / HttpWebRequest |
| Business spans | Fody → `ElasticApmTraceBackend` |
| Optional labels | `ApmBusiness.SetCheckoutLabels` in `CheckoutController` |
| Logs | log4net includes `trace.id` / `transaction.id` for correlation |

**What to look for in Elastic APM**

1. Source: `ShipmentService.cs` / `LegacyShipmentService.vb` — no APM API in bodies.
2. `POST /web/Checkout`
3. Service **ShipmentsWeb** → transaction `POST Checkout/Index`:
   - `LegacyShipmentService.EnrichQuoteNote` (and nested helpers)
   - `ShipmentService.CreateQuoteAsync`
   - SQL and outbound HTTP to Tracking
4. Optional labels: `tracking_id`, `lane`, `weight_kg`, `quote_price`
5. Logs correlated by the same `trace.id`

Product docs: [Profiler auto instrumentation](https://www.elastic.co/docs/reference/apm/agents/dotnet/setup-auto-instrumentation) · [ASP.NET / IIS](https://www.elastic.co/docs/reference/apm/agents/dotnet/setup-asp-dot-net)

---

## EDOT path (TrackingApi)

`TrackingApi` can run with the Elastic Distribution of OpenTelemetry (.NET) when the pool sets `OTEL_EXPORTER_OTLP_ENDPOINT`.

| Piece | How this sample wires it |
|---|---|
| Trigger | Pool `OTEL_*` variables (including `OTEL_SERVICE_NAME` → `TrackingApi-EDOT`) |
| Startup | `TrackingApi/Global.asax.cs`: when OTLP is set → `ActivitySourceTraceBackend` + OpenTelemetry SDK (`WithElasticDefaults`, AspNet, SqlClient, `AddSource("Contoso.Observability")`) |
| Auto instrumentation | OpenTelemetry ASP.NET + SqlClient |
| Business spans | Same Fody aspects → `ActivitySourceTraceBackend` → OTLP |
| Fallback | If OTLP is unset, TrackingApi uses `ElasticApmTraceBackend` (profiler path) |

**What to look for**

1. Service **TrackingApi-EDOT** (agent name around `opentelemetry/dotnet/elastic`)
2. Dashboard NDJSON under `kibana/contoso-profiler-vs-edot-dashboard.json`
3. Tracking request traces: server span plus woven business / Internal spans from `Contoso.Observability`

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
