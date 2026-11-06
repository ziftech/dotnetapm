# Coexistence path: profiler handles ASP.NET; NuGet assemblies provide Public API / filters / Fody backend.
# ElasticApmModule + profiler ASP.NET integration caused NullReferenceException storms in agent logs.
$ErrorActionPreference = "Stop"
Import-Module WebAdministration

function Remove-Module([string]$path) {
  [xml]$xml = Get-Content $path -Raw
  $mod = $xml.SelectSingleNode("//system.webServer/modules/add[@name='ElasticApmModule']")
  if ($mod) {
    $mod.ParentNode.RemoveChild($mod) | Out-Null
    $xml.Save($path)
    Write-Output "Removed ElasticApmModule from $path"
  } else {
    Write-Output "No ElasticApmModule in $path"
  }
  $sn = $xml.SelectSingleNode("//appSettings/add[@key='ElasticApm:ServiceName']")
  Write-Output ("ServiceName=" + $(if ($sn) { $sn.GetAttribute('value') } else { '(missing)' }))
}

Remove-Module 'C:\lab\app\ShipmentsWeb\Web.config'
Remove-Module 'C:\lab\app\TrackingApi\Web.config'

# Ensure profiler deps resolvable: unblock and confirm Unsafe present
Get-ChildItem C:\elastic\apm-agent-dotnet -Recurse -Include *.dll | Unblock-File -ErrorAction SilentlyContinue
if (-not (Test-Path 'C:\elastic\apm-agent-dotnet\net472\System.Runtime.CompilerServices.Unsafe.dll')) {
  Copy-Item 'C:\elastic\apm-agent-dotnet-full\8.0.0\System.Runtime.CompilerServices.Unsafe.dll' 'C:\elastic\apm-agent-dotnet\net472\' -Force
}

# Clear pool-level service name; keep profiler env
$filterBase = "system.applicationHost/applicationPools/add[@name='SharedPool']/environmentVariables"
$pspath = 'MACHINE/WEBROOT/APPHOST'
Remove-WebConfigurationProperty -pspath $pspath -filter $filterBase -name "." -AtElement @{name='ELASTIC_APM_SERVICE_NAME'} -ErrorAction SilentlyContinue

Stop-WebAppPool SharedPool
Start-Sleep 4
# kill leftover w3wp
Get-Process w3wp -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep 2
Start-WebAppPool SharedPool
Start-Sleep 5
Write-Output ("pool=" + (Get-WebAppPoolState SharedPool).Value)
try { Write-Output ("web=" + (Invoke-WebRequest http://127.0.0.1/web/ -UseBasicParsing -TimeoutSec 20).StatusCode) } catch { Write-Output $_.Exception.Message }
try { Write-Output ("api=" + (Invoke-WebRequest http://127.0.0.1/tracking/api/tracking/coex1 -UseBasicParsing -TimeoutSec 20).StatusCode) } catch { Write-Output $_.Exception.Message }
