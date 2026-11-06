# 0 µs HttpWebRequest / HttpClient / TrackingApi durations

## Observation (pre-fix)

Under checkout, each request produced two `GET localhost` outbound spans:

| Path | Stack cue | Typical duration |
|---|---|---|
| `HttpClient.GetAsync` → DiagnosticSource | `HttpHandlerDiagnosticListener` | ~8–20 ms or **0 µs** |
| `HttpWebRequest.GetResponse` (sync) | `TrackingClient.GetStatusHttpWebRequest` | **0 µs** (systematic) |

Matching TrackingApi child transactions (and often `ShipmentService.LookupStatus`) mirrored the client duration, including **0 µs** for the sync WebRequest call.

## Causes

1. **Sync `HttpWebRequest.GetResponse()`** on .NET Framework: `System.Diagnostics.HttpHandlerDiagnosticListener` Start/Stop correlation yields `span.duration.us = 0` even though a real HTTP round-trip and TrackingApi transaction occur.
2. **Timer granularity on fast localhost**: even after switching to async, very fast same-machine replies can still land Start/Stop on the same tick, so one of the two outbound legs (and the matching TrackingApi tx) intermittently reports **0 µs**. Non-zero samples often cluster near Windows timer quanta (~15.6 ms).

## Fixes applied

1. `TrackingClient.GetStatusHttpWebRequestAsync` uses `GetResponseAsync()` (still HttpWebRequest).
2. Checkout calls the WebRequest leg with a distinct id suffix (`trackingId + "-wr"`) so the two outbound URLs differ.
3. `TrackingController.Get` adds `Thread.Sleep(25)` so handler work exceeds DiagnosticSource timer granularity on localhost (lab-only).

## Post-fix verification (narrow weave, Asia/Dubai evening of 2026-11-06)

Sample clean trace `b0ab8ed422b9f48703de78c3cc0a9790`:

| Leg | Client `GET localhost` | TrackingApi `GET tracking {id}` |
|---|---|---|
| HttpClient | 41,098 µs | 41,098 µs |
| HttpWebRequest (async) | 50,714 µs | 50,714 µs |

Across post-delay FIX-* checkouts: HTTP spans ≈ all non-zero (~31–78 ms); TrackingApi children match.

## ApplicationNamespaces / `library_frame`

Configured both ways:

- Web.config: `ElasticApm:ApplicationNamespaces=Contoso.`
- Pool env: `ELASTIC_APM_APPLICATION_NAMESPACES=Contoso.`
- Also: `ELASTIC_APM_SPAN_STACK_TRACE_MIN_DURATION=0ms` (so short spans still get stacks)

**Result:** Contoso frames **are present** on the WAITFOR stack (`classname=Contoso.Shipments.Business.ShipmentRepository`, `function=RunSlowQuery`, `module=Contoso.Shipments.Business`). However, **`library_frame` is `null` for every frame** (Contoso, `System.Data`, and `Elastic.Apm` alike).

Per [APM .NET stacktrace config](https://www.elastic.co/docs/reference/apm/agents/dotnet/config-stacktrace), `ApplicationNamespaces` is primarily used when determining the **error culprit** (and suppresses `ExcludedNamespaces` for that purpose). It does **not** reliably populate `library_frame: false` on profiler ADO.NET span stack frames in this agent build (1.34.x). Kibana’s Stack Trace tab therefore shows Contoso’s `RunSlowQuery` without a distinct “application vs library” badge; the profiler also records `filename` as `mscorlib.dll` for that frame even though `classname`/`module` correctly name Contoso.

## Screenshots

- `screenshots/11-checkout-trace-waterfall-last-15m.png` — narrow `ShipmentService.*` + WAITFOR SQL + dual TrackingApi children (non-zero HTTP)
- `screenshots/12-slow-sql-span-stacktrace-last-15m.png` — WAITFOR Stack Trace with `RunSlowQuery` visible
