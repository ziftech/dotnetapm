# Download EDOT + ASP.NET + SqlClient instrumentation packages into C:\lab\src\packages
$ErrorActionPreference = "Stop"
$nuget = 'C:\lab\nuget.exe'
if (-not (Test-Path $nuget)) {
  Invoke-WebRequest -Uri 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile $nuget -UseBasicParsing
}
$packages = 'C:\lab\src\packages'
New-Item -ItemType Directory -Force -Path $packages | Out-Null
& $nuget install Elastic.OpenTelemetry -Version 1.7.0 -OutputDirectory $packages -NonInteractive
& $nuget install OpenTelemetry.Instrumentation.AspNet -Version 1.14.0 -OutputDirectory $packages -NonInteractive -PreRelease
# Prefer latest stable AspNet if available; fall back handled below
& $nuget install OpenTelemetry.Instrumentation.AspNet -Version 1.20.3 -OutputDirectory $packages -NonInteractive
& $nuget install OpenTelemetry.Instrumentation.SqlClient -Version 1.20.2 -OutputDirectory $packages -NonInteractive
Write-Output 'PACKAGES_OK'
Get-ChildItem $packages -Directory | Where-Object { $_.Name -match 'Elastic.OpenTelemetry|OpenTelemetry' } | Select-Object -ExpandProperty Name
