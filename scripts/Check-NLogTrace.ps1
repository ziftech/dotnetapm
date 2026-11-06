$ErrorActionPreference = 'Continue'
cmd /c 'curl -sS -o NUL http://127.0.0.1/tracking/api/tracking/NLOGTEST2'
Start-Sleep 1
Write-Output '=== text log ==='
Select-String -Path 'C:\lab\logs\tracking-api.log' -Pattern 'NLOGTEST2' | Select-Object -Last 2 | ForEach-Object { $_.Line }
Write-Output '=== ecs json last lines with NLOGTEST2 or trace ==='
Get-Content 'C:\lab\logs\tracking-api-ecs.json' -Tail 5 -EA SilentlyContinue
Write-Output '=== reflect ThreadSafe on renderer ==='
Add-Type -Path 'C:\lab\app\TrackingApi\bin\Elastic.Apm.NLog.dll'
$t = [Elastic.Apm.NLog.ApmTraceIdLayoutRenderer]
$t.GetCustomAttributes($false) | ForEach-Object { Write-Output $_.GetType().FullName }
Write-Output ('Assembly=' + $t.Assembly.FullName)
