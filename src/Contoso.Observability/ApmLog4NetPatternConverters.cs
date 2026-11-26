using System.IO;
using log4net.Core;
using log4net.Layout.Pattern;

namespace Contoso.Observability
{
    /// <summary>log4net converter: %apm_trace_id</summary>
    public sealed class ApmTraceIdPatternConverter : PatternLayoutConverter
    {
        protected override void Convert(TextWriter writer, LoggingEvent loggingEvent)
        {
            writer.Write(ApmBusiness.CurrentTraceId() ?? string.Empty);
        }
    }

    /// <summary>log4net converter: %apm_transaction_id</summary>
    public sealed class ApmTransactionIdPatternConverter : PatternLayoutConverter
    {
        protected override void Convert(TextWriter writer, LoggingEvent loggingEvent)
        {
            writer.Write(ApmBusiness.CurrentTransactionOrSpanId() ?? string.Empty);
        }
    }
}
