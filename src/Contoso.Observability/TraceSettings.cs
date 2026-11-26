using System;
using System.Configuration;
using System.Text.RegularExpressions;
using System.Threading;

namespace Contoso.Observability
{
    /// <summary>
    /// Runtime knobs from appSettings, read once (lazy, thread-safe).
    /// Contoso:Trace:Enabled — kill switch (default true).
    /// Contoso:Trace:Exclude — regex over "Type.Method".
    /// </summary>
    public static class TraceSettings
    {
        private static readonly Lazy<State> Cached = new Lazy<State>(Load, LazyThreadSafetyMode.ExecutionAndPublication);

        public static bool Enabled => Cached.Value.Enabled;

        public static bool IsExcluded(string typeDotMethod)
        {
            var exclude = Cached.Value.Exclude;
            if (exclude == null || string.IsNullOrEmpty(typeDotMethod)) return false;
            return exclude.IsMatch(typeDotMethod);
        }

        private static State Load()
        {
            var enabled = true;
            try
            {
                var raw = ConfigurationManager.AppSettings["Contoso:Trace:Enabled"];
                if (!string.IsNullOrWhiteSpace(raw))
                {
                    if (string.Equals(raw, "false", StringComparison.OrdinalIgnoreCase)
                        || raw == "0")
                        enabled = false;
                    else if (string.Equals(raw, "true", StringComparison.OrdinalIgnoreCase)
                             || raw == "1")
                        enabled = true;
                }
            }
            catch
            {
                enabled = true;
            }

            Regex exclude = null;
            try
            {
                var pattern = ConfigurationManager.AppSettings["Contoso:Trace:Exclude"];
                if (!string.IsNullOrWhiteSpace(pattern))
                    exclude = new Regex(pattern, RegexOptions.Compiled | RegexOptions.CultureInvariant);
            }
            catch
            {
                exclude = null;
            }

            return new State(enabled, exclude);
        }

        private sealed class State
        {
            public State(bool enabled, Regex exclude)
            {
                Enabled = enabled;
                Exclude = exclude;
            }

            public bool Enabled { get; }
            public Regex Exclude { get; }
        }
    }
}
