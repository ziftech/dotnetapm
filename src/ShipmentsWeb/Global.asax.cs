using System;
using System.Web;
using System.Web.Mvc;
using System.Web.Routing;
using Elastic.Apm;
using log4net;
using log4net.Config;
using ShipmentsWeb.Filters;

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
            GlobalFilters.Filters.Add(new ApmExceptionFilter());
            GlobalFilters.Filters.Add(new HandleErrorAttribute());
            Log.Info("ShipmentsWeb started");
        }

        protected void Application_Error(object sender, EventArgs e)
        {
            var ex = Server.GetLastError();
            if (ex == null) return;
            try
            {
                Agent.Tracer?.CurrentTransaction?.CaptureException(ex);
                Log.Error("Application_Error", ex);
            }
            catch
            {
            }
        }
    }
}
