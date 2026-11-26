$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName 'Microsoft.Web.Administration, Version=7.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35'
Import-Module WebAdministration

$otelHome = 'C:\Program Files\OpenTelemetry .NET AutoInstrumentation'
$otelNative = "$otelHome\win-x64\OpenTelemetry.AutoInstrumentation.Native.dll"
$logDir = 'C:\lab\logs\otel-auto'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$edot = @{}
Get-Content "$env:USERPROFILE\edot.env" | ForEach-Object {
  if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
  $i = $_.IndexOf('='); $edot[$_.Substring(0,$i).Trim()] = $_.Substring($i+1).Trim()
}

$sm = New-Object Microsoft.Web.Administration.ServerManager
$pool = $sm.ApplicationPools['TrackingEdotPool']
$envColl = $pool.GetCollection('environmentVariables')
$map = @{
  'COR_ENABLE_PROFILING' = '1'
  'COR_PROFILER' = '{918728DD-259F-4A6A-AC2B-B85E1B658318}'
  'COR_PROFILER_PATH' = $otelNative
  'COR_PROFILER_PATH_64' = $otelNative
  'COR_PROFILER_PATH_32' = "$otelHome\win-x86\OpenTelemetry.AutoInstrumentation.Native.dll"
  'OTEL_DOTNET_AUTO_HOME' = $otelHome
  'DOTNET_STARTUP_HOOKS' = "$otelHome\net\OpenTelemetry.AutoInstrumentation.StartupHook.dll"
  'DOTNET_SHARED_STORE' = "$otelHome\store"
  'DOTNET_ADDITIONAL_DEPS' = "$otelHome\AdditionalDeps"
  'OTEL_SERVICE_NAME' = 'TrackingApi-EDOT'
  'OTEL_RESOURCE_ATTRIBUTES' = 'deployment.environment=lab,service.version=s5-edot-zero'
  'OTEL_EXPORTER_OTLP_ENDPOINT' = $edot['OTEL_EXPORTER_OTLP_ENDPOINT']
  'OTEL_EXPORTER_OTLP_HEADERS' = $edot['OTEL_EXPORTER_OTLP_HEADERS']
  'OTEL_EXPORTER_OTLP_PROTOCOL' = 'http/protobuf'
  'OTEL_TRACES_EXPORTER' = 'otlp'
  'OTEL_METRICS_EXPORTER' = 'none'
  'OTEL_LOGS_EXPORTER' = 'none'
  'OTEL_DOTNET_AUTO_TRACES_ADDITIONAL_SOURCES' = 'Contoso.Observability'
  'OTEL_LOG_LEVEL' = 'info'
  'OTEL_DOTNET_AUTO_LOG_DIRECTORY' = $logDir
}
foreach ($key in $map.Keys) {
  $found = $false
  foreach ($e in $envColl) {
    if ($e.GetAttributeValue('name') -eq $key) { $e.SetAttributeValue('value', [string]$map[$key]); $found=$true; break }
  }
  if (-not $found) {
    $el = $envColl.CreateElement('add'); $el['name']=$key; $el['value']=[string]$map[$key]; [void]$envColl.Add($el)
  }
}
# remove broken plugin pointer
for ($i=$envColl.Count-1; $i -ge 0; $i--) {
  if ($envColl[$i].GetAttributeValue('name') -eq 'OTEL_DOTNET_AUTO_PLUGINS') { $envColl.RemoveAt($i) }
}
$sm.CommitChanges()
Restart-WebAppPool TrackingEdotPool
Start-Sleep 5

$tid = 'CTR-EDOT' + (Get-Date -Format 'HHmmss')
$code = & curl.exe -s -o C:\lab\logs\tracking-edot-body.txt -w '%{http_code}' "http://127.0.0.1/tracking/api/tracking/$tid"
Write-Output ("TRACKING_HTTP=$code tid=$tid")
Get-Content C:\lab\logs\tracking-edot-body.txt
Start-Sleep 1
$lines = Get-Content C:\lab\logs\tracking-api.log -Tail 20 | Where-Object { $_ -match [regex]::Escape($tid) }
$lines
if ($lines -match 'trace\.id=[0-9a-fA-F]{16,}') { 'TRACKING_NLOG_TRACE_OK' } else { 'TRACKING_NLOG_TRACE_EMPTY' }

# modules
Get-CimInstance Win32_Process -Filter "Name='w3wp.exe'" | Where-Object { $_.CommandLine -match 'TrackingEdotPool' } | ForEach-Object {
  Write-Output ("PID=" + $_.ProcessId)
  try {
    (Get-Process -Id $_.ProcessId).Modules | Where-Object { $_.ModuleName -match 'OpenTelemetry.AutoInstrumentation.Native' } |
      ForEach-Object { Write-Output ('MODULE ' + $_.FileName) }
  } catch {}
}

Write-Output ("ES_QUERY_TID=$tid")
Write-Output ("ES_QUERY_AFTER=" + (Get-Date).ToUniversalTime().ToString('o'))
