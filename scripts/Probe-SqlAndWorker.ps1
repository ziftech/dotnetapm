$ErrorActionPreference = "Continue"
Write-Output "=== SQL Server tree (depth 2) ==="
Get-ChildItem 'C:\Program Files\Microsoft SQL Server' -ErrorAction SilentlyContinue | ForEach-Object {
  Write-Output $_.FullName
  Get-ChildItem $_.FullName -ErrorAction SilentlyContinue | Select-Object -First 20 | ForEach-Object { Write-Output ("  " + $_.Name) }
}
Write-Output "=== find sqlcmd/sqllocaldb ==="
Get-ChildItem 'C:\Program Files\Microsoft SQL Server' -Recurse -Include sqlcmd.exe,sqllocaldb.exe -ErrorAction SilentlyContinue |
  Select-Object -ExpandProperty FullName
Write-Output "=== worker log / err ==="
if (Test-Path C:\lab\worker.out.log) { Get-Content C:\lab\worker.out.log -Tail 40 }
if (Test-Path C:\lab\worker.err.log) { Get-Content C:\lab\worker.err.log -Tail 40 }
Get-ChildItem C:\lab\*.log -ErrorAction SilentlyContinue | Select-Object Name,Length,LastWriteTime
Write-Output "=== choco ==="
Get-Command choco -ErrorAction SilentlyContinue | Format-List
if (Get-Command choco -ErrorAction SilentlyContinue) { choco --version }
