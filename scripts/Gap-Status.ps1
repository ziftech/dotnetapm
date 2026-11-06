$ErrorActionPreference = "Continue"
$out = "C:\lab-gap-status.txt"
$lines = @()
$lines += "ts=$(Get-Date -Format o)"
$lines += "=== SQL services ==="
Get-Service | Where-Object { $_.Name -match 'SQL|MSSQL' } | ForEach-Object { $lines += "$($_.Name)=$($_.Status)" }
$lines += "=== LocalDB ==="
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
try { $lines += (sqllocaldb info 2>&1 | Out-String) } catch { $lines += "no-sqllocaldb: $($_.Exception.Message)" }
$lines += "=== choco sql ==="
try { $lines += (choco list --local-only 2>&1 | Select-String -Pattern 'sql' | Out-String) } catch { $lines += $_.Exception.Message }
$lines += "=== SQL dirs ==="
if (Test-Path 'C:\Program Files\Microsoft SQL Server') {
  Get-ChildItem 'C:\Program Files\Microsoft SQL Server' | ForEach-Object { $lines += $_.Name }
} else { $lines += "missing SQL Server dir" }
$lines += "=== lab-sql.done ==="
if (Test-Path C:\lab-sql.done) { $lines += (Get-Content C:\lab-sql.done -Raw) } else { $lines += "absent" }
$lines += "=== worker ==="
$p = Get-Process ShipmentsWorker -ErrorAction SilentlyContinue
if ($p) { $lines += "pid=$($p.Id)" } else { $lines += "not-running" }
$lines += "=== elastic-agent ==="
$agent = 'C:\Program Files\Elastic\Agent\elastic-agent.exe'
if (Test-Path $agent) {
  try { $lines += (& $agent status 2>&1 | Select-Object -First 40 | Out-String) } catch { $lines += $_.Exception.Message }
} else { $lines += "agent binary missing" }
$lines += "=== IIS sites ==="
try {
  Import-Module WebAdministration
  Get-Website | ForEach-Object { $lines += "$($_.Name) state=$($_.State) bindings=$($_.bindings.Collection.bindingInformation)" }
} catch { $lines += $_.Exception.Message }
$lines | Set-Content $out
Get-Content $out
