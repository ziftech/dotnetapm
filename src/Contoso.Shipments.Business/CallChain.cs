using System;

namespace Contoso.Shipments.Business
{
    /// <summary>Deep internal call chain (10+ frames) for stack-trace demos.
    /// Broad weave: public steps produce many short app spans (span-budget demo).</summary>
    public static class CallChain
    {
        public static string RunDeep(string trackingId)
        {
            return Step01(trackingId);
        }

        public static string Step01(string id) { return Step02(id); }
        public static string Step02(string id) { return Step03(id); }
        public static string Step03(string id) { return Step04(id); }
        public static string Step04(string id) { return Step05(id); }
        public static string Step05(string id) { return Step06(id); }
        public static string Step06(string id) { return Step07(id); }
        public static string Step07(string id) { return Step08(id); }
        public static string Step08(string id) { return Step09(id); }
        public static string Step09(string id) { return Step10(id); }
        public static string Step10(string id) { return Step11(id); }
        public static string Step11(string id) { return Step12(id); }

        public static string Step12(string id)
        {
            return "CHAIN-" + (id ?? "UNKNOWN") + "-" + DateTime.UtcNow.Ticks;
        }
    }
}
