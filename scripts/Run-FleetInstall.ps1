$ErrorActionPreference = "Stop"
$map = @{}
Get-Content "$env:USERPROFILE\fleet-install.env" | ForEach-Object {
  if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
  $i = $_.IndexOf('=')
  $map[$_.Substring(0,$i).Trim()] = $_.Substring($i+1).Trim()
}
Copy-Item "$env:USERPROFILE\Install-ElasticAgent.ps1" C:\lab\Install-ElasticAgent.ps1 -Force
& C:\lab\Install-ElasticAgent.ps1 -EnrollmentToken $map['ENROLLMENT_TOKEN'] -FleetUrl $map['FLEET_URL'] -Version '9.1.5'
Remove-Item "$env:USERPROFILE\fleet-install.env" -Force -ErrorAction SilentlyContinue
Write-Output "Run-FleetInstall finished"
