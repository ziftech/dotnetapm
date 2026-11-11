# Contoso .NET APM lab — demo guide (Profiler vs EDOT + aspects)

Audience: customer sessions (legacy .NET Framework 4.8, C# and VB class libraries).
Lab VM: `http://34.18.109.143` · Kibana: Elastic Observability (serverless project used by the lab).

---

## 1. What to say in the first two minutes

We do **not** ask teams to wrap hundreds of methods with `CaptureTransaction`.

| Layer | What you install / change | What you get |
|---|---|---|
| **A — Agent on the host** | IIS pool COR_* profiler **or** EDOT/OTel on the app pool | HTTP transactions, SQL, outbound HTTP, errors, service map |
| **B — Aspect on business DLLs** | One shared library + assembly-level `[Trace]` / `<Assembly: Trace>` | Named business spans (`ShipmentService.*`, `LegacyShipmentService.*`) **without editing method bodies** |
| **C — Optional values** | A few `SetLabel` / Activity tags at choke points | `tracking_id`, `lane`, `weight_kg`, `quote_price` for filtering |

**Demo order:** open untouched business code → show assembly Trace filter → run Checkout → open waterfall → (optional) labels / logs / EDOT side-by-side.

---

## 2. How instrumentation works (shared aspect)

Both traditional APM and EDOT reuse the **same** build-time weave:

1. NuGet: `MethodBoundaryAspect.Fody` + project `FodyWeavers.xml` (`<MethodBoundaryAspect />`).
2. Shared library: `Contoso.Observability` defines `TraceAttribute` (`OnEntry` / `OnExit` / `OnException`).
3. Business DLL applies it once at assembly level with filters (namespace / `*Service` / public methods).
4. At runtime the aspect calls `TraceBackends.Current.StartSpanOrTransaction(...)`.
5. Host selects the backend:
   - **Traditional:** `ElasticApmTraceBackend` → Elastic APM Agent API (`ISpan` / `ITransaction`)
   - **EDOT:** `ActivitySourceTraceBackend` → `ActivitySource("Contoso.Observability")` exported by OpenTelemetry / EDOT

```
HTTP request
    └─ Layer A: profiler or EDOT ASP.NET instrumentation  → transaction / server span
         └─ Layer B: Fody-woven business methods           → child spans (app/business or Internal)
              └─ Layer C (optional): labels / tags         → Metadata in Kibana
```

C# assembly filter (narrow):

```csharp
[assembly: Trace(
    NamespaceFilter = @"^Contoso\.Shipments",
    TypeNameFilter = @"Service$",
    MethodNameFilter = @"^(?!MoveNext$|SetStateMachine$).+",
    AttributeTargetMemberAttributes = MulticastAttributes.Public)]
```

VB.NET equivalent (`My Project/AssemblyInfo.vb`):

```vb
<Assembly: Trace(
    NamespaceFilter:="^Contoso\.Shipments\.LegacyVb",
    TypeNameFilter:="Service$",
    MethodNameFilter:="^(?!MoveNext$|SetStateMachine$).+",
    AttributeTargetMemberAttributes:=MulticastAttributes.Public)>
```

The VB sample lives in `src/Contoso.Shipments.LegacyVb` (`LegacyShipmentService`). Method bodies have **no** APM calls. Checkout calls `EnrichQuoteNote` so the waterfall shows `LegacyShipmentService.*` next to the C# `ShipmentService.*` spans.

> **VB note:** Lab uses MethodBoundaryAspect.Fody **3.6.0** (required for reliable VB weaving; 2.0.149 NRE’d on VB attribute resolution). Keep explicit `mscorlib` + `System` references on Framework VB projects so Fody can resolve `System.Object`.


---

## 3. Traditional path — Elastic .NET APM Profiler

**Host:** `ShipmentsWeb` on IIS **SharedPool**.

| Piece | Contoso wiring |
|---|---|
| Profiler | Pool env: `COR_ENABLE_PROFILING=1`, `COR_PROFILER`, Elastic profiler path (see `scripts/Install-ApmProfiler.ps1` / `Configure-ApmPool.ps1`) |
| Service name | `ElasticApm:ServiceName` = `ShipmentsWeb` in `Web.config` (and/or pool env) |
| Auto spans | ASP.NET MVC, SqlClient, HttpClient / HttpWebRequest via profiler + DiagnosticSource |
| Business spans | Fody → `ElasticApmTraceBackend` (default `TraceBackends.Current`) |
| Optional labels | `ApmBusiness.SetCheckoutLabels` in `CheckoutController` |
| Logs | log4net lines include `trace.id` / `transaction.id`; Fleet `lab-app-logs` maps them to ECS |

**What you show**

1. Source: `ShipmentService.cs` / `LegacyShipmentService.vb` — no APM API in bodies.
2. `POST http://34.18.109.143/web/Checkout`
3. APM UI → service **ShipmentsWeb** → transaction `POST Checkout/Index` waterfall:
   - `LegacyShipmentService.EnrichQuoteNote` (+ nested Normalize/Classify)
   - `ShipmentService.CreateQuoteAsync`
   - SQL / outbound HTTP to Tracking
4. Metadata → Labels: `tracking_id`, `lane`, `weight_kg`, `quote_price`
5. Logs tab / Discover: same `trace.id`

Docs: [Profiler auto instrumentation (zero-code)](https://www.elastic.co/docs/reference/apm/agents/dotnet/setup-auto-instrumentation) · [ASP.NET / IIS module](https://www.elastic.co/docs/reference/apm/agents/dotnet/setup-asp-dot-net).


---

## 4. EDOT path — Elastic Distribution of OpenTelemetry (.NET)

**Host:** `TrackingApi` on IIS **TrackingEdotPool** (app path `/tracking`).

| Piece | Contoso wiring |
|---|---|
| Trigger | Pool sets `OTEL_EXPORTER_OTLP_ENDPOINT` (and related `OTEL_*`) |
| Startup | `TrackingApi/Global.asax.cs`: if OTLP endpoint present → `ActivitySourceTraceBackend` + `OpenTelemetrySdk` with `WithElasticDefaults()`, AspNet + SqlClient + `AddSource("Contoso.Observability")` |
| Service name | `OTEL_SERVICE_NAME` → `TrackingApi-EDOT` |
| Auto spans | OpenTelemetry ASP.NET + SqlClient instrumentations |
| Business spans | Same Fody aspects → `ActivitySourceTraceBackend` → OTLP |
| Ingest | `traces-generic.otel-default` (OTel) vs profiler `traces-apm*` |

When OTLP is **not** set, TrackingApi falls back to `ElasticApmTraceBackend` (profiler path).

**What you show**

1. Service inventory: **TrackingApi-EDOT** with `agent.name` ≈ `opentelemetry/dotnet/elastic`
2. Dashboard **Profiler vs EDOT** (`kibana/contoso-profiler-vs-edot-dashboard.json`)
3. Trace for a Tracking GET: AspNet server span + woven business / Internal spans from `Contoso.Observability`

Docs: [EDOT .NET](https://www.elastic.co/docs/reference/opentelemetry/edot-sdks/dotnet) · [Migrate from APM .NET agent](https://www.elastic.co/docs/reference/opentelemetry/edot-sdks/dotnet/migration).


---

## 5. Live demo script (≈15 minutes)

1. **Objection:** “We can’t edit 500 methods / we only have Web.config.”  
   Answer with Layers A/B/C. Host agent = Web.config/IIS. Aspects = business **DLL build**, not every method.
2. **Code:** show `LegacyShipmentService.vb` and `ShipmentService.cs` (untouched bodies) + one `AssemblyInfo` Trace filter each.
3. **Run:** submit Checkout (`lane=DXB-AMM`). Confirm page shows `VB enrich: VB:…`.
4. **APM waterfall (profiler):** `LegacyShipmentService` + `ShipmentService` under Checkout.
5. **Business values:** Labels on the same transaction (Layer C — optional).
6. **Log correlation:** ShipmentsWeb Logs / Discover by `trace.id`.
7. **EDOT contrast:** open TrackingApi-EDOT + Profiler vs EDOT dashboard (same aspect library, different backend).
8. **Ask for one real VB class library** from the customer to tailor `NamespaceFilter` / `TypeNameFilter`.

---

## 6. Customer takeaway (one line)

> Install the agent on the host (Web.config / IIS). Add one shared aspect package to each business DLL build and set assembly filters. Method bodies stay clean — works for C# and VB. Labels and OpenTelemetry are optional next steps.

---

## 7. Lab pointers

| Item | Location |
|---|---|
| Aspect + backends | `src/Contoso.Observability/` |
| C# woven business DLL | `src/Contoso.Shipments.Business/` |
| VB woven business DLL | `src/Contoso.Shipments.LegacyVb/` |
| Profiler web app | `src/ShipmentsWeb/` |
| EDOT web API | `src/TrackingApi/` |
| Build/deploy | `scripts/Build-And-Deploy.ps1` (re-run `Install-EdotTrackingApi.ps1` afterward to keep `/tracking` on `TrackingEdotPool`) |
| Weave verify | `scripts/Verify-AssemblyWeave.ps1`, `scripts/Verify-VbAssemblyWeave.ps1` |

| Comparison dashboard | `kibana/contoso-profiler-vs-edot-dashboard.json` |
| Business values dashboard | `kibana/contoso-business-values-dashboard.json` |
