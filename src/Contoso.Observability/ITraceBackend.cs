using System;

namespace Contoso.Observability
{
    /// <summary>Thin backend so the Fody aspect can target Elastic APM or ActivitySource/EDOT.</summary>
    public interface ITraceBackend
    {
        IDisposable StartSpanOrTransaction(string name, string type, string subtype);
        void CaptureException(Exception exception);
    }

    public static class TraceBackends
    {
        /// <summary>
        /// Default backend. When OTEL exporter / auto-instrumentation env is present,
        /// use ActivitySource so zero-code EDOT can pick up Contoso.Observability spans
        /// via OTEL_DOTNET_AUTO_TRACES_ADDITIONAL_SOURCES — no Global.asax SDK required.
        /// </summary>
        public static ITraceBackend Current { get; set; } = CreateDefault();

        public static ITraceBackend CreateDefault()
        {
            if (IsOtelenabled())
                return new ActivitySourceTraceBackend();
            return new ElasticApmTraceBackend();
        }

        public static bool IsOtelenabled()
        {
            return !string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("OTEL_EXPORTER_OTLP_ENDPOINT"))
                || !string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("OTEL_DOTNET_AUTO_HOME"));
        }
    }
}
