$ErrorActionPreference = 'Stop'
Import-Module WebAdministration
Add-Type -AssemblyName 'Microsoft.Web.Administration, Version=7.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35'

# Keep OpenTelemetry core installed, but remove machine/service-wide COR_* so
# each app pool owns its profiler (Elastic on SharedPool, OTel on TrackingEdotPool).
$modulePath = 'C:\Program Files\OpenTelemetry .NET AutoInstrumentation\OpenTelemetry.DotNet.Auto.psm1'
if (Test-Path $modulePath) {
  Import-Module $modulePath
  try { Unregister-OpenTelemetryForIIS -NoReset:$true } catch { Unregister-OpenTelemetryForIIS }
  Write-Output 'Unregister-OpenTelemetryForIIS OK (core remains installed; pools keep their COR_*)'
}

function Set-PoolEnvMap([string]$poolName, [hashtable]$map, [string[]]$remove = @()) {
  $sm = New-Object Microsoft.Web.Administration.ServerManager
  $pool = $sm.ApplicationPools[$poolName]
  $envColl = $pool.GetCollection('environmentVariables')
  foreach ($n in $remove) {
    for ($i = $envColl.Count - 1; $i -ge 0; $i--) {
      if ($envColl[$i].GetAttributeValue('name') -eq $n) { $envColl.RemoveAt($i) }
    }
  }
  foreach ($key in $map.Keys) {
    $found = $false
    foreach ($e in $envColl) {
      if ($e.GetAttributeValue('name') -eq $key) {
        $e.SetAttributeValue('value', [string]$map[$key]); $found = $true; break
      }
    }
    if (-not $found) {
      $el = $envColl.CreateElement('add'); $el['name'] = $key; $el['value'] = [string]$map[$key]; [void]$envColl.Add($el)
    }
  }
  $sm.CommitChanges()
}

$apm = @{}
Get-Content "$env:USERPROFILE\apm.env" | ForEach-Object {
  if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
  $i = $_.IndexOf('='); $apm[$_.Substring(0,$i).Trim()] = $_.Substring($i+1).Trim()
}
$edot = @{}
Get-Content "$env:USERPROFILE\edot.env" | ForEach-Object {
  if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
  $i = $_.IndexOf('='); $edot[$_.Substring(0,$i).Trim()] = $_.Substring($i+1).Trim()
}

$profilerHome = 'C:\elastic\apm-agent-dotnet'
$elasticDll = "$profilerHome\elastic_apm_profiler.dll"
Set-PoolEnvMap 'SharedPool' @{
  'COR_ENABLE_PROFILING' = '1'
  'COR_PROFILER' = '{FA65FE15-F085-4681-9B20-95E04F6C03CC}'
  'COR_PROFILER_PATH' = $elasticDll
  'COR_PROFILER_PATH_64' = $elasticDll
  'COR_PROFILER_PATH_32' = $elasticDll
  'ELASTIC_APM_PROFILER_HOME' = $profilerHome
  'ELASTIC_APM_PROFILER_INTEGRATIONS' = "$profilerHome\integrations.yml"
  'COMPlus_LoaderOptimization' = '1'
  'ELASTIC_APM_SERVER_URL' = $apm['ELASTIC_APM_SERVER_URL']
  'ELASTIC_APM_API_KEY' = $apm['ELASTIC_APM_API_KEY']
  'ELASTIC_APM_ENVIRONMENT' = 'lab'
  'ELASTIC_APM_APPLICATION_NAMESPACES' = 'Contoso.'
  'ELASTIC_APM_SPAN_STACK_TRACE_MIN_DURATION' = '0ms'
  'ELASTIC_APM_PROFILER_LOG' = 'info'
  'ELASTIC_APM_PROFILER_LOG_DIR' = 'C:\ProgramData\elastic\apm-agent-dotnet\logs'
} @(
  'OTEL_DOTNET_AUTO_HOME','DOTNET_STARTUP_HOOKS','OTEL_DOTNET_AUTO_PLUGINS',
  'OTEL_EXPORTER_OTLP_ENDPOINT','OTEL_SERVICE_NAME','OTEL_DOTNET_AUTO_TRACES_ADDITIONAL_SOURCES',
  'CORECLR_ENABLE_PROFILING','CORECLR_PROFILER','CORECLR_PROFILER_PATH','CORECLR_PROFILER_PATH_64','CORECLR_PROFILER_PATH_32',
  'DOTNET_SHARED_STORE','DOTNET_ADDITIONAL_DEPS','ASPNETCORE_HOSTINGSTARTUPASSEMBLIES'
)

