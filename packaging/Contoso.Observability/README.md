# Contoso.Observability

Adds build-time business-method spans to .NET Framework class libraries (C# / VB).

## Install

**packages.config:** `nuget install Contoso.Observability -Source <feed>`

**PackageReference:** `dotnet add package Contoso.Observability`

## MSBuild properties

| Property | Default | Purpose |
|---|---|---|
| `ContosoTraceEnabled` | `true` | Master switch for weaving |
| `ContosoTraceNamespaceFilter` | `^$(RootNamespace)` | Namespace regex |
| `ContosoTraceTypeFilter` | `.` | Type-name regex |
| `ContosoTraceMethodFilter` | excludes getters/setters/ctors/`ToString`/`Equals`/async state machine | Method-name regex |
| `ContosoTraceVisibility` | `Public` | `MulticastAttributes` value |
| `ContosoTraceStartTransactions` | `false` | Allow aspect to start root txs (workers) |
| `ContosoTraceSkipGeneration` | `false` | Skip generated `[assembly: Trace]` if you author it yourself |

## Runtime appSettings

- `Contoso:Trace:Enabled` — kill switch without rebuild
- `Contoso:Trace:Exclude` — regex over `Type.Method`

## Supportability

Community sample owned by the adopting team — not an Elastic-supported product.
