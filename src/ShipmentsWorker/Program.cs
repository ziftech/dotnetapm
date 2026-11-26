using System;
using System.Configuration;
using System.Threading;
using Contoso.Observability;
using Contoso.Shipments.Business;

namespace ShipmentsWorker
{
    /// <summary>Non-HTTP entry point (timer loop) for APM transaction demos.</summary>
    internal static class Program
    {
        private static readonly ShipmentService Service = new ShipmentService();

        private static void Main()
        {
            TraceBackends.Current = new ElasticApmTraceBackend();

            var interval = 30;
            int.TryParse(ConfigurationManager.AppSettings["IntervalSeconds"], out interval);
            if (interval < 5) interval = 5;

            Console.WriteLine("ShipmentsWorker starting. Interval={0}s.", interval);
            using (var timer = new Timer(_ => Tick(), null, TimeSpan.Zero, TimeSpan.FromSeconds(interval)))
            {
                var exit = new ManualResetEvent(false);
                Console.CancelKeyPress += (s, e) => { e.Cancel = true; exit.Set(); };
                exit.WaitOne();
            }
        }

        private static void Tick()
        {
            try
            {
                ApmEntryPoint.Run("ShipmentsWorker.Tick", () =>
                {
                    var id = "WRK-" + DateTime.UtcNow.ToString("HHmmss");
                    var quote = Service.CreateQuote(id, "WRK-LANE", 3);
                    Console.WriteLine("{0:o} worker quote {1} price={2}", DateTime.UtcNow, quote.TrackingId, quote.Price);
                });
            }
            catch (Exception ex)
            {
                // Avoid Exception.ToString() — stack formatting can itself throw FileLoadException
                // when DiagnosticSource binding redirects are wrong.
                Console.WriteLine("Worker tick failed: " + ex.GetType().FullName + ": " + ex.Message);
            }
        }
    }
}
