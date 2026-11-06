$ErrorActionPreference = "Stop"
Unregister-ScheduledTask -TaskName ContosoSqlFinish -Confirm:$false -ErrorAction SilentlyContinue
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File C:\lab\Finish-SqlAndWaitfor.ps1 *> C:\lab\sql-finish-out.txt'
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName ContosoSqlFinish -Action $action -Principal $principal | Out-Null
Start-ScheduledTask -TaskName ContosoSqlFinish
for ($i=0; $i -lt 30; $i++) {
  Start-Sleep 2
  $t = Get-ScheduledTask -TaskName ContosoSqlFinish
  if ($t.State -ne 'Running') { break }
}
Get-ScheduledTask -TaskName ContosoSqlFinish | Format-List TaskName,State
if (Test-Path C:\lab\sql-finish-out.txt) { Get-Content C:\lab\sql-finish-out.txt }
if (Test-Path C:\lab-sql.done) { Get-Content C:\lab-sql.done }
