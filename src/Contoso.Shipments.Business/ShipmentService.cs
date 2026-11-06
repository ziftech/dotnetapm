using System;
using System.Threading.Tasks;
using Contoso.Observability;

namespace Contoso.Shipments.Business
{
    [Trace]
    public class ShipmentService
    {
        private readonly ShipmentRepository _repository;

        public ShipmentService() : this(new ShipmentRepository())
        {
        }

        public ShipmentService(ShipmentRepository repository)
        {
            _repository = repository;
        }

        public ShipmentQuote CreateQuote(string trackingId, string lane, int weightKg)
        {
            try
            {
                MaybeSwallowHandledException(trackingId);
            }
            catch (Exception)
            {
                // Handled/swallowed on purpose for Phase 3 error-visibility demos
            }

            var chainToken = CallChain.RunDeep(trackingId);
            var price = PricingCalculator.CalculateHeavy(lane, weightKg);
            price = PricingCalculator.ApplySurcharge(price, weightKg);
            _repository.UpsertSample(trackingId, lane, weightKg);

            if (string.Equals(lane, "SLOW", StringComparison.OrdinalIgnoreCase))
            {
                _repository.RunSlowQuery(2);
            }

            return new ShipmentQuote
            {
                TrackingId = trackingId,
                Lane = lane,
                WeightKg = weightKg,
                Price = price,
                ChainToken = chainToken
            };
        }

        public async Task<ShipmentQuote> CreateQuoteAsync(string trackingId, string lane, int weightKg)
        {
            var chainToken = CallChain.RunDeep(trackingId);
            var price = await PricingCalculator.CalculateHeavyAsync(lane, weightKg).ConfigureAwait(false);
            price = PricingCalculator.ApplySurcharge(price, weightKg);
            await Task.Run(() => _repository.UpsertSample(trackingId, lane, weightKg)).ConfigureAwait(false);
            if (string.Equals(lane, "SLOW", StringComparison.OrdinalIgnoreCase))
            {
                await _repository.RunSlowQueryAsync(2).ConfigureAwait(false);
            }
            return new ShipmentQuote
            {
                TrackingId = trackingId,
                Lane = lane,
                WeightKg = weightKg,
                Price = price,
                ChainToken = chainToken
            };
        }

        public string LookupStatus(string trackingId)
        {
            var table = _repository.GetShipment(trackingId);
            if (table.Rows.Count == 0) return "Unknown";
            return Convert.ToString(table.Rows[0]["Status"]) ?? "Unknown";
        }

        private static void MaybeSwallowHandledException(string trackingId)
        {
            if (trackingId != null && trackingId.IndexOf("THROW", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                try
                {
                    throw new InvalidOperationException("Synthetic handled business exception for Contoso lab");
                }
                catch (InvalidOperationException ex)
                {
                    System.Diagnostics.Trace.WriteLine("Swallowed: " + ex.Message);
                    // Intentionally not rethrown
                }
            }
        }
    }

    public class ShipmentQuote
    {
        public string TrackingId { get; set; }
        public string Lane { get; set; }
        public int WeightKg { get; set; }
        public decimal Price { get; set; }
        public string ChainToken { get; set; }
    }
}
