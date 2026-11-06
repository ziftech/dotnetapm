using System;
using System.Configuration;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Threading.Tasks;
using log4net;

namespace ShipmentsWeb.Services
{
    public class TrackingClient
    {
        private static readonly ILog Log = LogManager.GetLogger(typeof(TrackingClient));
        private static readonly HttpClient Http = new HttpClient();

        private readonly string _baseUrl;

        public TrackingClient()
        {
            _baseUrl = (ConfigurationManager.AppSettings["TrackingApiBaseUrl"] ?? "http://localhost/tracking")
                .TrimEnd('/');
        }

        public async Task<string> GetStatusHttpClientAsync(string trackingId)
        {
            var url = _baseUrl + "/api/tracking/" + Uri.EscapeDataString(trackingId ?? string.Empty);
            try
            {
                var response = await Http.GetAsync(url).ConfigureAwait(false);
                var body = await response.Content.ReadAsStringAsync().ConfigureAwait(false);
                Log.InfoFormat("HttpClient status={0}", (int)response.StatusCode);
                return ((int)response.StatusCode) + " " + body;
            }
            catch (Exception ex)
            {
                Log.Warn("HttpClient call failed: " + ex.Message);
                return "ERR " + ex.Message;
            }
        }

        /// <summary>
        /// HttpWebRequest path for outbound instrumentation demos.
        /// Must use GetResponseAsync: sync GetResponse() on .NET Framework makes
        /// System.Net.HttpHandlerDiagnosticListener emit Start/Stop with 0µs duration
        /// (and a matching 0µs TrackingApi child transaction).
        /// </summary>
        public async Task<string> GetStatusHttpWebRequestAsync(string trackingId)
        {
            var url = _baseUrl + "/api/tracking/" + Uri.EscapeDataString(trackingId ?? string.Empty);
            try
            {
                var request = (HttpWebRequest)WebRequest.Create(url);
                request.Method = "GET";
                request.Timeout = 15000;
                using (var response = (HttpWebResponse)await request.GetResponseAsync().ConfigureAwait(false))
                using (var stream = response.GetResponseStream())
                using (var reader = new StreamReader(stream ?? Stream.Null))
                {
                    var body = await reader.ReadToEndAsync().ConfigureAwait(false);
                    Log.InfoFormat("HttpWebRequest status={0}", (int)response.StatusCode);
                    return ((int)response.StatusCode) + " " + body;
                }
            }
            catch (WebException wex)
            {
                var http = wex.Response as HttpWebResponse;
                if (http != null)
                {
                    using (var stream = http.GetResponseStream())
                    using (var reader = new StreamReader(stream ?? Stream.Null))
                    {
                        var body = reader.ReadToEnd();
                        return ((int)http.StatusCode) + " " + body;
                    }
                }
                Log.Warn("HttpWebRequest failed: " + wex.Message);
                return "ERR " + wex.Message;
            }
        }
    }
}
