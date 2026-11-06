param(
  [string]$EnvFile = "$env:USERPROFILE\apm-secrets.env"
)
$ErrorActionPreference = "Stop"
$map = @{}
Get-Content $EnvFile | ForEach-Object {
  if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
  $i = $_.IndexOf('=')
  $map[$_.Substring(0, $i).Trim()] = $_.Substring($i + 1).Trim()
}
& C:\lab\Apply-LabStage.ps1 -Stage S1 -PerAppNames -ServerUrl $map['ELASTIC_APM_SERVER_URL'] -ApiKey $map['ELASTIC_APM_API_KEY']
& C:\lab\Configure-ApmPool.ps1 -Mode profiler -ServerUrl $map['ELASTIC_APM_SERVER_URL'] -ApiKey $map['ELASTIC_APM_API_KEY']
# Add stacktrace settings on pool
Import-Module WebAdministration
$filterBase = "system.applicationHost/applicationPools/add[@name='SharedPool']/environmentVariables"
$pspath = 'MACHINE/WEBROOT/APPHOST'
function Set-PoolEnv([string]$Name, [string]$Value) {
  Remove-WebConfigurationProperty -pspath $pspath -filter $filterBase -name "." -AtElement @{name=$Name} -ErrorAction SilentlyContinue
  Add-WebConfigurationProperty -pspath $pspath -filter $filterBase -name "." -value @{name=$Name; value=$Value}
}
Set-PoolEnv 'ELASTIC_APM_APPLICATION_NAMESPACES' 'Contoso.'
Set-PoolEnv 'ELASTIC_APM_SPAN_STACK_TRACE_MIN_DURATION' '0ms'
# Ensure pool-level service name is absent for S1 per-app proof
Remove-WebConfigurationProperty -pspath $pspath -filter $filterBase -name "." -AtElement @{name='ELASTIC_APM_SERVICE_NAME'} -ErrorAction SilentlyContinue
Restart-WebAppPool SharedPool
Remove-Item -Force $EnvFile -ErrorAction SilentlyContinue
Write-Output "S1 remote apply complete"
Get-WebConfigurationProperty -pspath $pspath -filter $filterBase -name "." | ForEach-Object {
  $n=$_.name; $v=$_.value
  if ($n -match 'KEY|SECRET') { "ENV $n=***len=$($v.Length)" } else { "ENV $n=$v" }
}
