$ErrorActionPreference = 'Continue'
Import-Module WebAdministration

function Set-AppSetting([string]$path, [string]$key, [string]$value) {
  [xml]$x = Get-Content $path
  $app = $x.SelectSingleNode('/configuration/appSettings')
  if (-not $app) {
    $app = $x.CreateElement('appSettings')
    $x.DocumentElement.AppendChild($app) | Out-Null
  }
  $n = $app.SelectSingleNode("add[@key='$key']")
  if (-not $n) {
    $n = $x.CreateElement('add')
    $n.SetAttribute('key', $key)
    $app.AppendChild($n) | Out-Null
  }
  $n.SetAttribute('value', $value)
  $x.Save($path)
}

foreach ($p in @('C:\lab\app\ShipmentsWeb\Web.config', 'C:\lab\app\TrackingApi\Web.config')) {
  Set-AppSetting $p 'ElasticApm:ApplicationNamespaces' 'Contoso.'
  Set-AppSetting $p 'ElasticApm:SpanStackTraceMinDuration' '0ms'
  Set-AppSetting $p 'ElasticApm:Environment' 'lab'
  Set-AppSetting $p 'ElasticApm:ServiceVersion' '1.0.0-lab'
}
Set-AppSetting 'C:\lab\app\ShipmentsWeb\Web.config' 'ElasticApm:ServiceName' 'ShipmentsWeb'
Set-AppSetting 'C:\lab\app\TrackingApi\Web.config' 'ElasticApm:ServiceName' 'TrackingApi'

$nlogSrc = Get-ChildItem 'C:\lab\src\packages\Elastic.Apm.NLog*\lib' -Recurse -Filter Elastic.Apm.NLog.dll -EA SilentlyContinue | Select-Object -First 1
if ($nlogSrc) {
  Copy-Item $nlogSrc.FullName 'C:\lab\app\TrackingApi\bin\' -Force
  $apm = Get-ChildItem 'C:\lab\src\packages\Elastic.Apm.1.*\lib' -Recurse -Filter Elastic.Apm.dll -EA SilentlyContinue | Select-Object -First 1
  if ($apm) { Copy-Item $apm.FullName 'C:\lab\app\TrackingApi\bin\' -Force }
}

# Ensure Contoso.Observability + MethodBoundaryAspect in bins
Copy-Item 'C:\lab\src\src\Contoso.Observability\bin\Release\Contoso.Observability.dll' 'C:\lab\app\ShipmentsWeb\bin\' -Force -EA SilentlyContinue
Copy-Item 'C:\lab\src\src\Contoso.Observability\bin\Release\Contoso.Observability.dll' 'C:\lab\app\TrackingApi\bin\' -Force -EA SilentlyContinue

& 'C:\lab\src\scripts\Restore-ProfilerTrackingApi.ps1'
Restart-WebAppPool SharedPool
Start-Sleep 5

Write-Output '--- home ---'
(Invoke-WebRequest 'http://localhost/web/' -UseBasicParsing).StatusCode
Write-Output '--- slow checkout ---'
try {
  $r = Invoke-WebRequest 'http://localhost/web/Checkout' -Method POST -Body @{ trackingId = 'ASM-WEAVE-1'; lane = 'SLOW'; weightKg = '5' } -UseBasicParsing -TimeoutSec 60
  Write-Output $r.StatusCode
} catch {
  Write-Output $_.Exception.Message
}
Write-Output '--- tracking ---'
try {
  (Invoke-WebRequest 'http://localhost/tracking/api/tracking/ASM-WEAVE-1' -UseBasicParsing).StatusCode
} catch { Write-Output $_.Exception.Message }

Write-Output '--- web log tail ---'
Get-Content 'C:\lab\logs\shipments-web.log' -Tail 5 -EA SilentlyContinue
Write-Output '--- tracking log tail ---'
Get-ChildItem 'C:\lab\logs\*.log' | ForEach-Object { Write-Output ("FILE " + $_.FullName); Get-Content $_.FullName -Tail 3 -EA SilentlyContinue }
Write-Output 'SMOKE_DONE'
