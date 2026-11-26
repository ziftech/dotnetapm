$ErrorActionPreference = 'Continue'
Import-Module WebAdministration
Add-Type -AssemblyName 'Microsoft.Web.Administration, Version=7.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35'

function Show-PoolEnv([string]$poolName) {
  Write-Output "--- pool $poolName ---"
  $sm = New-Object Microsoft.Web.Administration.ServerManager
  $pool = $sm.ApplicationPools[$poolName]
  if (-not $pool) { Write-Output 'MISSING'; return }
  $envColl = $pool.GetCollection('environmentVariables')
  foreach ($e in $envColl) {
    $n = $e.GetAttributeValue('name')
    $v = $e.GetAttributeValue('value')
    if ($n -match 'KEY|SECRET|HEADERS') { Write-Output ("  {0}=***len={1}" -f $n, ($v | Measure-Object -Character).Characters) }
    else { Write-Output ("  {0}={1}" -f $n, $v) }
  }
}

Show-PoolEnv 'SharedPool'
Show-PoolEnv 'TrackingEdotPool'

# Generate traffic
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' -and $_.PrefixOrigin -ne 'WellKnown' } | Select-Object -First 1).IPAddress
$base = "http://127.0.0.1"
Write-Output "Hitting $base"
try {
  $r1 = Invoke-WebRequest "$base/web/" -UseBasicParsing -TimeoutSec 30
  Write-Output ("WEB_HOME={0}" -f $r1.StatusCode)
} catch { Write-Output ("WEB_HOME_ERR={0}" -f $_.Exception.Message) }

$tid = 'CTR-SIX' + (Get-Date -Format 'HHmmss')
try {
  $body = "trackingId=$tid&lane=DXB-AMM&weightKg=5"
  $r2 = Invoke-WebRequest "$base/web/Checkout" -Method POST -Body $body -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing -TimeoutSec 120
  Write-Output ("CHECKOUT={0} tid={1} len={2}" -f $r2.StatusCode, $tid, $r2.Content.Length)
  if ($r2.Content -match 'VB enrich') { Write-Output 'CHECKOUT_VB_OK' }
} catch { Write-Output ("CHECKOUT_ERR={0}" -f $_.Exception.Message) }

try {
  $r3 = Invoke-WebRequest "$base/tracking/api/tracking/$tid" -UseBasicParsing -TimeoutSec 60
  Write-Output ("TRACKING={0} body={1}" -f $r3.StatusCode, $r3.Content.Substring(0, [Math]::Min(120, $r3.Content.Length)))
} catch { Write-Output ("TRACKING_ERR={0}" -f $_.Exception.Message) }

# log4net injection check
Start-Sleep 2
$log = 'C:\lab\logs\shipments-web.log'
if (Test-Path $log) {
  Write-Output '--- last checkout log lines ---'
  Get-Content $log -Tail 30 | Select-String -Pattern 'Checkout|trace\.id=' | Select-Object -Last 8 | ForEach-Object { $_.Line }
  $ok = Get-Content $log -Tail 50 | Where-Object { $_ -match 'Checkout start' -and $_ -match 'trace\.id=[0-9a-fA-F]{16,}' }
  if ($ok) { Write-Output 'LOG4NET_TRACE_OK' } else { Write-Output 'LOG4NET_TRACE_FAIL' }
} else {
  Write-Output 'LOG_MISSING'
}

Write-Output ("TRACKING_ID_FOR_ES=$tid")
