# Build weave modes and note stage markers for the remote k6 driver.
param(
  [ValidateSet('B0','S1','narrow','broad')]
  [string]$Stage
)
$ErrorActionPreference = 'Stop'
$root = 'C:\lab\src'
Import-Module WebAdministration

function Set-Profiler([bool]$on) {
  $filterBase = "system.applicationHost/applicationPools/add[@name='SharedPool']/environmentVariables"
  # Keep existing URL/key; toggle COR_ENABLE_PROFILING
  $val = if ($on) { '1' } else { '0' }
  & "$env:windir\system32\inetsrv\appcmd.exe" set config -section:system.applicationHost/applicationPools "/[$filterBase].[name='COR_ENABLE_PROFILING'].value:$val" /commit:apphost | Out-Null
}

switch ($Stage) {
  'B0' {
    & "$root\scripts\Run-Overhead10m.ps1" -WeaveMode none
    Set-Profiler $false
  }
  'S1' {
    & "$root\scripts\Run-Overhead10m.ps1" -WeaveMode none
    Set-Profiler $true
  }
  'narrow' {
    & "$root\scripts\Run-Overhead10m.ps1" -WeaveMode narrow
    Set-Profiler $true
  }
  'broad' {
    & "$root\scripts\Run-Overhead10m.ps1" -WeaveMode broad
    Set-Profiler $true
  }
}

Restart-WebAppPool SharedPool
Start-Sleep 5
# warm
cmd /c "curl -sS -o NUL http://127.0.0.1/web/"
cmd /c "curl -sS -o NUL http://127.0.0.1/tracking/api/tracking/warmup"
Write-Output "STAGE_READY=$Stage"
Write-Output ("COR_ENABLE_PROFILING=" + ((& "$env:windir\system32\inetsrv\appcmd.exe" list config -section:system.applicationHost/applicationPools) | Select-String 'COR_ENABLE_PROFILING' | Select-Object -First 1))
