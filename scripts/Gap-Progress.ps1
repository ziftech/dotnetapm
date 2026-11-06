$ErrorActionPreference = "Continue"
Write-Output "worker=$((Get-Process ShipmentsWorker -EA SilentlyContinue).Id)"
Write-Output "=== SQL services ==="
Get-Service | Where-Object { $_.Name -match 'SQL|MSSQL' } | ForEach-Object { Write-Output "$($_.Name)=$($_.Status)" }
Write-Output "=== lab-sql.done ==="
if (Test-Path C:\lab-sql.done) { Get-Content C:\lab-sql.done } else { Write-Output absent }
Write-Output "=== choco log tail ==="
if (Test-Path C:\lab-sql-choco.log) { Get-Content C:\lab-sql-choco.log -Tail 50 } else { Write-Output 'no choco log yet' }
Write-Output "=== install processes ==="
Get-Process | Where-Object { $_.ProcessName -match 'choco|msiexec|sql|Setup|powershell' } |
  Select-Object -First 20 Name,Id | Format-Table -AutoSize | Out-String | Write-Output
Write-Output "=== worker logs ==="
if (Test-Path C:\lab\logs\worker-out.txt) { Get-Content C:\lab\logs\worker-out.txt -Tail 40 }
if (Test-Path C:\lab\logs\worker-err.txt) { Get-Content C:\lab\logs\worker-err.txt -Tail 40 }
Write-Output "=== log4net/nlog paths ==="
Get-ChildItem C:\lab\app -Recurse -Include *.log -ErrorAction SilentlyContinue | Select-Object -First 20 FullName,Length,LastWriteTime
Get-ChildItem C:\inetpub\logs -Recurse -ErrorAction SilentlyContinue | Select-Object -First 5 FullName