$otelHome = 'C:\Program Files\OpenTelemetry .NET AutoInstrumentation'
$logDir = 'C:\lab\logs\otel-auto'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$otelNative = "$otelHome\win-x64\OpenTelemetry.AutoInstrumentation.Native.dll"
Set-PoolEnvMap 'TrackingEdotPool' @{
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
} @('OTEL_DOTNET_AUTO_PLUGINS','ELASTIC_APM_SERVER_URL','ELASTIC_APM_API_KEY','ELASTIC_APM_PROFILER_HOME','COR_PROFILER_PATH')

Set-ItemProperty 'IIS:\Sites\Shipments\tracking' -Name applicationPool -Value 'TrackingEdotPool'

iisreset /noforce | Out-Null
Start-Sleep 8

Write-Output '--- w3wp profiler modules ---'
# warm both
try { Invoke-WebRequest 'http://127.0.0.1/web/' -UseBasicParsing -TimeoutSec 30 | Out-Null } catch { Write-Output $_.Exception.Message }
try { Invoke-WebRequest 'http://127.0.0.1/tracking/api/tracking/zero2' -UseBasicParsing -TimeoutSec 60 | Out-Null } catch { Write-Output ("track_warm=" + $_.Exception.Message) }
Start-Sleep 2
Get-CimInstance Win32_Process -Filter "Name='w3wp.exe'" | ForEach-Object {
  Write-Output ("PID={0} {1}" -f $_.ProcessId, $_.CommandLine)
  try {
    $p = Get-Process -Id $_.ProcessId
    $p.Modules | Where-Object { $_.ModuleName -match 'elastic_apm_profiler|OpenTelemetry.AutoInstrumentation.Native' } |
      ForEach-Object { Write-Output ("  MODULE " + $_.ModuleName + " => " + $_.FileName) }
  } catch { Write-Output ("  " + $_.Exception.Message) }
}

$tid = 'CTR-ZERO' + (Get-Date -Format 'HHmmss')
try {
  $r = Invoke-WebRequest ("http://127.0.0.1/tracking/api/tracking/" + $tid) -UseBasicParsing -TimeoutSec 60
  Write-Output ("TRACKING_OK " + $r.StatusCode + " " + $r.Content)
} catch {
  Write-Output ("TRACKING_FAIL " + $_.Exception.Message)
  Get-ChildItem $logDir -File | Sort LastWriteTime -Descending | Select -First 3 | ForEach-Object {
    Write-Output $_.Name
    Get-Content $_.FullName -Tail 30
  }
  Get-Content C:\lab\logs\tracking-api.log -Tail 15
}

$body = "trackingId=$tid&lane=DXB-AMM&weightKg=5"
$r2 = Invoke-WebRequest 'http://127.0.0.1/web/Checkout' -Method POST -Body $body -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing -TimeoutSec 120
Write-Output ("CHECKOUT " + $r2.StatusCode)
Start-Sleep 1
$lines = Get-Content C:\lab\logs\shipments-web.log -Tail 30 | Where-Object { $_ -match [regex]::Escape($tid) }
$lines
if ($lines -match 'trace\.id=[0-9a-fA-F]{16,}') { 'FRESH_LOG4NET_OK' } else { 'FRESH_LOG4NET_EMPTY' }
Write-Output ("ES_TRACKING_ID=" + $tid)
