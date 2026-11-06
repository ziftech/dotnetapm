# Start ShipmentsWorker with APM env so non-HTTP Fody spans become transactions.
$ErrorActionPreference = "Continue"
Get-Process ShipmentsWorker -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
$exe = "C:\lab\app\ShipmentsWorker\ShipmentsWorker.exe"
if (-not (Test-Path $exe)) { throw "missing $exe" }

# Read secrets previously used for pool from a local secrets file if present; else from pool XML via appcmd text
$serverUrl = $env:ELASTIC_APM_SERVER_URL
$apiKey = $env:ELASTIC_APM_API_KEY
if (-not $serverUrl -or -not $apiKey) {
  $cfg = & C:\Windows\System32\inetsrv\appcmd.exe list config -section:system.applicationHost/applicationPools
  if ($cfg -match "name=`"ELASTIC_APM_SERVER_URL`" value=`"([^`"]+)`"") { $serverUrl = $Matches[1] }
  if ($cfg -match "name=`"ELASTIC_APM_API_KEY`" value=`"([^`"]+)`"") { $apiKey = $Matches[1] }
}
if (-not $serverUrl -or -not $apiKey) { throw "Could not resolve APM server URL / API key for worker" }

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exe
$psi.WorkingDirectory = Split-Path $exe
$psi.UseShellExecute = $false
$psi.EnvironmentVariables['ELASTIC_APM_SERVER_URL'] = $serverUrl
$psi.EnvironmentVariables['ELASTIC_APM_API_KEY'] = $apiKey
$psi.EnvironmentVariables['ELASTIC_APM_SERVICE_NAME'] = 'ShipmentsWorker'
$psi.EnvironmentVariables['ELASTIC_APM_ENVIRONMENT'] = 'lab'
$psi.EnvironmentVariables['ELASTIC_APM_APPLICATION_NAMESPACES'] = 'Contoso.'
$psi.CreateNoWindow = $true
Copy-Item C:\lab\src\packages\Elastic.Apm.1.34.7\lib\net462\Elastic.Apm.dll C:\lab\app\ShipmentsWorker\ -Force -ErrorAction SilentlyContinue
Copy-Item C:\lab\src\src\Contoso.Observability\bin\Release\*.dll C:\lab\app\ShipmentsWorker\ -Force -ErrorAction SilentlyContinue
Copy-Item C:\lab\src\src\Contoso.Shipments.Business\bin\Release\*.dll C:\lab\app\ShipmentsWorker\ -Force -ErrorAction SilentlyContinue
[System.Diagnostics.Process]::Start($psi) | Out-Null
Start-Sleep 3
Get-Process ShipmentsWorker | Format-Table Id,CPU,WorkingSet64
Write-Output "ShipmentsWorker started service=ShipmentsWorker serverHost=$(([Uri]$serverUrl).Host)"
