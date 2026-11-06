param(
  [ValidateSet('B0','S1','narrow','broad')]
  [string]$Stage
)
$ErrorActionPreference = 'Stop'
$root = 'C:\lab\src'
$map = @{}
Get-Content 'C:\lab\apm-stage.env' | ForEach-Object {
  if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
  $i = $_.IndexOf('='); $map[$_.Substring(0, $i).Trim()] = $_.Substring($i + 1).Trim()
}
$server = $map['ServerUrl']
$key = $map['ApiKey']
if (-not $server -or -not $key) { throw 'missing ServerUrl/ApiKey in C:\lab\apm-stage.env' }

function Set-AppSetting([xml]$xml, [string]$key, [string]$value) {
  $app = $xml.SelectSingleNode('/configuration/appSettings')
  if (-not $app) { throw "no appSettings in config" }
  $n = $app.SelectSingleNode("add[@key='$key']")
  if (-not $n) {
    $n = $xml.CreateElement('add')
    $n.SetAttribute('key', $key)
    [void]$app.AppendChild($n)
  }
  $n.SetAttribute('value', $value)
}

function Ensure-PerAppApmSettings {
  # Keep distinct service names so traces show ShipmentsWeb -> TrackingApi, not a shared pool name.
  $pairs = @(
    @{ Path = 'C:\lab\app\ShipmentsWeb\Web.config'; Service = 'ShipmentsWeb' },
    @{ Path = 'C:\lab\app\TrackingApi\Web.config'; Service = 'TrackingApi' }
  )
  foreach ($p in $pairs) {
    if (-not (Test-Path $p.Path)) { continue }
    [xml]$x = Get-Content $p.Path
    Set-AppSetting $x 'ElasticApm:ServiceName' $p.Service
    Set-AppSetting $x 'ElasticApm:Environment' 'lab'
    Set-AppSetting $x 'ElasticApm:ServerUrl' $server
    Set-AppSetting $x 'ElasticApm:ApplicationNamespaces' 'Contoso.'
    Set-AppSetting $x 'ElasticApm:SpanStackTraceMinDuration' '0ms'
    if ($key) { Set-AppSetting $x 'ElasticApm:ApiKey' $key }
    $x.Save($p.Path)
    Write-Output "APM_SETTINGS service=$($p.Service) path=$($p.Path)"
  }
}

# Deploy Observability + NLog config before weave rebuild so TrackingApi has Contoso renderers.
if (Test-Path "$root\src\Contoso.Observability\bin\Release\Contoso.Observability.dll") {
  Copy-Item "$root\src\Contoso.Observability\bin\Release\Contoso.Observability.dll" 'C:\lab\app\TrackingApi\bin\' -Force -ErrorAction SilentlyContinue
  Copy-Item "$root\src\Contoso.Observability\bin\Release\Contoso.Observability.dll" 'C:\lab\app\ShipmentsWeb\bin\' -Force -ErrorAction SilentlyContinue
}
if (Test-Path "$root\src\TrackingApi\NLog.config") {
  Copy-Item "$root\src\TrackingApi\NLog.config" 'C:\lab\app\TrackingApi\NLog.config' -Force
}

switch ($Stage) {
  'B0' {
    & "$root\scripts\Run-Overhead10m.ps1" -WeaveMode none
    & "$root\scripts\Configure-ApmPool.ps1" -Mode none
  }
  'S1' {
    & "$root\scripts\Run-Overhead10m.ps1" -WeaveMode none
    & "$root\scripts\Configure-ApmPool.ps1" -Mode profiler -ServerUrl $server -ApiKey $key
  }
  'narrow' {
    & "$root\scripts\Run-Overhead10m.ps1" -WeaveMode narrow
    & "$root\scripts\Configure-ApmPool.ps1" -Mode profiler -ServerUrl $server -ApiKey $key
  }
  'broad' {
    & "$root\scripts\Run-Overhead10m.ps1" -WeaveMode broad
    & "$root\scripts\Configure-ApmPool.ps1" -Mode profiler -ServerUrl $server -ApiKey $key
  }
}

Ensure-PerAppApmSettings
& "$root\scripts\Fix-TrackingBuffers.ps1"
& "$root\scripts\Fix-DiagnosticSource.ps1"
# Fix-DiagnosticSource already recycles the pool and verifies checkout once.
Start-Sleep 2

# Warm ALL three k6 endpoints (narrow historically failed checkout when only home/tracking were warmed).
Write-Output '=== WARMUP ==='
cmd /c "curl -sS -o NUL -w home=%{http_code} http://127.0.0.1/web/"
Write-Output ''
cmd /c "curl -sS -o NUL -w tracking=%{http_code} http://127.0.0.1/tracking/api/tracking/warmup"
Write-Output ''
for ($i = 1; $i -le 5; $i++) {
  $code = cmd /c "curl -sS -o NUL -w %{http_code} -X POST --data-urlencode trackingId=WARM-$i --data-urlencode lane=DXB-AMM --data-urlencode weightKg=5 http://127.0.0.1/web/Checkout"
  Write-Output "checkout_warm_$i=$code"
  if ($code -ne '200') { throw "checkout warm-up failed: HTTP $code" }
}

# Gate: quick check burst must be healthy before k6 starts
$ok = 0
for ($i = 1; $i -le 10; $i++) {
  $code = cmd /c "curl -sS -o NUL -w %{http_code} -X POST --data-urlencode trackingId=GATE-$i --data-urlencode lane=DXB-AMM --data-urlencode weightKg=5 http://127.0.0.1/web/Checkout"
  if ($code -eq '200') { $ok++ }
}
Write-Output "checkout_gate_ok=$ok/10"
if ($ok -lt 9) { throw "checkout gate failed ($ok/10); refusing to start stage $Stage" }

Write-Output "STAGE_READY=$Stage"
