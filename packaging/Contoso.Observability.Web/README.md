# Contoso.Observability.Web

Generic IIS HTTP module for ASP.NET Framework apps: config-driven request labels and exception capture without `Global.asax`.

## packages.config

NuGet XDT transforms add `ApmContextHttpModule`, a DiagnosticSource 8.0.0.1 binding redirect, and an `ElasticApm:ServiceName` placeholder.

## PackageReference

XDT does not run. Copy this into `Web.config` manually:

```xml
<appSettings>
  <add key="Contoso:Labels:PathRegex" value="checkout" />
  <add key="Contoso:Labels:tracking_id" value="form:trackingId|query:trackingId" />
  <add key="Contoso:Labels:lane" value="form:lane|query:lane" />
  <add key="Contoso:Labels:weight_kg" value="form:weightKg|query:weightKg" />
</appSettings>
<system.webServer>
  <modules>
    <add name="ContosoApmContext"
         type="Contoso.Observability.ApmContextHttpModule, Contoso.Observability.Web"
         preCondition="managedHandler" />
  </modules>
</system.webServer>
```

## Label sources

Each `Contoso:Labels:<name>` value is a `|`-separated list of `form:`, `query:`, `header:`, or `route:` sources. The first non-empty value wins. Optional `Contoso:Labels:PathRegex` limits which requests get labels.
