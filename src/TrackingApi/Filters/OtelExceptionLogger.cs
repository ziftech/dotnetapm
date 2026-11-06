using System.Diagnostics;
using System.Threading;
// Activity lives in System.Diagnostics.DiagnosticSource on .NET Framework
using System.Threading.Tasks;
using System.Web.Http.ExceptionHandling;

namespace TrackingApi.Filters
{
    /// <summary>S5: capture Web API exceptions onto the current Activity (EDOT/OTel).</summary>
    public sealed class OtelExceptionLogger : ExceptionLogger
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
                var activity = Activity.Current;
                if (activity == null) return;
                activity.SetTag("error", "true");
                activity.SetTag("exception.type", context.Exception.GetType().FullName);
                activity.SetTag("exception.message", context.Exception.Message);
                activity.SetStatus(ActivityStatusCode.Error, context.Exception.Message);
            }
            catch
            {
            }
        }
    }
}
