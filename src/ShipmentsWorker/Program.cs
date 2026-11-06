using System;
using System.Configuration;
using System.Threading;
using Contoso.Observability;
using Contoso.Shipments.Business;
using Elastic.Apm;

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

            Console.WriteLine("ShipmentsWorker starting. Interval={0}s. Agent configured={1}", interval, Agent.Config != null);
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
                var id = "WRK-" + DateTime.UtcNow.ToString("HHmmss");
                // Fody [Trace] on ShipmentService starts a transaction when none is active
                var quote = Service.CreateQuote(id, "WRK-LANE", 3);
                Console.WriteLine("{0:o} worker quote {1} price={2}", DateTime.UtcNow, quote.TrackingId, quote.Price);
            }
            catch (Exception ex)
            {
                Console.WriteLine("Worker tick failed: " + ex.Message);
            }
        }
    }
}
