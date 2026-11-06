using System.Web;
using System.Web.Mvc;
using System.Web.Routing;
using log4net;
using log4net.Config;

namespace ShipmentsWeb
{
    public class MvcApplication : HttpApplication
    {
        private static readonly ILog Log = LogManager.GetLogger(typeof(MvcApplication));

        protected void Application_Start()
        {
            XmlConfigurator.Configure();
            AreaRegistration.RegisterAllAreas();
            RouteConfig.RegisterRoutes(RouteTable.Routes);
            Log.Info("ShipmentsWeb started");
        }
    }
}
