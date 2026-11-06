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
        public static ITraceBackend Current { get; set; } = new ElasticApmTraceBackend();
    }
}
