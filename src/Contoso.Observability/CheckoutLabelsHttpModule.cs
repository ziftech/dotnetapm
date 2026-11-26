using System;
using System.Globalization;
using System.Web;

namespace Contoso.Observability
{
    /// <summary>
    /// Sets Contoso checkout business labels from the HTTP request (and optional
    /// HttpContext.Items["quote_price"]) without touching Global.asax or controllers.
    /// Register only in Web.config under system.webServer/modules.
    /// </summary>
    public sealed class CheckoutLabelsHttpModule : IHttpModule
    {
        public const string QuotePriceItemKey = "quote_price";

        public void Init(HttpApplication context)
        {
            context.PostAcquireRequestState += OnPostAcquireRequestState;
            context.PreSendRequestContent += OnPreSendRequestContent;
        }

        private static void OnPostAcquireRequestState(object sender, EventArgs e)
        {
            var app = sender as HttpApplication;
            var request = app?.Context?.Request;
            if (request == null) return;
            if (!IsCheckoutPost(request)) return;

            var trackingId = FirstNonEmpty(request, "trackingId");
            var lane = FirstNonEmpty(request, "lane");
            var weightRaw = FirstNonEmpty(request, "weightKg");
            var weightKg = 0;
            if (!string.IsNullOrEmpty(weightRaw))
                int.TryParse(weightRaw, NumberStyles.Integer, CultureInfo.InvariantCulture, out weightKg);

            ApmBusiness.SetCheckoutLabels(trackingId, lane, weightKg);
        }

        private static void OnPreSendRequestContent(object sender, EventArgs e)
        {
            var app = sender as HttpApplication;
            var ctx = app?.Context;
            if (ctx == null) return;
            if (!IsCheckoutPost(ctx.Request)) return;

            var trackingId = FirstNonEmpty(ctx.Request, "trackingId");
            var lane = FirstNonEmpty(ctx.Request, "lane");
            var weightRaw = FirstNonEmpty(ctx.Request, "weightKg");
            var weightKg = 0;
            if (!string.IsNullOrEmpty(weightRaw))
                int.TryParse(weightRaw, NumberStyles.Integer, CultureInfo.InvariantCulture, out weightKg);

            double? quote = null;
            var item = ctx.Items[QuotePriceItemKey];
            if (item != null)
            {
                try { quote = Convert.ToDouble(item, CultureInfo.InvariantCulture); }
                catch { /* ignore */ }
            }

            ApmBusiness.SetCheckoutLabels(trackingId, lane, weightKg, quote);
        }

        private static bool IsCheckoutPost(HttpRequest request)
        {
            if (request == null) return false;
            if (!string.Equals(request.HttpMethod, "POST", StringComparison.OrdinalIgnoreCase)) return false;
            var path = (request.AppRelativeCurrentExecutionFilePath ?? request.Path ?? string.Empty).ToLowerInvariant();
            return path.IndexOf("checkout", StringComparison.OrdinalIgnoreCase) >= 0;
        }

        private static string FirstNonEmpty(HttpRequest request, string key)
        {
            try
            {
                var form = request.Form[key];
                if (!string.IsNullOrWhiteSpace(form)) return form.Trim();
            }
            catch
            {
                // Form may throw if request body is unavailable; fall through.
            }

            var qs = request.QueryString[key];
            return string.IsNullOrWhiteSpace(qs) ? null : qs.Trim();
        }

        public void Dispose()
        {
        }
    }
}
