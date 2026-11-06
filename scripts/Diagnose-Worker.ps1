$ErrorActionPreference = "Continue"
Write-Output "=== process ==="
Get-Process ShipmentsWorker -ErrorAction SilentlyContinue | Format-Table Id,StartTime,CPU,WorkingSet64 | Out-String | Write-Output
Write-Output "=== recent apm logs ==="
Get-ChildItem C:\ProgramData\elastic\apm-agent-dotnet\logs -ErrorAction SilentlyContinue |
  Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-15) } |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 20 Name, Length, LastWriteTime |
  Format-Table -AutoSize | Out-String | Write-Output
Write-Output "=== configs ==="
Get-ChildItem C:\lab\app\ShipmentsWorker | Format-Table Name,Length | Out-String | Write-Output
foreach ($f in @('C:\lab\app\ShipmentsWorker\ShipmentsWorker.exe.config','C:\lab\app\ShipmentsWorker\App.config')) {
  if (Test-Path $f) {
    Write-Output "FILE $f"
    Get-Content $f | Write-Output
  }
}
# set interval 5
$path = 'C:\lab\app\ShipmentsWorker\ShipmentsWorker.exe.config'
if (-not (Test-Path $path)) { $path = 'C:\lab\app\ShipmentsWorker\App.config' }
if (Test-Path $path) {
  [xml]$xml = Get-Content $path
  $n = $xml.SelectSingleNode("//appSettings/add[@key='IntervalSeconds']")
  if ($n) { $n.SetAttribute('value','5'); $xml.Save($path); Write-Output "set IntervalSeconds=5 in $path" }
}
