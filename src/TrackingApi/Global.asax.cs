using System.Web;
using System.Web.Http;
using NLog;

namespace TrackingApi
{
    public class WebApiApplication : HttpApplication
    {
        private static readonly Logger Log = LogManager.GetCurrentClassLogger();

        protected void Application_Start()
        {
            GlobalConfiguration.Configure(WebApiConfig.Register);
            Log.Info("TrackingApi started");
        }
    }
}
