$ErrorActionPreference = "Continue"
Get-ScheduledTask -TaskName ContosoSqlInstall -EA SilentlyContinue | Format-List TaskName,State
Get-Process | Where-Object { $_.ProcessName -match 'choco|msiexec|setup|SQL|powershell' } | Format-Table Name,Id,CPU -AutoSize
if (Test-Path C:\lab-sql-choco.log) { Get-Content C:\lab-sql-choco.log -Tail 40 }
Get-Service | Where-Object { $_.Name -match 'SQL' } | ForEach-Object { Write-Output "$($_.Name)=$($_.Status)" }
Get-ChildItem 'C:\ProgramData\chocolatey\lib\sql-server-express' -ErrorAction SilentlyContinue | Select-Object Name
Get-ChildItem 'C:\ProgramData\chocolatey\lib-bad' -ErrorAction SilentlyContinue | Select-Object Name
if (Test-Path C:\lab-sql.done) { Get-Content C:\lab-sql.done }
