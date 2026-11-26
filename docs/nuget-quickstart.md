# Contoso.Observability — NuGet quickstart

Add the package, rebuild, and business methods in your DLLs appear as spans under the IIS (or worker) transaction. Logs can carry trace IDs when you also install the Log4Net or NLog companion package.

**Supportability:** this is a community sample, not an Elastic-supported product. The adopting team owns maintenance, upgrades, and production risk.

**Licence:** MIT.

## Install

**packages.config**

```text
nuget install Contoso.Observability -Version 1.0.0 -Source <your-feed>
```

Ensure Fody / MethodBoundaryAspect build imports are present (the package ships `build/*.props` and `build/*.targets`).

**PackageReference**

```bash
dotnet add package Contoso.Observability --version 1.0.0
```

For IIS apps without source edits to controllers, also install `Contoso.Observability.Web` and register `ApmContextHttpModule` (XDT for packages.config; copy the snippet from that package README for PackageReference).

Companion packages:

- `Contoso.Observability.Log4Net` — `%apm_trace_id` / `%apm_transaction_id` pattern converters
- `Contoso.Observability.NLog` — `${apm-trace-id}` / `${apm-transaction-id}` layout renderers

## MSBuild properties

| Property | Default | Purpose |
|---|---|---|
| `ContosoTraceEnabled` | `true` | Master switch for weaving |
| `ContosoTraceNamespaceFilter` | `^$(RootNamespace)` | Namespace regex |
| `ContosoTraceTypeFilter` | `.` | Type-name regex |
| `ContosoTraceMethodFilter` | excludes getters/setters/ctors/`ToString`/`Equals`/async state machine | Method-name regex |
| `ContosoTraceVisibility` | `Public` | Multicast visibility |
| `ContosoTraceStartTransactions` | `false` | Allow aspect to start root transactions (workers) |
| `ContosoTraceSkipGeneration` | `false` | Skip generated `[assembly: Trace]` if you author it yourself |

Start narrow — for example type filter `.*Service$` — then widen. Elastic APM caps transactions around **500 spans**; broad filters burn that budget quickly.

### Directory.Build.props for many libraries

Place this next to the solution so ~15 class libraries pick up the same filters without per-project edits:

```xml
<Project>
  <PropertyGroup>
    <ContosoTraceEnabled>true</ContosoTraceEnabled>
    <ContosoTraceTypeFilter>.*Service$</ContosoTraceTypeFilter>
    <ContosoTraceVisibility>Public</ContosoTraceVisibility>
    <ContosoTraceStartTransactions>false</ContosoTraceStartTransactions>
  </PropertyGroup>
</Project>
```

## Runtime appSettings

| Key | Purpose |
|---|---|
| `Contoso:Trace:Enabled` | Kill switch without rebuild (`false` disables aspect work) |
| `Contoso:Trace:Exclude` | Regex over `Type.Method` to skip hot methods |
| `Contoso:Labels:PathRegex` | Optional path filter for `ApmContextHttpModule` |
| `Contoso:Labels:<name>` | Label sources: `form:` / `query:` / `header:` / `route:` (`|`-separated; first non-empty wins) |

Example checkout labels (no controller code):

```xml
<add key="Contoso:Labels:PathRegex" value="checkout" />
<add key="Contoso:Labels:tracking_id" value="form:trackingId|query:trackingId" />
<add key="Contoso:Labels:lane" value="form:lane|query:lane" />
<add key="Contoso:Labels:weight_kg" value="form:weightKg|query:weightKg" />
```

## Exclude a hot method

Prefer runtime exclude when you need a quick fix without rebuild:

```xml
<add key="Contoso:Trace:Exclude" value="MyNs\.HotService\.TightLoop" />
```

Or tighten `ContosoTraceMethodFilter` / `ContosoTraceTypeFilter` and rebuild.

## Workers / Windows services

Set `ContosoTraceStartTransactions=true` so the first woven method can start a root transaction when none exists, or call `ApmEntryPoint` once at the process entry method.

## Agent versions

Keep `Elastic.Apm` NuGet aligned with the profiler agent (lab uses **1.34.7**). Pin `System.Diagnostics.DiagnosticSource` to **8.0.1** — 10.x breaks the profiler `BeginRequest` path on .NET Framework.

## Verify locally

```powershell
./scripts/Pack-And-Verify.ps1 -Configuration Release
```

Packs four nupkgs into `./artifacts` and asserts the clean C# / VB / SDK samples weave with zero tracing source in the sample projects.

## CI

The Windows pack/verify workflow lives at [`build/ci.windows.yml`](../build/ci.windows.yml). Copy it to `.github/workflows/ci.yml` in a repo that allows workflow updates (GitHub `workflow` scope). Until then, run locally:

```powershell
./scripts/Pack-And-Verify.ps1 -Configuration Release
```
