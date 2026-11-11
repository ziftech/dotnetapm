using System;
using System.Threading.Tasks;
using System.Web.Mvc;
using Contoso.Observability;
using Contoso.Shipments.Business;
using Contoso.Shipments.LegacyVb;
using log4net;
using ShipmentsWeb.Services;


namespace ShipmentsWeb.Controllers
{
    public class CheckoutController : Controller
    {
        private static readonly ILog Log = LogManager.GetLogger(typeof(CheckoutController));
        private readonly ShipmentService _shipments = new ShipmentService();
        private readonly LegacyShipmentService _legacyVb = new LegacyShipmentService();
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

            // Business values → APM labels (Metadata → Labels) for filtering / demo
            ApmBusiness.SetCheckoutLabels(trackingId, lane, weightKg);

            Log.InfoFormat(
                "Checkout start trackingId={0} lane={1} weight={2} trace.id={3} transaction.id={4}",
                trackingId, lane, weightKg, ApmBusiness.CurrentTraceId(), ApmBusiness.CurrentTransactionOrSpanId());

            // Synthetic failure for SLO burn demos (trackingId prefix SLOBOOM)
            if (trackingId.StartsWith("SLOBOOM", StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException("Synthetic checkout failure for SLO burn");
            }

            // VB class library (Fody-woven) — proves aspects work without C# / without per-method APM code.
            var vbNote = _legacyVb.EnrichQuoteNote(trackingId, lane, weightKg);

            var quote = await _shipments.CreateQuoteAsync(trackingId, lane, weightKg).ConfigureAwait(false);
            ApmBusiness.SetCheckoutLabels(trackingId, lane, weightKg, (double)quote.Price);

            var viaHttpClient = await _tracking.GetStatusHttpClientAsync(trackingId).ConfigureAwait(false);

            // Distinct id suffix avoids DiagnosticSource conflating back-to-back HttpClient + HttpWebRequest
            // calls to the same URL (which produced 0µs outbound spans / TrackingApi children).
            var viaWebRequest = await _tracking.GetStatusHttpWebRequestAsync(trackingId + "-wr").ConfigureAwait(false);

            ViewBag.Quote = quote;
            ViewBag.VbNote = vbNote;
            ViewBag.HttpClientStatus = viaHttpClient;
            ViewBag.WebRequestStatus = viaWebRequest;
            Log.InfoFormat(
                "Checkout done price={0} chain={1} vbNote={2} trackingId={3} trace.id={4}",
                quote.Price, quote.ChainToken, vbNote, trackingId, ApmBusiness.CurrentTraceId());
            return View();
        }
    }
}
