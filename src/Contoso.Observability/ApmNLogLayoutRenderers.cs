using System.Text;
using Elastic.Apm;
using NLog;
using NLog.LayoutRenderers;

namespace Contoso.Observability
{
    /// <summary>
    /// Sync-context APM layout renderers. Elastic.Apm.NLog's renderers are marked
    /// ThreadSafe/ThreadAgnostic which lets NLog evaluate them off the request thread
    /// where Agent.Tracer.CurrentTransaction is null under the profiler.
    /// </summary>
    [LayoutRenderer("ContosoApmTraceId")]
    public sealed class ContosoApmTraceIdLayoutRenderer : LayoutRenderer
    {
        protected override void Append(StringBuilder builder, LogEventInfo logEvent)
        {
            if (!Agent.IsConfigured) return;
            var tx = Agent.Tracer?.CurrentTransaction;
            if (tx != null) builder.Append(tx.TraceId);
        }
    }

    [LayoutRenderer("ContosoApmTransactionId")]
    public sealed class ContosoApmTransactionIdLayoutRenderer : LayoutRenderer
    {
        protected override void Append(StringBuilder builder, LogEventInfo logEvent)
        {
            if (!Agent.IsConfigured) return;
            var tx = Agent.Tracer?.CurrentTransaction;
            if (tx != null) builder.Append(tx.Id);
        }
    }
}
