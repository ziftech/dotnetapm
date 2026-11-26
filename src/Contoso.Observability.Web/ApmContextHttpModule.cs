using System;
using System.Collections.Generic;
using System.Configuration;
using System.Text.RegularExpressions;
using System.Web;

namespace Contoso.Observability
{
    /// <summary>
    /// Generic IIS module: request labels from appSettings and exception capture
    /// without Global.asax. Register only under system.webServer/modules.
    /// </summary>
    public sealed class ApmContextHttpModule : IHttpModule
    {
        private const string LabelPrefix = "Contoso:Labels:";
        private const string PathRegexKey = "Contoso:Labels:PathRegex";

        public void Init(HttpApplication context)
        {
            if (context == null) return;
            context.PostAcquireRequestState += OnPostAcquireRequestState;
            context.Error += OnError;
        }

        private static void OnPostAcquireRequestState(object sender, EventArgs e)
        {
            try
            {
                var app = sender as HttpApplication;
                var request = app?.Context?.Request;
                if (request == null) return;
                if (!PathMatches(request)) return;

                foreach (var mapping in ReadLabelMappings())
                {
                    var value = ResolveValue(request, mapping.Sources);
                    if (!string.IsNullOrWhiteSpace(value))
                        ApmBusiness.SetLabel(mapping.Label, value.Trim());
                }
            }
            catch
            {
                // Never throw from the module.
            }
        }

        private static void OnError(object sender, EventArgs e)
        {
            try
            {
                var app = sender as HttpApplication;
                var ex = app?.Server?.GetLastError();
                if (ex == null) return;
                TraceBackends.Current.CaptureException(ex);
            }
            catch
            {
                // Never throw from the module.
            }
        }

        private static bool PathMatches(HttpRequest request)
        {
            var pattern = ConfigurationManager.AppSettings[PathRegexKey];
            if (string.IsNullOrWhiteSpace(pattern)) return true;

            var path = request.AppRelativeCurrentExecutionFilePath ?? request.Path ?? string.Empty;
            try
            {
                return Regex.IsMatch(path, pattern, RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
            }
            catch
            {
                return false;
            }
        }

        private static IEnumerable<LabelMapping> ReadLabelMappings()
        {
            var settings = ConfigurationManager.AppSettings;
            if (settings == null) yield break;

            foreach (var key in settings.AllKeys)
            {
                if (string.IsNullOrEmpty(key)) continue;
                if (!key.StartsWith(LabelPrefix, StringComparison.OrdinalIgnoreCase)) continue;
                if (string.Equals(key, PathRegexKey, StringComparison.OrdinalIgnoreCase)) continue;

                var label = key.Substring(LabelPrefix.Length).Trim();
                if (string.IsNullOrEmpty(label)) continue;

                var raw = settings[key];
                if (string.IsNullOrWhiteSpace(raw)) continue;

                yield return new LabelMapping(label, raw.Split(new[] { '|' }, StringSplitOptions.RemoveEmptyEntries));
            }
        }

        private static string ResolveValue(HttpRequest request, string[] sources)
        {
            if (sources == null) return null;
            foreach (var source in sources)
            {
                var value = ReadSource(request, source);
                if (!string.IsNullOrWhiteSpace(value)) return value;
            }
            return null;
        }

        private static string ReadSource(HttpRequest request, string source)
        {
            if (string.IsNullOrWhiteSpace(source)) return null;
            var colon = source.IndexOf(':');
            if (colon <= 0 || colon >= source.Length - 1) return null;

            var kind = source.Substring(0, colon).Trim();
            var name = source.Substring(colon + 1).Trim();
            if (string.IsNullOrEmpty(name)) return null;

            try
            {
                if (kind.Equals("form", StringComparison.OrdinalIgnoreCase))
                {
                    try { return request.Form[name]; }
                    catch { return null; }
                }
                if (kind.Equals("query", StringComparison.OrdinalIgnoreCase))
                    return request.QueryString[name];
                if (kind.Equals("header", StringComparison.OrdinalIgnoreCase))
                    return request.Headers[name];
                if (kind.Equals("route", StringComparison.OrdinalIgnoreCase))
                {
                    var values = request.RequestContext?.RouteData?.Values;
                    if (values == null || !values.ContainsKey(name)) return null;
                    return values[name]?.ToString();
                }
            }
            catch
            {
                return null;
            }

            return null;
        }

        public void Dispose()
        {
        }

        private sealed class LabelMapping
        {
            public LabelMapping(string label, string[] sources)
            {
                Label = label;
                Sources = sources ?? Array.Empty<string>();
            }

            public string Label { get; }
            public string[] Sources { get; }
        }
    }
}
