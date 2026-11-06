# Configure SharedPool APM env vars. Modes: none | profiler | profiler-named | clear
param(
  [ValidateSet('none','profiler','profiler-named','clear')]
  [string]$Mode = 'profiler',
  [string]$ProfilerHome = 'C:\elastic\apm-agent-dotnet',
  [string]$ServerUrl = '',
  [string]$ApiKey = '',
  [string]$ServiceName = '',
  [string]$LogDir = 'C:\ProgramData\elastic\apm-agent-dotnet\logs'
)
$ErrorActionPreference = "Stop"
Import-Module WebAdministration

$filterBase = "system.applicationHost/applicationPools/add[@name='SharedPool']/environmentVariables"
$pspath = 'MACHINE/WEBROOT/APPHOST'

function Clear-PoolEnv {
  # Remove the whole environmentVariables collection entries
  $existing = Get-WebConfigurationProperty -pspath $pspath -filter $filterBase -name "." -ErrorAction SilentlyContinue
  if ($null -ne $existing) {
    Clear-WebConfiguration -pspath $pspath -filter $filterBase -ErrorAction SilentlyContinue
  }
  # Also clear known names individually (idempotent)
  $names = @(
    'COR_ENABLE_PROFILING','COR_PROFILER','COR_PROFILER_PATH',
    'CORECLR_ENABLE_PROFILING','CORECLR_PROFILER','CORECLR_PROFILER_PATH',
    'ELASTIC_APM_PROFILER_HOME','ELASTIC_APM_PROFILER_INTEGRATIONS',
    'ELASTIC_APM_SERVER_URL','ELASTIC_APM_SECRET_TOKEN','ELASTIC_APM_API_KEY','ELASTIC_APM_SERVICE_NAME',
    'ELASTIC_APM_ENVIRONMENT','ELASTIC_APM_APPLICATION_NAMESPACES',
    'ELASTIC_APM_SPAN_STACK_TRACE_MIN_DURATION','COMPlus_LoaderOptimization',
    'OTEL_LOG_LEVEL','ELASTIC_APM_PROFILER_LOG','ELASTIC_APM_PROFILER_LOG_DIR',
    'ELASTIC_APM_SERVICE_VERSION','ELASTIC_APM_VERIFY_SERVER_CERT'
  )
  foreach ($n in $names) {
    Remove-WebConfigurationProperty -pspath $pspath -filter $filterBase -name "." -AtElement @{name=$n} -ErrorAction SilentlyContinue
  }
}

function Set-PoolEnv([string]$Name, [string]$Value) {
  Remove-WebConfigurationProperty -pspath $pspath -filter $filterBase -name "." -AtElement @{name=$Name} -ErrorAction SilentlyContinue
  Add-WebConfigurationProperty -pspath $pspath -filter $filterBase -name "." -value @{name=$Name; value=$Value}
}

Clear-PoolEnv

if ($Mode -eq 'clear' -or $Mode -eq 'none') {
  Write-Output "Cleared APM env on SharedPool"
} else {
  if (-not (Test-Path "$ProfilerHome\elastic_apm_profiler.dll")) { throw "Profiler DLL missing at $ProfilerHome" }
  if (-not $ServerUrl) { throw "ServerUrl required" }
  if (-not $ApiKey) { throw "ApiKey required" }

  New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

  Set-PoolEnv 'COR_ENABLE_PROFILING' '1'
  Set-PoolEnv 'COR_PROFILER' '{FA65FE15-F085-4681-9B20-95E04F6C03CC}'
  Set-PoolEnv 'COR_PROFILER_PATH' "$ProfilerHome\elastic_apm_profiler.dll"
  Set-PoolEnv 'ELASTIC_APM_PROFILER_HOME' $ProfilerHome
  Set-PoolEnv 'ELASTIC_APM_PROFILER_INTEGRATIONS' "$ProfilerHome\integrations.yml"
  Set-PoolEnv 'COMPlus_LoaderOptimization' '1'
  Set-PoolEnv 'ELASTIC_APM_SERVER_URL' $ServerUrl
  Set-PoolEnv 'ELASTIC_APM_API_KEY' $ApiKey
  Set-PoolEnv 'ELASTIC_APM_ENVIRONMENT' 'lab'
  Set-PoolEnv 'ELASTIC_APM_PROFILER_LOG' 'info'
  Set-PoolEnv 'ELASTIC_APM_PROFILER_LOG_DIR' $LogDir
  # Profiler reads these from env (Web.config alone is not enough for stack frame classification).
  Set-PoolEnv 'ELASTIC_APM_APPLICATION_NAMESPACES' 'Contoso.'
  Set-PoolEnv 'ELASTIC_APM_SPAN_STACK_TRACE_MIN_DURATION' '0ms'
  if ($Mode -eq 'profiler-named' -and $ServiceName) {
    Set-PoolEnv 'ELASTIC_APM_SERVICE_NAME' $ServiceName
  }
  Write-Output "Configured SharedPool mode=$Mode serverHost=$(([Uri]$ServerUrl).Host) apiKeyLen=$($ApiKey.Length)"
}

$poolState = (Get-WebAppPoolState -Name SharedPool).Value
if ($poolState -eq 'Stopped') { Start-WebAppPool SharedPool } else { Restart-WebAppPool SharedPool }
Start-Sleep 4
Write-Output "Pool state=$((Get-WebAppPoolState -Name SharedPool).Value)"
Write-Output "Env names now:"
Get-WebConfigurationProperty -pspath $pspath -filter $filterBase -name "." | ForEach-Object {
  $n = $_.name; $v = $_.value
  if ($n -match 'KEY|SECRET') { Write-Output ("  {0}=***len={1}" -f $n, $v.Length) }
  else { Write-Output ("  {0}={1}" -f $n, $v) }
}
