using System;

namespace Contoso.Observability
{
    /// <summary>Marker to skip MethodBoundaryAspect weaving on hot paths.</summary>
    [AttributeUsage(AttributeTargets.Method | AttributeTargets.Class, AllowMultiple = false, Inherited = false)]
    public sealed class DisableWeavingAttribute : Attribute
    {
    }
}
