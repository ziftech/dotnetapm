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
# S2 = profiler + NuGet module + per-app names + woven business DLL (already built)
& C:\lab\Apply-LabStage.ps1 -Stage S2 -PerAppNames -EnableNuGetModule -ServerUrl $map['ELASTIC_APM_SERVER_URL'] -ApiKey $map['ELASTIC_APM_API_KEY']
& C:\lab\Configure-ApmPool.ps1 -Mode profiler -ServerUrl $map['ELASTIC_APM_SERVER_URL'] -ApiKey $map['ELASTIC_APM_API_KEY']
Import-Module WebAdministration
$filterBase = "system.applicationHost/applicationPools/add[@name='SharedPool']/environmentVariables"
$pspath = 'MACHINE/WEBROOT/APPHOST'
function Set-PoolEnv([string]$Name, [string]$Value) {
  Remove-WebConfigurationProperty -pspath $pspath -filter $filterBase -name "." -AtElement @{name=$Name} -ErrorAction SilentlyContinue
  Add-WebConfigurationProperty -pspath $pspath -filter $filterBase -name "." -value @{name=$Name; value=$Value}
}
Set-PoolEnv 'ELASTIC_APM_APPLICATION_NAMESPACES' 'Contoso.'
Set-PoolEnv 'ELASTIC_APM_SPAN_STACK_TRACE_MIN_DURATION' '0ms'
Remove-WebConfigurationProperty -pspath $pspath -filter $filterBase -name "." -AtElement @{name='ELASTIC_APM_SERVICE_NAME'} -ErrorAction SilentlyContinue
# Hard recycle
Stop-WebAppPool SharedPool
Start-Sleep 3
Start-WebAppPool SharedPool
Start-Sleep 5
Remove-Item -Force $EnvFile -ErrorAction SilentlyContinue
Write-Output "S2 remote apply complete"
# Confirm module present
Select-String -Path C:\lab\app\ShipmentsWeb\Web.config,C:\lab\app\TrackingApi\Web.config -Pattern 'ElasticApmModule|ServiceName' |
  ForEach-Object { $_.Line.Trim() }
