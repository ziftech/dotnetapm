using System;
using System.Web;
using System.Web.Http;
using System.Web.Http.ExceptionHandling;
using Contoso.Observability;
using NLog;
using OpenTelemetry;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using TrackingApi.Filters;

namespace TrackingApi
{
    public class WebApiApplication : HttpApplication
    {
        private static readonly Logger Log = LogManager.GetCurrentClassLogger();
        private OpenTelemetrySdk _sdk;

        protected void Application_Start()
        {
            // Fody aspects emit ActivitySource spans for Contoso business methods.
            TraceBackends.Current = new ActivitySourceTraceBackend();

            // Explicit AspNet + SqlClient registration: assembly scanning alone did not
            // produce SERVER spans for this ASP.NET Framework Web API on first deploy.
            _sdk = OpenTelemetrySdk.Create(builder => builder
                .WithElasticDefaults()
                .ConfigureResource(r => r.AddService(
                    serviceName: Environment.GetEnvironmentVariable("OTEL_SERVICE_NAME") ?? "TrackingApi-EDOT",
                    serviceVersion: "s5-edot"))
                .WithTracing(t => t
                    .AddAspNetInstrumentation()
                    .AddSqlClientInstrumentation()
                    .AddSource("Contoso.Observability")));

            GlobalConfiguration.Configure(WebApiConfig.Register);
            GlobalConfiguration.Configuration.Services.Add(typeof(IExceptionLogger), new OtelExceptionLogger());
            Log.Info("TrackingApi started with EDOT OpenTelemetry SDK (explicit AspNet+SqlClient)");
        }

        protected void Application_End()
        {
            _sdk?.Dispose();
        }

        protected void Application_Error(object sender, EventArgs e)
        {
            var ex = Server.GetLastError();
            if (ex == null) return;
            try
            {
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
