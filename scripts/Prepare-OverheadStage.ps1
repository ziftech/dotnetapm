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

# Keep ApplicationNamespaces / stacktrace on web.configs
foreach ($p in @('C:\lab\app\ShipmentsWeb\Web.config', 'C:\lab\app\TrackingApi\Web.config')) {
  if (-not (Test-Path $p)) { continue }
  [xml]$x = Get-Content $p
  $app = $x.SelectSingleNode('/configuration/appSettings')
  foreach ($kv in @(
      @{ k = 'ElasticApm:ApplicationNamespaces'; v = 'Contoso.' },
      @{ k = 'ElasticApm:SpanStackTraceMinDuration'; v = '0ms' }
    )) {
    $n = $app.SelectSingleNode("add[@key='$($kv.k)']")
    if (-not $n) {
      $n = $x.CreateElement('add'); $n.SetAttribute('key', $kv.k); $app.AppendChild($n) | Out-Null
    }
    $n.SetAttribute('value', $kv.v)
  }
  $x.Save($p)
}

& "$root\scripts\Fix-TrackingBuffers.ps1"
Import-Module WebAdministration
Restart-WebAppPool SharedPool
Start-Sleep 5
cmd /c "curl -sS -o NUL -w home=%{http_code} http://127.0.0.1/web/"
Write-Output ''
cmd /c "curl -sS -o NUL -w tracking=%{http_code} http://127.0.0.1/tracking/api/tracking/warmup"
Write-Output ''
Write-Output "STAGE_READY=$Stage"
