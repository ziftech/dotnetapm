using System;
using System.Threading.Tasks;

namespace Contoso.Observability
{
    /// <summary>Helpers for ending spans after async Task completion.</summary>
    public static class TraceScope
    {
        public static void CompleteAsync(IDisposable scope, Task task, Exception syncException)
        {
            if (syncException != null)
            {
                TraceBackends.Current.CaptureException(syncException);
                scope?.Dispose();
                return;
            }

            if (task == null)
            {
                scope?.Dispose();
                return;
            }

            task.ContinueWith(t =>
            {
                try
                {
                    if (t.IsFaulted && t.Exception != null)
                    {
                        TraceBackends.Current.CaptureException(t.Exception.GetBaseException());
                    }
                }
                finally
                {
                    scope?.Dispose();
                }
            }, TaskContinuationOptions.ExecuteSynchronously);
        }
    }
}
