$ErrorActionPreference = "Stop"
$zip = "C:\lab\contoso-s1.zip"
if (-not (Test-Path $zip)) { throw "Missing $zip" }
$tmp = "C:\lab\src-staging"
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
Expand-Archive -Path $zip -DestinationPath $tmp -Force
$sln = Get-ChildItem $tmp -Filter Contoso.Shipments.sln -Recurse | Select-Object -First 1
if (-not $sln) { throw "sln not found in zip" }
$root = $sln.Directory.FullName
Write-Output "Source root: $root"
# Replace C:\lab\src with the extracted project root (sln + src + scripts)
if (Test-Path "C:\lab\src") {
  # keep packages cache if present
  if (Test-Path "C:\lab\src\packages") {
    New-Item -ItemType Directory -Force -Path "C:\lab\packages-cache" | Out-Null
    robocopy "C:\lab\src\packages" "C:\lab\packages-cache" /E /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
  }
  Remove-Item "C:\lab\src" -Recurse -Force
}
New-Item -ItemType Directory -Force -Path "C:\lab\src" | Out-Null
robocopy $root "C:\lab\src" /E /XD bin obj .git /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
if (Test-Path "C:\lab\packages-cache") {
  New-Item -ItemType Directory -Force -Path "C:\lab\src\packages" | Out-Null
  robocopy "C:\lab\packages-cache" "C:\lab\src\packages" /E /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
}
Set-Location "C:\lab\src"
powershell -ExecutionPolicy Bypass -File "C:\lab\src\scripts\Build-And-Deploy.ps1"
Write-Output "Sync-And-Build complete"
