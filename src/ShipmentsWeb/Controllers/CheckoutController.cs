using System;
using System.Threading.Tasks;
using System.Web.Mvc;
using Contoso.Shipments.Business;
using log4net;
using ShipmentsWeb.Services;

namespace ShipmentsWeb.Controllers
{
    public class CheckoutController : Controller
    {
        private static readonly ILog Log = LogManager.GetLogger(typeof(CheckoutController));
        private readonly ShipmentService _shipments = new ShipmentService();
        private readonly TrackingClient _tracking = new TrackingClient();

        [HttpGet]
        public ActionResult Index()
        {
            return View();
        }

        [HttpPost]
        public async Task<ActionResult> Index(string trackingId, string lane, int weightKg)
        {
            trackingId = string.IsNullOrWhiteSpace(trackingId) ? "CTR-" + Guid.NewGuid().ToString("N").Substring(0, 8) : trackingId;
            lane = string.IsNullOrWhiteSpace(lane) ? "DXB-AMM" : lane;
            if (weightKg <= 0) weightKg = 5;

            Log.InfoFormat("Checkout start trackingId={0} lane={1} weight={2}", trackingId, lane, weightKg);

            // Synthetic failure for SLO burn demos (trackingId prefix SLOBOOM)
            if (trackingId.StartsWith("SLOBOOM", StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException("Synthetic checkout failure for SLO burn");
            }

            var quote = await _shipments.CreateQuoteAsync(trackingId, lane, weightKg).ConfigureAwait(false);
            var viaHttpClient = await _tracking.GetStatusHttpClientAsync(trackingId).ConfigureAwait(false);
            // Distinct id suffix avoids DiagnosticSource conflating back-to-back HttpClient + HttpWebRequest
            // calls to the same URL (which produced 0µs outbound spans / TrackingApi children).
            var viaWebRequest = await _tracking.GetStatusHttpWebRequestAsync(trackingId + "-wr").ConfigureAwait(false);

            ViewBag.Quote = quote;
            ViewBag.HttpClientStatus = viaHttpClient;
            ViewBag.WebRequestStatus = viaWebRequest;
            Log.InfoFormat("Checkout done price={0} chain={1}", quote.Price, quote.ChainToken);
            return View();
        }
    }
}
