# Install OpenTelemetry .NET AutoInstrumentation, run Register-OpenTelemetryForIIS once,
# then scope profilers per pool so ShipmentsWeb keeps Elastic APM while TrackingApi uses
# OTel zero-code with OTEL_DOTNET_AUTO_TRACES_ADDITIONAL_SOURCES=Contoso.Observability.
$ErrorActionPreference = "Stop"
Import-Module WebAdministration
Add-Type -AssemblyName "Microsoft.Web.Administration, Version=7.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35" -ErrorAction SilentlyContinue

$moduleDir = 'C:\Program Files\OpenTelemetry .NET AutoInstrumentation'
$modulePath = Join-Path $moduleDir 'OpenTelemetry.DotNet.Auto.psm1'
$version = 'v1.12.0'

if (-not (Test-Path $modulePath)) {
  Write-Output "Downloading OpenTelemetry.DotNet.Auto.psm1 ($version)..."
  $tmp = Join-Path $env:TEMP ("otel-auto-" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  $url = "https://github.com/open-telemetry/opentelemetry-dotnet-instrumentation/releases/download/$version/OpenTelemetry.DotNet.Auto.psm1"
  $dl = Join-Path $tmp 'OpenTelemetry.DotNet.Auto.psm1'
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest -Uri $url -OutFile $dl -UseBasicParsing
  Import-Module $dl
  Install-OpenTelemetryCore -InstallDir $moduleDir
  Copy-Item $dl $modulePath -Force
  Write-Output "Installed OpenTelemetry core under $moduleDir"
} else {
  Import-Module $modulePath
  Write-Output "Using existing OpenTelemetry module at $modulePath"
}

# Satisfy the zero-code IIS registration step, then clear W3SVC/WAS COR_* so pools
# can choose Elastic vs OTel independently (service-level PATH_64 would otherwise win).
Register-OpenTelemetryForIIS -NoReset:$true
try { Unregister-OpenTelemetryForIIS -NoReset:$true } catch { Unregister-OpenTelemetryForIIS }
Write-Output 'Register-OpenTelemetryForIIS + pool-scoped Unregister complete'

function Set-PoolEnvMap([string]$poolName, [hashtable]$map, [string[]]$remove = @()) {
  $sm = New-Object Microsoft.Web.Administration.ServerManager
  $pool = $sm.ApplicationPools[$poolName]
  if (-not $pool) { throw "missing $poolName" }
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

$map = @{}
Get-Content "$env:USERPROFILE\edot.env" | ForEach-Object {
  if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
  $i = $_.IndexOf('='); $map[$_.Substring(0,$i).Trim()] = $_.Substring($i+1).Trim()
}
if (-not $map['OTEL_EXPORTER_OTLP_ENDPOINT']) { throw 'missing OTEL_EXPORTER_OTLP_ENDPOINT' }
if (-not $map['OTEL_EXPORTER_OTLP_HEADERS']) { throw 'missing OTEL_EXPORTER_OTLP_HEADERS' }

$poolName = 'TrackingEdotPool'
$siteApp = 'Shipments/tracking'
if (-not (Test-Path "IIS:\AppPools\$poolName")) { New-WebAppPool -Name $poolName | Out-Null }
Set-ItemProperty "IIS:\AppPools\$poolName" -Name managedRuntimeVersion -Value 'v4.0'
Set-ItemProperty "IIS:\AppPools\$poolName" -Name enable32BitAppOnWin64 -Value $false

$otelNative = Join-Path $moduleDir 'win-x64\OpenTelemetry.AutoInstrumentation.Native.dll'
$logDir = 'C:\lab\logs\otel-auto'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

Set-PoolEnvMap $poolName @{
  'COR_ENABLE_PROFILING' = '1'
  'COR_PROFILER' = '{918728DD-259F-4A6A-AC2B-B85E1B658318}'
  'COR_PROFILER_PATH' = $otelNative
  'COR_PROFILER_PATH_64' = $otelNative
  'COR_PROFILER_PATH_32' = (Join-Path $moduleDir 'win-x86\OpenTelemetry.AutoInstrumentation.Native.dll')
  'OTEL_DOTNET_AUTO_HOME' = $moduleDir
  'DOTNET_STARTUP_HOOKS' = (Join-Path $moduleDir 'net\OpenTelemetry.AutoInstrumentation.StartupHook.dll')
  'DOTNET_SHARED_STORE' = (Join-Path $moduleDir 'store')
  'DOTNET_ADDITIONAL_DEPS' = (Join-Path $moduleDir 'AdditionalDeps')
  'OTEL_SERVICE_NAME' = 'TrackingApi-EDOT'
  'OTEL_RESOURCE_ATTRIBUTES' = 'deployment.environment=lab,service.version=s5-edot-zero'
  'OTEL_EXPORTER_OTLP_ENDPOINT' = $map['OTEL_EXPORTER_OTLP_ENDPOINT']
  'OTEL_EXPORTER_OTLP_HEADERS' = $map['OTEL_EXPORTER_OTLP_HEADERS']
  'OTEL_EXPORTER_OTLP_PROTOCOL' = 'http/protobuf'
  'OTEL_TRACES_EXPORTER' = 'otlp'
  'OTEL_METRICS_EXPORTER' = 'none'
  'OTEL_LOGS_EXPORTER' = 'none'
  'OTEL_DOTNET_AUTO_TRACES_ADDITIONAL_SOURCES' = 'Contoso.Observability'
  'OTEL_LOG_LEVEL' = 'info'
  'OTEL_DOTNET_AUTO_LOG_DIRECTORY' = $logDir
} @('OTEL_DOTNET_AUTO_PLUGINS','ELASTIC_APM_SERVER_URL','ELASTIC_APM_API_KEY','ELASTIC_APM_PROFILER_HOME')

Set-ItemProperty "IIS:\Sites\$siteApp" -Name applicationPool -Value $poolName

# SharedPool → Elastic APM profiler (explicit PATH_64 so W3SVC leftovers cannot win)
$apm = @{}
if (Test-Path "$env:USERPROFILE\apm.env") {
  Get-Content "$env:USERPROFILE\apm.env" | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
    $i = $_.IndexOf('='); $apm[$_.Substring(0,$i).Trim()] = $_.Substring($i+1).Trim()
  }
}
$profilerHome = 'C:\elastic\apm-agent-dotnet'
$elasticDll = "$profilerHome\elastic_apm_profiler.dll"
if ((Test-Path $elasticDll) -and $apm['ELASTIC_APM_SERVER_URL'] -and $apm['ELASTIC_APM_API_KEY']) {
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
  Write-Output 'SharedPool Elastic profiler re-applied'
}

iisreset /noforce | Out-Null
Start-Sleep 5
Write-Output "EDOT_ZERO_CODE_OK pool=$poolName additional_sources=Contoso.Observability"
Write-Output "endpoint=$($map['OTEL_EXPORTER_OTLP_ENDPOINT'])"
