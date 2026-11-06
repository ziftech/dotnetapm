using System.Reflection;
using Contoso.Observability;
using MethodBoundaryAspect.Fody.Attributes;

[assembly: AssemblyTitle("Contoso.Shipments.Business")]
[assembly: AssemblyDescription("Synthetic Contoso shipments business library for APM lab")]
[assembly: AssemblyConfiguration("")]
[assembly: AssemblyCompany("Contoso Synthetic")]
[assembly: AssemblyProduct("Contoso.Shipments.Business")]
[assembly: AssemblyCopyright("Copyright © Contoso Synthetic 2026")]
[assembly: AssemblyTrademark("")]
[assembly: AssemblyCulture("")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

// WEAVE_MODE markers — scripts/Set-WeaveMode.ps1 rewrites the Trace lines below.
// NARROW (default): public methods on *Service types only.
// BROAD: also PricingCalculator / CallChain / ShipmentRepository.
// NONE: no Trace attribute (plus optional [assembly: DisableWeaving] for B0).

// BEGIN_WEAVE
[assembly: Trace(
    NamespaceFilter = @"^Contoso\.Shipments",
    TypeNameFilter = @"Service$",
    MethodNameFilter = @"^(?!MoveNext$|SetStateMachine$).+",
    AttributeTargetMemberAttributes = MulticastAttributes.Public)]
// END_WEAVE
