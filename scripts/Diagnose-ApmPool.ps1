$ErrorActionPreference = "Continue"
Write-Output "=== Profiler files ==="
Get-ChildItem C:\elastic\apm-agent-dotnet -ErrorAction SilentlyContinue | Format-Table Name, Length -AutoSize | Out-String | Write-Output

Write-Output "=== SharedPool env (names; secrets redacted) ==="
Import-Module WebAdministration
$pool = Get-Item 'IIS:\AppPools\SharedPool'
$cols = $pool.GetCollection('environmentVariables')
if ($cols.Count -eq 0) { Write-Output "(no environmentVariables)" }
foreach ($c in $cols) {
  $n = $c.GetAttributeValue('name')
  $v = $c.GetAttributeValue('value')
  if ($n -match 'KEY|SECRET|PASSWORD|TOKEN') { $v = '***len=' + $v.Length }
  Write-Output ("ENV {0}={1}" -f $n, $v)
}

Write-Output "=== w3wp ==="
Get-Process w3wp -ErrorAction SilentlyContinue | Format-Table Id, CPU, WorkingSet64 -AutoSize | Out-String | Write-Output

Write-Output "=== profiler log candidates ==="
$paths = @(
  'C:\elastic\apm-agent-dotnet',
  'C:\Windows\Temp',
  'C:\lab\logs',
  "$env:ProgramData\elastic"
)
foreach ($p in $paths) {
  if (Test-Path $p) {
    Get-ChildItem $p -Recurse -Include *.log,*.txt -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -match 'elastic|apm|profiler' } |
      Select-Object -First 15 FullName, Length, LastWriteTime |
      Format-Table -AutoSize | Out-String | Write-Output
  }
}

Write-Output "=== local HTTP ==="
try { Write-Output ("web=" + (Invoke-WebRequest http://127.0.0.1/web/ -UseBasicParsing -TimeoutSec 15).StatusCode) } catch { Write-Output ("web ERR " + $_.Exception.Message) }
try { Write-Output ("api=" + (Invoke-WebRequest http://127.0.0.1/tracking/api/tracking/diag1 -UseBasicParsing -TimeoutSec 15).StatusCode) } catch { Write-Output ("api ERR " + $_.Exception.Message) }
