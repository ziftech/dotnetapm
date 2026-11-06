$ErrorActionPreference = 'Continue'
Write-Output '=== Elastic.Apm versions (profiler vs app bin) ==='
$paths = @(
  'C:\lab\app\TrackingApi\bin\Elastic.Apm.dll',
  'C:\lab\app\ShipmentsWeb\bin\Elastic.Apm.dll'
)
Get-ChildItem 'C:\elastic\apm-agent-dotnet' -Recurse -Filter 'Elastic.Apm.dll' -EA SilentlyContinue |
  ForEach-Object { $paths += $_.FullName }
$paths | Select-Object -Unique | ForEach-Object {
  if (Test-Path $_) {
    $v = [Reflection.AssemblyName]::GetAssemblyName($_).Version
    Write-Output "$_ => $v"
  }
}

Write-Output '=== Agent assemblies via probe ==='
Copy-Item 'C:\lab\src\scripts\agentprobe.ashx' 'C:\lab\app\TrackingApi\agentprobe.ashx' -Force
Import-Module WebAdministration
Restart-WebAppPool SharedPool
Start-Sleep 6
cmd /c 'curl -sS -o NUL http://127.0.0.1/tracking/api/tracking/nlogwarm'
cmd /c 'curl -sS http://127.0.0.1/tracking/agentprobe.ashx'
Write-Output ''

$id = 'NLOGFIX-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
cmd /c "curl -sS -o NUL -w nlog_http=%{http_code} http://127.0.0.1/tracking/api/tracking/$id"
Write-Output ''
Start-Sleep 2
Write-Output '=== last matching tracking-api.log lines ==='
Select-String -Path 'C:\lab\logs\tracking-api.log' -Pattern $id | Select-Object -Last 5 | ForEach-Object { $_.Line }

$line = Select-String -Path 'C:\lab\logs\tracking-api.log' -Pattern $id | Select-Object -Last 1
if (-not $line) { throw "no log line for $id" }
if ($line.Line -notmatch 'trace\.id=([0-9a-f]{32})') { throw "EMPTY ContosoApmTraceId for $id :: $($line.Line)" }
Write-Output "NLOG_TRACE_OK id=$id trace=$($Matches[1])"
