using System.Diagnostics;
using Elastic.Apm;

namespace Contoso.Observability
{
    /// <summary>
    /// Attach Contoso business fields to the active APM transaction and/or Activity (EDOT).
    /// Labels appear on the transaction Metadata → Labels in Kibana APM.
    /// </summary>
    public static class ApmBusiness
    {
        public static void SetCheckoutLabels(string trackingId, string lane, int weightKg, double? quotePrice = null)
        {
            var tx = Agent.IsConfigured ? Agent.Tracer?.CurrentTransaction : null;
            if (tx != null)
            {
                if (!string.IsNullOrEmpty(trackingId)) tx.SetLabel("tracking_id", trackingId);
                if (!string.IsNullOrEmpty(lane)) tx.SetLabel("lane", lane);
                tx.SetLabel("weight_kg", weightKg);
                if (quotePrice.HasValue) tx.SetLabel("quote_price", quotePrice.Value);
            }

            var activity = Activity.Current;
            if (activity != null)
            {
                if (!string.IsNullOrEmpty(trackingId)) activity.SetTag("tracking_id", trackingId);
                if (!string.IsNullOrEmpty(lane)) activity.SetTag("lane", lane);
                activity.SetTag("weight_kg", weightKg);
                if (quotePrice.HasValue) activity.SetTag("quote_price", quotePrice.Value);
            }
        }

        public static void SetTrackingLabels(string trackingId, string status = null)
        {
            var tx = Agent.IsConfigured ? Agent.Tracer?.CurrentTransaction : null;
            if (tx != null)
            {
                if (!string.IsNullOrEmpty(trackingId)) tx.SetLabel("tracking_id", trackingId);
                if (!string.IsNullOrEmpty(status)) tx.SetLabel("shipment_status", status);
            }

            var activity = Activity.Current;
            if (activity != null)
            {
                if (!string.IsNullOrEmpty(trackingId)) activity.SetTag("tracking_id", trackingId);
                if (!string.IsNullOrEmpty(status)) activity.SetTag("shipment_status", status);
            }
        }

        public static string CurrentTraceId()
        {
            if (Agent.IsConfigured)
            {
                var id = Agent.Tracer?.CurrentTransaction?.TraceId;
                if (!string.IsNullOrEmpty(id)) return id;
            }
            var activity = Activity.Current;
            return activity != null ? activity.TraceId.ToHexString() : string.Empty;
        }

        public static string CurrentTransactionOrSpanId()
        {
            if (Agent.IsConfigured)
            {
                var id = Agent.Tracer?.CurrentTransaction?.Id;
                if (!string.IsNullOrEmpty(id)) return id;
            }
            var activity = Activity.Current;
            return activity != null ? activity.SpanId.ToHexString() : string.Empty;
        }
    }
}
