using System;
using System.Diagnostics;

namespace Contoso.Observability
{
    /// <summary>EDOT / OpenTelemetry-friendly backend using ActivitySource.</summary>
    public sealed class ActivitySourceTraceBackend : ITraceBackend
    {
        private static readonly ActivitySource Source = new ActivitySource("Contoso.Observability");

        public IDisposable StartSpanOrTransaction(string name, string type, string subtype)
        {
            var activity = Source.StartActivity(name, ActivityKind.Internal);
            if (activity != null)
            {
                activity.SetTag("span.type", type);
                activity.SetTag("span.subtype", subtype);
            }
            return activity ?? (IDisposable)Noop.Instance;
        }

        public void CaptureException(Exception exception)
        {
            if (Activity.Current == null || exception == null) return;
            Activity.Current.SetTag("error", "true");
            Activity.Current.SetTag("exception.type", exception.GetType().FullName);
            Activity.Current.SetTag("exception.message", exception.Message);
        }

        private sealed class Noop : IDisposable
        {
            public static readonly Noop Instance = new Noop();
            public void Dispose() { }
        }
    }
}
