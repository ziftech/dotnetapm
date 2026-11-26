using System;
using System.Diagnostics;
using System.Threading.Tasks;
using Elastic.Apm;
using Elastic.Apm.Api;

namespace Contoso.Observability
{
    /// <summary>
    /// Starts a root transaction (Elastic APM) or Activity (EDOT) for Windows services / workers
    /// that have no IIS request transaction.
    /// </summary>
    public static class ApmEntryPoint
    {
        private static readonly ActivitySource Source = new ActivitySource("Contoso.Observability");
        private static int _agentTried;

        public static void Run(string name, Action action)
        {
            if (action == null) throw new ArgumentNullException("action");
            if (string.IsNullOrWhiteSpace(name)) name = "Contoso.Entry";

            if (TraceBackends.IsOtelenabled())
            {
                using (var activity = Source.StartActivity(name, ActivityKind.Server))
                {
                    if (activity != null)
                        activity.SetTag("span.type", "app");
                    action();
                }
                return;
            }

            EnsureAgent();
            var tracer = Agent.Tracer;
            if (tracer != null)
            {
                tracer.CaptureTransaction(name, ApiConstants.TypeRequest, action);
                return;
            }

            action();
        }

        public static Task RunAsync(string name, Func<Task> action)
        {
            if (action == null) throw new ArgumentNullException("action");
            if (string.IsNullOrWhiteSpace(name)) name = "Contoso.Entry";

            if (TraceBackends.IsOtelenabled())
            {
                var activity = Source.StartActivity(name, ActivityKind.Server);
                if (activity != null)
                    activity.SetTag("span.type", "app");
                return action().ContinueWith(t =>
                {
                    try
                    {
                        if (t.IsFaulted && t.Exception != null && activity != null)
                        {
                            var ex = t.Exception.GetBaseException();
                            activity.SetTag("error", "true");
                            activity.SetTag("exception.type", ex.GetType().FullName);
                            activity.SetTag("exception.message", ex.Message);
                        }
                    }
                    finally
                    {
                        activity?.Dispose();
                    }
                    return t;
                }, TaskContinuationOptions.ExecuteSynchronously).Unwrap();
            }

            EnsureAgent();
            var tracer = Agent.Tracer;
            if (tracer != null)
                return tracer.CaptureTransaction(name, ApiConstants.TypeRequest, action);

            return action();
        }

        private static void EnsureAgent()
        {
            if (Agent.Tracer != null) return;
            if (System.Threading.Interlocked.Exchange(ref _agentTried, 1) == 1)
                return;

            try
            {
                if (!Agent.IsConfigured)
                    Agent.Setup(new AgentComponents());
            }
            catch
            {
                // Leave Tracer null; callers fall back to uninstrumented execution.
            }
        }
    }
}
