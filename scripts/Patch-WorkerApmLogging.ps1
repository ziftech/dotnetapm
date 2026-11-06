# Enable Elastic APM agent file logging and force a CaptureTransaction test path.
$ErrorActionPreference = "Stop"
$bat = 'C:\lab\logs\start-worker.bat'
$lines = Get-Content $bat
# Insert APM log dir env if missing
if ($lines -notcontains 'set ELASTIC_APM_LOG_DIRECTORY=C:\lab\logs\apm-agent') {
  $new = @()
  foreach ($l in $lines) {
    if ($l -match '^set ELASTIC_APM_LOG_LEVEL=') {
      $new += 'set ELASTIC_APM_LOG_DIRECTORY=C:\lab\logs\apm-agent'
      $new += 'set ELASTIC_APM_LOG_LEVEL=Debug'
      $new += 'set ELASTIC_APM_FLUSH_INTERVAL=1s'
      $new += 'set ELASTIC_APM_TRANSACTION_SAMPLE_RATE=1'
    } elseif ($l -match '^set ELASTIC_APM_LOG_LEVEL=') {
      continue
    } else {
      $new += $l
    }
  }
  # simpler rewrite from known template preserved in bat
  $url = ($lines | Where-Object { $_ -match '^set ELASTIC_APM_SERVER_URL=' })
  $key = ($lines | Where-Object { $_ -match '^set ELASTIC_APM_API_KEY=' })
  $content = @"
@echo off
$url
$key
set ELASTIC_APM_SERVICE_NAME=ShipmentsWorker
set ELASTIC_APM_ENVIRONMENT=lab
set ELASTIC_APM_APPLICATION_NAMESPACES=Contoso.
set ELASTIC_APM_ENABLED=true
set ELASTIC_APM_LOG_LEVEL=Debug
set ELASTIC_APM_LOG_DIRECTORY=C:\lab\logs\apm-agent
set ELASTIC_APM_FLUSH_INTERVAL=1s
set ELASTIC_APM_TRANSACTION_SAMPLE_RATE=1
cd /d "C:\lab\app\ShipmentsWorker"
"C:\lab\app\ShipmentsWorker\ShipmentsWorker.exe" >> "C:\lab\logs\worker-out.txt" 2>> "C:\lab\logs\worker-err.txt"
"@
  New-Item -ItemType Directory -Force -Path C:\lab\logs\apm-agent | Out-Null
  Set-Content -Path $bat -Value $content -Encoding ASCII
}
Get-Process ShipmentsWorker -EA SilentlyContinue | Stop-Process -Force
Start-ScheduledTask -TaskName ContosoShipmentsWorker
Start-Sleep 8
Write-Output "worker=$((Get-Process ShipmentsWorker -EA SilentlyContinue).Id)"
Start-Sleep 15
Write-Output "=== apm agent logs ==="
Get-ChildItem C:\lab\logs\apm-agent -ErrorAction SilentlyContinue | Format-Table Name,Length
Get-ChildItem C:\lab\logs\apm-agent -ErrorAction SilentlyContinue | ForEach-Object {
  Write-Output "--- $($_.Name) ---"
  Get-Content $_.FullName -Tail 80
}
