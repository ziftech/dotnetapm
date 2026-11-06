using System;
using System.Reflection;
using System.Threading.Tasks;
using MethodBoundaryAspect.Fody.Attributes;

namespace Contoso.Observability
{
    /// <summary>
    /// Build-time woven aspect (third-party MethodBoundaryAspect.Fody).
    /// Creates child spans when a transaction exists; otherwise starts a transaction (worker).
    /// </summary>
    public sealed class TraceAttribute : OnMethodBoundaryAspect
    {
        private const string ScopeKey = "Contoso.Observability.Scope";

        public override void OnEntry(MethodExecutionArgs args)
        {
            if (args.Method == null) return;
            if (args.Method.IsDefined(typeof(DisableWeavingAttribute), false)) return;
            if (args.Method.DeclaringType != null &&
                args.Method.DeclaringType.IsDefined(typeof(DisableWeavingAttribute), false)) return;

            var typeName = args.Method.DeclaringType != null ? args.Method.DeclaringType.Name : "Unknown";
            var name = typeName + "." + args.Method.Name;
            var scope = TraceBackends.Current.StartSpanOrTransaction(name, "app", "business");
            args.MethodExecutionTag = scope;
        }

        public override void OnExit(MethodExecutionArgs args)
        {
            var scope = args.MethodExecutionTag as IDisposable;
            if (scope == null) return;

            // Async: MethodBoundaryAspect may call OnExit before the Task completes.
            if (args.ReturnValue is Task task)
            {
                TraceScope.CompleteAsync(scope, task, null);
                return;
            }

            scope.Dispose();
        }

        public override void OnException(MethodExecutionArgs args)
        {
            var scope = args.MethodExecutionTag as IDisposable;
            if (args.Exception != null)
            {
                TraceBackends.Current.CaptureException(args.Exception);
            }
            scope?.Dispose();
        }
    }
}
