using System.Threading;
using System.Threading.Tasks;
using System.Web.Http.ExceptionHandling;
using Contoso.Observability;

namespace TrackingApi.Filters
{
    /// <summary>Capture Web API exceptions into the active Contoso trace backend (Elastic APM when profiler is on).</summary>
    public sealed class ApmExceptionLogger : ExceptionLogger
    {
        public override void Log(ExceptionLoggerContext context)
        {
            Capture(context);
        }

        public override Task LogAsync(ExceptionLoggerContext context, CancellationToken cancellationToken)
        {
            Capture(context);
            return Task.CompletedTask;
        }

        private static void Capture(ExceptionLoggerContext context)
        {
            if (context?.Exception == null) return;
            try
            {
                TraceBackends.Current.CaptureException(context.Exception);
            }
            catch
            {
            }
        }
    }
}
