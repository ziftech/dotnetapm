$ErrorActionPreference = "Continue"
Write-Output "=== IIS ==="
Import-Module WebAdministration
Get-Website | Select-Object Name, State, PhysicalPath | Format-Table -AutoSize | Out-String | Write-Output
Get-WebApplication -Site Shipments | Select-Object Path, ApplicationPool, PhysicalPath | Format-Table -AutoSize | Out-String | Write-Output
Write-Output "SharedPool state: $((Get-Item IIS:\AppPools\SharedPool).State)"

Write-Output "=== Worker ==="
Get-Process ShipmentsWorker -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
$exe = "C:\lab\app\ShipmentsWorker\ShipmentsWorker.exe"
if (Test-Path $exe) {
  Start-Process $exe -WorkingDirectory "C:\lab\app\ShipmentsWorker" -WindowStyle Hidden
  Start-Sleep 2
  $p = Get-Process ShipmentsWorker -ErrorAction SilentlyContinue
  if ($p) { Write-Output "WORKER_RUNNING pid=$($p.Id)" } else { Write-Output "WORKER_NOT_RUNNING" }
} else {
  Write-Output "WORKER_EXE_MISSING"
}

Write-Output "=== SQL ==="
Get-Service | Where-Object { $_.Name -match 'SQL' } | ForEach-Object { Write-Output ("SERVICE {0}={1}" -f $_.Name, $_.Status) }
$sx = Get-Service 'MSSQL$SQLEXPRESS' -ErrorAction SilentlyContinue
Write-Output ("SQLEXPRESS_PRESENT={0}" -f [bool]$sx)

Write-Output "=== Done markers ==="
Write-Output ("lab-setup.done={0}" -f (Test-Path C:\lab-setup.done))
Write-Output ("lab-phase2.done={0}" -f (Test-Path C:\lab-phase2.done))
Write-Output ("lab-phase2-iis-fixed.done={0}" -f (Test-Path C:\lab-phase2-iis-fixed.done))
