using System.Web.Mvc;
using Elastic.Apm;

namespace ShipmentsWeb.Filters
{
    /// <summary>S1: capture handled MVC exceptions into the active APM transaction.</summary>
    public sealed class ApmExceptionFilter : IExceptionFilter
    {
        public void OnException(ExceptionContext filterContext)
        {
            if (filterContext?.Exception == null) return;
            try
            {
                var tx = Agent.Tracer?.CurrentTransaction;
                tx?.CaptureException(filterContext.Exception);
                Agent.Tracer?.CurrentSpan?.CaptureException(filterContext.Exception);
            }
            catch
            {
                // never break the app for observability
            }
        }
    }
}
