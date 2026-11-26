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
            var activity = Activity.Current;
            activity.SetStatus(ActivityStatusCode.Error, exception.Message);
            activity.AddEvent(new ActivityEvent(
                "exception",
                tags: new ActivityTagsCollection
                {
                    { "exception.type", exception.GetType().FullName },
                    { "exception.message", exception.Message },
                    { "exception.stacktrace", exception.StackTrace ?? string.Empty }
                }));
        }

        public void SetLabel(string key, string value)
        {
            if (Activity.Current == null || string.IsNullOrEmpty(key) || value == null) return;
            Activity.Current.SetTag(key, value);
        }

        private sealed class Noop : IDisposable
        {
            public static readonly Noop Instance = new Noop();
            public void Dispose() { }
        }
    }
}
