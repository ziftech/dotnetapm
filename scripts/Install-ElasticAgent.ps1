param(
  [Parameter(Mandatory=$true)][string]$EnrollmentToken,
  [Parameter(Mandatory=$true)][string]$FleetUrl,
  [string]$Version = "9.2.0"
)
$ErrorActionPreference = "Stop"
Start-Transcript -Path "C:\lab-elastic-agent.log" -Append
New-Item -ItemType Directory -Force -Path C:\lab\agent | Out-Null
$zip = "C:\lab\agent\elastic-agent-$Version-windows-x86_64.zip"
$url = "https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-$Version-windows-x86_64.zip"
if (-not (Test-Path $zip)) {
  Write-Output "Downloading $url"
  Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
}
$dest = "C:\lab\agent\elastic-agent-$Version-windows-x86_64"
if (-not (Test-Path "$dest\elastic-agent.exe")) {
  Expand-Archive -Path $zip -DestinationPath C:\lab\agent -Force
}
Set-Location $dest
Write-Output "Installing Elastic Agent into Fleet..."
& .\elastic-agent.exe install --non-interactive --url=$FleetUrl --enrollment-token=$EnrollmentToken --insecure=$false
Write-Output "elastic-agent install exit=$LASTEXITCODE"
Get-Service elastic-agent -ErrorAction SilentlyContinue | Format-Table Name,Status
Stop-Transcript
