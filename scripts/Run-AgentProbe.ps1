$ErrorActionPreference = 'Continue'
Copy-Item 'C:\lab\src\scripts\agentprobe.ashx' 'C:\lab\app\TrackingApi\agentprobe.ashx' -Force
Copy-Item 'C:\lab\src\scripts\agentprobe.ashx' 'C:\lab\app\ShipmentsWeb\agentprobe.ashx' -Force
Import-Module WebAdministration
Restart-WebAppPool SharedPool
Start-Sleep 5
Write-Output '=== tracking probe (cold) ==='
cmd /c 'curl -sS http://127.0.0.1/tracking/agentprobe.ashx'
Write-Output ''
Write-Output '=== tracking api then probe ==='
cmd /c 'curl -sS -o NUL http://127.0.0.1/tracking/api/tracking/probe1'
cmd /c 'curl -sS http://127.0.0.1/tracking/agentprobe.ashx'
Write-Output ''
Write-Output '=== web probe ==='
cmd /c 'curl -sS http://127.0.0.1/web/agentprobe.ashx'
Write-Output ''
Write-Output '=== profiler Elastic.Apm.dll ==='
Get-ChildItem 'C:\elastic\apm-agent-dotnet' -Recurse -Filter 'Elastic.Apm.dll' -EA SilentlyContinue |
  ForEach-Object { Write-Output ($_.FullName + ' ' + [Reflection.AssemblyName]::GetAssemblyName($_.FullName).Version) }
Write-Output '=== app bin Elastic.Apm.dll ==='
foreach ($p in @('C:\lab\app\TrackingApi\bin\Elastic.Apm.dll','C:\lab\app\ShipmentsWeb\bin\Elastic.Apm.dll')) {
  if (Test-Path $p) { Write-Output ($p + ' ' + [Reflection.AssemblyName]::GetAssemblyName($p).Version) }
}
Get-Content 'C:\elastic\apm-agent-dotnet\version.txt' -EA SilentlyContinue
