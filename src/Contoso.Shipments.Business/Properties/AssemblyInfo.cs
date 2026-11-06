using System.Reflection;

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

// S2 narrow: weave public methods on *Service types in Contoso.Shipments.* (class-level Trace below is the reliable Fody path).
// Broad variant additionally applies [Trace] on PricingCalculator / CallChain / ShipmentRepository.
