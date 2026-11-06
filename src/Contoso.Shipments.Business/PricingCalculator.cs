using System;
using System.Threading;
using System.Threading.Tasks;

namespace Contoso.Shipments.Business
{
    // S2-broad: weave public pricing helpers (demonstrates span volume vs narrow Service-only)
    public static class PricingCalculator
    {
        /// <summary>CPU-heavy pricing path used to create visible span/CPU load.</summary>
        public static decimal CalculateHeavy(string lane, int weightKg)
        {
            double acc = weightKg;
            for (var i = 0; i < 2_500_000; i++)
            {
                acc = Math.Sqrt(acc * 1.000001d + (i % 97)) + (lane?.Length ?? 0);
            }
            return Math.Round((decimal)(acc % 5000) + weightKg * 1.25m, 2);
        }

        public static async Task<decimal> CalculateHeavyAsync(string lane, int weightKg)
        {
            return await Task.Run(() => CalculateHeavy(lane, weightKg)).ConfigureAwait(false);
        }

        private static decimal InternalSurcharge(int weightKg)
        {
            return weightKg > 20 ? 12.5m : 0m;
        }

        public static decimal ApplySurcharge(decimal basePrice, int weightKg)
        {
            return basePrice + InternalSurcharge(weightKg);
        }
    }
}
