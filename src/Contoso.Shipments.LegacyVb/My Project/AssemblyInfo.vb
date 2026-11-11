Imports System.Reflection
Imports Contoso.Observability
Imports MethodBoundaryAspect.Fody.Attributes

<Assembly: AssemblyTitle("Contoso.Shipments.LegacyVb")>
<Assembly: AssemblyDescription("VB.NET Framework 4.8 class library — Fody Trace weave demo for Contoso lab")>
<Assembly: AssemblyCompany("Contoso Synthetic")>
<Assembly: AssemblyProduct("Contoso.Shipments.LegacyVb")>
<Assembly: AssemblyCopyright("Copyright © Contoso Synthetic 2026")>
<Assembly: AssemblyVersion("1.0.0.0")>
<Assembly: AssemblyFileVersion("1.0.0.0")>

' Same pattern as Contoso.Shipments.Business (C#): one assembly-level Trace attribute.
' Public methods on *Service types are woven — method bodies stay free of APM calls.
<Assembly: Trace(
    NamespaceFilter:="^Contoso\.Shipments\.LegacyVb",
    TypeNameFilter:="Service$",
    MethodNameFilter:="^(?!MoveNext$|SetStateMachine$).+",
    AttributeTargetMemberAttributes:=MulticastAttributes.Public)>
