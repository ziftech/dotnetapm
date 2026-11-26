using System;

namespace Contoso.Observability
{
    /// <summary>Capture an exception at most once as it bubbles through nested woven frames.</summary>
    internal static class ExceptionCapture
    {
        private const string CapturedKey = "contoso.apm.captured";

        public static bool TryMark(Exception exception)
        {
            if (exception == null) return false;
            try
            {
                if (exception.Data == null) return true;
                if (exception.Data.Contains(CapturedKey)) return false;
                exception.Data[CapturedKey] = true;
                return true;
            }
            catch
            {
                // Some exceptions reject Data mutations; still allow one capture attempt.
                return true;
            }
        }
    }
}
