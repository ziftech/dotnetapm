using System;
using System.Web;
using System.Web.Http;
using System.Web.Http.ExceptionHandling;
using Contoso.Observability;
using NLog;
using TrackingApi.Filters;

namespace TrackingApi
{
    public class WebApiApplication : HttpApplication
    {
        private static readonly Logger Log = LogManager.GetCurrentClassLogger();

        protected void Application_Start()
        {
            GlobalConfiguration.Configure(WebApiConfig.Register);

            // Tracing backend is selected by Contoso.Observability.TraceBackends from env
            // (OTEL_EXPORTER_OTLP_ENDPOINT / OTEL_DOTNET_AUTO_HOME → ActivitySource).
            // EDOT / OpenTelemetry zero-code is attached via Register-OpenTelemetryForIIS —
            // no OpenTelemetrySdk in this file.
            if (TraceBackends.IsOtelenabled())
            {
                GlobalConfiguration.Configuration.Services.Add(typeof(IExceptionLogger), new OtelExceptionLogger());
                Log.Info("TrackingApi started (EDOT/OTel zero-code path; ActivitySource backend)");
            }
            else
            {
                GlobalConfiguration.Configuration.Services.Add(typeof(IExceptionLogger), new ApmExceptionLogger());
                Log.Info("TrackingApi started (Elastic APM profiler/NuGet path)");
            }
        }

        protected void Application_Error(object sender, EventArgs e)
        {
            var ex = Server.GetLastError();
            if (ex == null) return;
            try
            {
                TraceBackends.Current.CaptureException(ex);
                var activity = System.Diagnostics.Activity.Current;
                if (activity != null)
                {
                    activity.SetTag("error", "true");
                    activity.SetTag("exception.type", ex.GetType().FullName);
                    activity.SetTag("exception.message", ex.Message);
                    activity.SetStatus(System.Diagnostics.ActivityStatusCode.Error, ex.Message);
                }
                Log.Error(ex, "Application_Error");
            }
            catch
            {
            }
        }
    }
}
