# Move /tracking back to SharedPool (Elastic APM profiler) after S5 EDOT demos.
$ErrorActionPreference = 'Stop'
Import-Module WebAdministration
$siteApp = 'Shipments/tracking'
Set-ItemProperty "IIS:\Sites\$siteApp" -Name applicationPool -Value 'SharedPool'
if (Test-Path 'IIS:\AppPools\TrackingEdotPool') {
  try { Stop-WebAppPool TrackingEdotPool } catch {}
}
Restart-WebAppPool SharedPool
Write-Output "TRACKING_POOL=SharedPool"
Get-ItemProperty "IIS:\Sites\$siteApp" | Select-Object applicationPool | Format-List
