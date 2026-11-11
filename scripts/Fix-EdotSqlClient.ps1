$ErrorActionPreference = 'Stop'
$dest = 'C:\lab\app\TrackingApi\bin\OpenTelemetry.Instrumentation.SqlClient.dll'
$candidates = @(
  'C:\lab\src\packages\OpenTelemetry.Instrumentation.SqlClient.1.20.2\lib\net462\OpenTelemetry.Instrumentation.SqlClient.dll',
  'C:\lab\src\packages\OpenTelemetry.Instrumentation.SqlClient.1.20.2\lib\netstandard2.0\OpenTelemetry.Instrumentation.SqlClient.dll'
)
$src = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $src) { throw 'SqlClient 1.20.2 dll not found in packages' }
Copy-Item $src $dest -Force
Write-Output ("COPIED=" + $src)
Write-Output ("ASM=" + [Reflection.AssemblyName]::GetAssemblyName($dest).FullName)

# Prefer 1.20.2 in Deploy-EdotTrackingApi future runs: patch installed script's install list if present
$deploy = 'C:\lab\src\scripts\Deploy-EdotTrackingApi.ps1'
if (Test-Path $deploy) {
  (Get-Content $deploy -Raw) -replace "Id='OpenTelemetry.Instrumentation.SqlClient'; Version='1.20.1'", "Id='OpenTelemetry.Instrumentation.SqlClient'; Version='1.20.2'" |
    Set-Content $deploy -NoNewline
}

Import-Module WebAdministration
Restart-WebAppPool TrackingEdotPool
Start-Sleep -Seconds 4
try {
  $r = Invoke-WebRequest -UseBasicParsing 'http://127.0.0.1/tracking/api/tracking/VB-DEMO-01' -TimeoutSec 20
  Write-Output ("STATUS=" + $r.StatusCode)
  Write-Output $r.Content
} catch {
  Write-Output ("ERR=" + $_.Exception.Message)
  Get-Content C:\lab\logs\tracking-api.log -Tail 15
}
