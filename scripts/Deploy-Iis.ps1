# Idempotent IIS layout for Contoso lab:
# Site Shipments; apps /web and /tracking; shared pool SharedPool
# Requires elevated PowerShell. Build outputs expected under C:\lab\app\...

$ErrorActionPreference = "Stop"
$appcmd = "$env:windir\system32\inetsrv\appcmd.exe"
$siteName = "Shipments"
$poolName = "SharedPool"
$sitePath = "C:\lab\app\site-root"
$webPath = "C:\lab\app\ShipmentsWeb"
$apiPath = "C:\lab\app\TrackingApi"

New-Item -ItemType Directory -Force -Path $sitePath, $webPath, $apiPath, "C:\lab\logs" | Out-Null
if (-not (Test-Path "$sitePath\index.html")) {
  Set-Content -Path "$sitePath\index.html" -Value "<html><body>Contoso Shipments site root. Use /web and /tracking.</body></html>"
}

Import-Module WebAdministration -ErrorAction Stop

if (-not (Test-Path "IIS:\AppPools\$poolName")) {
  New-WebAppPool -Name $poolName | Out-Null
}
Set-ItemProperty "IIS:\AppPools\$poolName" -Name managedRuntimeVersion -Value "v4.0"
Set-ItemProperty "IIS:\AppPools\$poolName" -Name enable32BitAppOnWin64 -Value $false
Set-ItemProperty "IIS:\AppPools\$poolName" -Name processModel.identityType -Value ApplicationPoolIdentity

if (-not (Get-Website -Name $siteName -ErrorAction SilentlyContinue)) {
  New-Website -Name $siteName -Port 80 -PhysicalPath $sitePath -ApplicationPool $poolName | Out-Null
} else {
  Set-ItemProperty "IIS:\Sites\$siteName" -Name physicalPath -Value $sitePath
  Set-ItemProperty "IIS:\Sites\$siteName" -Name applicationPool -Value $poolName
}

function Ensure-App($path, $physical) {
  $full = "IIS:\Sites\$siteName$path"
  if (-not (Test-Path $full)) {
    New-WebApplication -Site $siteName -Name $path.Trim('/') -PhysicalPath $physical -ApplicationPool $poolName | Out-Null
  } else {
    Set-ItemProperty $full -Name physicalPath -Value $physical
    Set-ItemProperty $full -Name applicationPool -Value $poolName
  }
}

Ensure-App "/web" $webPath
Ensure-App "/tracking" $apiPath

# Grant IIS_IUSRS modify on logs
icacls "C:\lab\logs" /grant "IIS_IUSRS:(OI)(CI)M" | Out-Null
icacls "C:\lab\app" /grant "IIS_IUSRS:(OI)(CI)RX" | Out-Null

& $appcmd list apppool /apppool.name:$poolName
& $appcmd list app /site.name:$siteName
Write-Output "IIS layout ready: http://localhost/web  http://localhost/tracking/api/tracking/demo"
