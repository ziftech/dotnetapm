using System.Threading;
using System.Threading.Tasks;
using System.Web.Http.ExceptionHandling;
using Elastic.Apm;

namespace TrackingApi.Filters
{
    /// <summary>S1: capture Web API exceptions (including handled filter path) into APM.</summary>
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
                Agent.Tracer?.CurrentTransaction?.CaptureException(context.Exception);
                Agent.Tracer?.CurrentSpan?.CaptureException(context.Exception);
            }
            catch
            {
            }
        }
    }
}
