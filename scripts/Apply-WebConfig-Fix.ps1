$ErrorActionPreference = "Stop"
$src = Join-Path $env:USERPROFILE "ShipmentsWeb.Web.config"
if (-not (Test-Path $src)) { throw "Missing $src" }
Copy-Item $src "C:\lab\app\ShipmentsWeb\Web.config" -Force
Import-Module WebAdministration
Restart-WebAppPool SharedPool
Start-Sleep -Seconds 4
try {
  $r = Invoke-WebRequest -UseBasicParsing "http://127.0.0.1/web/" -TimeoutSec 30
  Write-Output "LOCAL_WEB=$($r.StatusCode)"
} catch {
  Write-Output "LOCAL_WEB_FAIL $($_.Exception.Message)"
}
try {
  $r = Invoke-WebRequest -UseBasicParsing "http://127.0.0.1/tracking/api/tracking/CTR-DEMO01" -TimeoutSec 30
  Write-Output "LOCAL_API=$($r.StatusCode)"
} catch {
  Write-Output "LOCAL_API_FAIL $($_.Exception.Message)"
}
