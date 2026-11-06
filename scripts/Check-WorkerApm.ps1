$ErrorActionPreference = "Continue"
Write-Output "=== process ==="
Get-Process ShipmentsWorker -EA SilentlyContinue | Format-List Id,ProcessName,StartTime,Path
Write-Output "=== task ==="
Get-ScheduledTask -TaskName ContosoShipmentsWorker -EA SilentlyContinue | Format-List TaskName,State
Write-Output "=== bat (redacted) ==="
if (Test-Path C:\lab\logs\start-worker.bat) {
  Get-Content C:\lab\logs\start-worker.bat | ForEach-Object {
    if ($_ -match 'API_KEY') { ($_ -replace '=.*','=***') } else { $_ }
  }
}
Write-Output "=== out/err ==="
if (Test-Path C:\lab\logs\worker-out.txt) { Get-Content C:\lab\logs\worker-out.txt -Tail 60 }
if (Test-Path C:\lab\logs\worker-err.txt) { Get-Content C:\lab\logs\worker-err.txt -Tail 60 }
Write-Output "=== app log files ==="
Get-ChildItem C:\lab\logs -ErrorAction SilentlyContinue | Format-Table Name,Length,LastWriteTime -AutoSize
Write-Output "=== sql install ==="
Get-ScheduledTask -TaskName ContosoSqlInstall -EA SilentlyContinue | Format-List TaskName,State
if (Test-Path C:\lab-sql-choco.log) { Get-Content C:\lab-sql-choco.log -Tail 30 }
Get-Service | Where-Object { $_.Name -match 'SQL' } | ForEach-Object { Write-Output "$($_.Name)=$($_.Status)" }
