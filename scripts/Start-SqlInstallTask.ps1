$ErrorActionPreference = "Stop"
$script = 'C:\lab\Install-SqlExpress-Choco.ps1'
if (-not (Test-Path $script)) { throw "missing $script" }
Unregister-ScheduledTask -TaskName 'ContosoSqlInstall' -Confirm:$false -ErrorAction SilentlyContinue
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$script`""
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName 'ContosoSqlInstall' -Action $action -Principal $principal -Settings $settings | Out-Null
Start-ScheduledTask -TaskName 'ContosoSqlInstall'
Start-Sleep 3
Get-ScheduledTask -TaskName 'ContosoSqlInstall' | Format-List TaskName,State
Write-Output "SQL_INSTALL_TASK_STARTED"
