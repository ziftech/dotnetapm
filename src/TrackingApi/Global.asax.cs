using System;
using System.Web;
using System.Web.Http;
using System.Web.Http.ExceptionHandling;
using Elastic.Apm;
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
            GlobalConfiguration.Configuration.Services.Add(typeof(IExceptionLogger), new ApmExceptionLogger());
            Log.Info("TrackingApi started");
        }

        protected void Application_Error(object sender, EventArgs e)
        {
            var ex = Server.GetLastError();
            if (ex == null) return;
            try
            {
                Agent.Tracer?.CurrentTransaction?.CaptureException(ex);
                Log.Error(ex, "Application_Error");
            }
            catch
            {
            }
        }
    }
}
