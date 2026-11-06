using System;
using System.Configuration;
using System.Reflection;
using System.Threading;
using Contoso.Observability;
using Contoso.Shipments.Business;
using Elastic.Apm;
using Elastic.Apm.Api;

namespace ShipmentsWorker
{
    /// <summary>Non-HTTP entry point (timer loop) for APM transaction demos.</summary>
    internal static class Program
    {
        private static readonly ShipmentService Service = new ShipmentService();

        private static void Main()
        {
            // Setup MUST run before any Contoso.Observability touch of Agent.
            EnsureAgent();
            TraceBackends.Current = new ElasticApmTraceBackend();

            var interval = 30;
            int.TryParse(ConfigurationManager.AppSettings["IntervalSeconds"], out interval);
            if (interval < 5) interval = 5;

            Console.WriteLine("ShipmentsWorker starting. Interval={0}s. configured={1} tracerNull={2} server={3}",
                interval, Agent.IsConfigured, Agent.Tracer == null,
                Environment.GetEnvironmentVariable("ELASTIC_APM_SERVER_URL"));
            using (var timer = new Timer(_ => Tick(), null, TimeSpan.Zero, TimeSpan.FromSeconds(interval)))
            {
                var exit = new ManualResetEvent(false);
                Console.CancelKeyPress += (s, e) => { e.Cancel = true; exit.Set(); };
                exit.WaitOne();
            }
        }

        private static void EnsureAgent()
        {
            Console.WriteLine("pre-setup IsConfigured={0} TracerNull={1}", Agent.IsConfigured, Agent.Tracer == null);
            if (Agent.Tracer != null) return;

            if (Agent.IsConfigured)
            {
                // Clear a half-initialized Agent (IsConfigured without Tracer) via reflection.
                try
                {
                    var componentsField = typeof(Agent).GetField("Components", BindingFlags.Static | BindingFlags.NonPublic | BindingFlags.Public)
                        ?? typeof(Agent).GetField("_components", BindingFlags.Static | BindingFlags.NonPublic | BindingFlags.Public);
                    if (componentsField != null)
                    {
                        componentsField.SetValue(null, null);
                        Console.WriteLine("cleared Agent components via {0}", componentsField.Name);
                    }
                    else
                    {
                        foreach (var f in typeof(Agent).GetFields(BindingFlags.Static | BindingFlags.NonPublic | BindingFlags.Public))
                            Console.WriteLine("Agent field {0} type={1} valNull={2}", f.Name, f.FieldType.Name, f.GetValue(null) == null);
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine("reflection clear failed: " + ex.Message);
                }
            }

            try
            {
                Agent.Setup(new AgentComponents());
                Console.WriteLine("Agent.Setup done. TracerNull={0}", Agent.Tracer == null);
            }
            catch (Exception ex)
            {
                Console.WriteLine("Agent.Setup failed: " + ex);
            }
        }

        private static void Tick()
        {
            try
            {
                var id = "WRK-" + DateTime.UtcNow.ToString("HHmmss");
                var tracer = Agent.Tracer;
                if (tracer == null)
                {
                    Console.WriteLine("Agent.Tracer still null; quote without APM");
                    var quoteFallback = Service.CreateQuote(id, "WRK-LANE", 3);
                    Console.WriteLine("{0:o} worker quote {1} price={2}", DateTime.UtcNow, quoteFallback.TrackingId, quoteFallback.Price);
                    return;
                }
                tracer.CaptureTransaction("ShipmentsWorker.Tick", ApiConstants.TypeRequest, () =>
                {
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
