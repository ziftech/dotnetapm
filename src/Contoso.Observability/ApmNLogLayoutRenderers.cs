using System.Text;
using NLog;
using NLog.LayoutRenderers;

namespace Contoso.Observability
{
    /// <summary>
    /// Sync-context APM layout renderers. Elastic.Apm.NLog's renderers are marked
    /// ThreadSafe/ThreadAgnostic which lets NLog evaluate them off the request thread
    /// where Agent.Tracer.CurrentTransaction is null under the profiler.
    /// Falls back to Activity.Current so EDOT / OpenTelemetry traces still correlate.
    /// </summary>
    [LayoutRenderer("ContosoApmTraceId")]
    public sealed class ContosoApmTraceIdLayoutRenderer : LayoutRenderer
    {
        protected override void Append(StringBuilder builder, LogEventInfo logEvent)
        {
            var id = ApmBusiness.CurrentTraceId();
            if (!string.IsNullOrEmpty(id)) builder.Append(id);
        }
    }

    [LayoutRenderer("ContosoApmTransactionId")]
    public sealed class ContosoApmTransactionIdLayoutRenderer : LayoutRenderer
    {
        protected override void Append(StringBuilder builder, LogEventInfo logEvent)
        {
            var id = ApmBusiness.CurrentTransactionOrSpanId();
            if (!string.IsNullOrEmpty(id)) builder.Append(id);
        }
    }
}
