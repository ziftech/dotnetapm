using System;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Threading.Tasks;
using MethodBoundaryAspect.Fody.Attributes;

namespace Contoso.Observability
{
    /// <summary>
    /// Build-time woven aspect (MethodBoundaryAspect.Fody). Prefer assembly-level application
    /// with NamespaceFilter / TypeNameFilter / MethodNameFilter.
    /// </summary>
    [AttributeUsage(AttributeTargets.Method | AttributeTargets.Class | AttributeTargets.Assembly,
        AllowMultiple = true, Inherited = true)]
    public sealed class TraceAttribute : OnMethodBoundaryAspect
    {
        public override void OnEntry(MethodExecutionArgs args)
        {
            if (args.Method == null) return;
            if (ShouldSkip(args.Method)) return;

            var typeName = args.Method.DeclaringType != null ? args.Method.DeclaringType.Name : "Unknown";
            var name = typeName + "." + args.Method.Name;
            var scope = TraceBackends.Current.StartSpanOrTransaction(name, "app", "business");
            args.MethodExecutionTag = scope;
        }

        public override void OnExit(MethodExecutionArgs args)
        {
            var scope = args.MethodExecutionTag as IDisposable;
            if (scope == null) return;

            // Async: OnExit runs when the Task is returned; complete after await.
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

        private static bool ShouldSkip(MethodBase method)
        {
            // Defense in depth if a compiler-generated method is still woven.
            if (method.Name == "MoveNext" || method.Name == "SetStateMachine") return true;
            var type = method.DeclaringType;
            if (type == null) return false;
            if (type.Name.IndexOf('>') >= 0) return true; // <>c, <Method>d__N
            if (type.IsDefined(typeof(CompilerGeneratedAttribute), false)) return true;
            if (method.IsDefined(typeof(CompilerGeneratedAttribute), false)) return true;
            return false;
        }
    }
}
