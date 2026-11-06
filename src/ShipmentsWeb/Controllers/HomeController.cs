using System.Web.Mvc;
using log4net;

namespace ShipmentsWeb.Controllers
{
    public class HomeController : Controller
    {
        private static readonly ILog Log = LogManager.GetLogger(typeof(HomeController));

        public ActionResult Index()
        {
            Log.Info("Home/Index");
            ViewBag.Message = "Contoso Shipments (synthetic lab)";
            return View();
        }
    }
}
