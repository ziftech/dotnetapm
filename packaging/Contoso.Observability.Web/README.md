# Contoso.Observability.Web

HTTP module package for IIS / ASP.NET Framework apps.

## packages.config

NuGet XDT transforms add the module, a DiagnosticSource 8.0.0.1 binding redirect, and an `ElasticApm:ServiceName` placeholder.

## PackageReference

XDT does not run. Copy this into `Web.config` manually:

```xml
<system.webServer>
  <modules>
    <add name="ContosoApmContext"
         type="Contoso.Observability.CheckoutLabelsHttpModule, Contoso.Observability.Web"
         preCondition="managedHandler" />
  </modules>
</system.webServer>
```

Phase 3 replaces `CheckoutLabelsHttpModule` with the generic `ApmContextHttpModule`.
