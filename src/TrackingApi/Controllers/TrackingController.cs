using System;
using System.Net;
using System.Net.Http;
using System.Web.Http;
using Contoso.Shipments.Business;
using NLog;

namespace TrackingApi.Controllers
{
    public class TrackingController : ApiController
    {
        private static readonly Logger Log = LogManager.GetCurrentClassLogger();
        private static int _requestCount;
        private readonly ShipmentService _shipments = new ShipmentService();

        [HttpGet]
        public HttpResponseMessage Get(string id)
        {
            var n = System.Threading.Interlocked.Increment(ref _requestCount);
            Log.Info("GET tracking id={0} n={1}", id, n);

            if (string.IsNullOrWhiteSpace(id))
            {
                return Request.CreateErrorResponse(HttpStatusCode.BadRequest, "tracking id required");
            }

            if (string.Equals(id, "missing", StringComparison.OrdinalIgnoreCase))
            {
                return Request.CreateErrorResponse(HttpStatusCode.NotFound, "tracking not found");
            }

            if (string.Equals(id, "forbidden", StringComparison.OrdinalIgnoreCase))
            {
                return Request.CreateErrorResponse(HttpStatusCode.Forbidden, "not allowed");
            }

            // Occasional unhandled 500 for error UI demos (~every 17th request or explicit id)
            if (string.Equals(id, "boom", StringComparison.OrdinalIgnoreCase) || n % 17 == 0)
            {
                throw new InvalidOperationException("Synthetic unhandled TrackingApi failure");
            }

            // Keep the handler above Windows/DiagnosticSource timer granularity (~15ms).
            // Faster localhost replies still complete real work, but HttpHandlerDiagnosticListener
            // Start/Stop can land on the same tick and report 0µs client + server durations.
            System.Threading.Thread.Sleep(25);

            var status = _shipments.LookupStatus(id);
            return Request.CreateResponse(HttpStatusCode.OK, new
            {
                trackingId = id,
                status = status,
                serverUtc = DateTime.UtcNow
            });
        }
    }
}
