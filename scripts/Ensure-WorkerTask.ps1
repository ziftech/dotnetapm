# Register ShipmentsWorker as a scheduled task so it survives SSH sessions.
$ErrorActionPreference = "Stop"
$dir = 'C:\lab\app\ShipmentsWorker'
$exe = Join-Path $dir 'ShipmentsWorker.exe'
$bat = 'C:\lab\logs\start-worker.bat'
if (-not (Test-Path $bat)) { throw "missing $bat - run Start-WorkerFromEnv.ps1 first" }

Get-Process ShipmentsWorker -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
Unregister-ScheduledTask -TaskName 'ContosoShipmentsWorker' -Confirm:$false -ErrorAction SilentlyContinue

$action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument "/c `"$bat`"" -WorkingDirectory $dir
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName 'ContosoShipmentsWorker' -Action $action -Trigger $trigger -Principal $principal -Settings $settings | Out-Null
Start-ScheduledTask -TaskName 'ContosoShipmentsWorker'
Start-Sleep 5
$w = Get-Process ShipmentsWorker -ErrorAction SilentlyContinue
if ($w) { Write-Output "TASK_OK pid=$($w.Id)" } else {
  Write-Output "TASK_STARTED_BUT_NO_PROCESS"
  Get-Content C:\lab\logs\worker-out.txt -Tail 20 -ErrorAction SilentlyContinue
  Get-Content C:\lab\logs\worker-err.txt -Tail 20 -ErrorAction SilentlyContinue
}
Get-ScheduledTask -TaskName 'ContosoShipmentsWorker' | Format-List TaskName,State
