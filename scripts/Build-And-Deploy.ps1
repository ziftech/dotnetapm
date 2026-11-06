# Restores NuGet packages, MSBuilds the solution, publishes web apps, configures IIS, starts worker.
# Run elevated on the lab VM from C:\lab\src (synced tree).

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path "$root\Contoso.Shipments.sln")) {
  # When script lives under C:\lab\src\scripts
  $root = $PSScriptRoot + "\.."
  $root = (Resolve-Path $root).Path
}
Set-Location $root
New-Item -ItemType Directory -Force -Path "C:\lab\logs", "C:\lab\app\ShipmentsWeb", "C:\lab\app\TrackingApi", "C:\lab\app\ShipmentsWorker" | Out-Null

$nuget = "C:\lab\nuget.exe"
if (-not (Test-Path $nuget)) {
  Invoke-WebRequest "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" -OutFile $nuget
}

$msbuild = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe 2>$null | Select-Object -First 1
if (-not $msbuild) {
  $candidates = @(
    "${env:ProgramFiles}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
  )
  $msbuild = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $msbuild) { throw "MSBuild not found. Is VS Build Tools installed?" }
Write-Output "Using MSBuild: $msbuild"

& $nuget restore ".\Contoso.Shipments.sln" -NonInteractive
if ($LASTEXITCODE -ne 0) { throw "nuget restore failed" }

& $msbuild ".\Contoso.Shipments.sln" /p:Configuration=Release /p:Platform="Any CPU" /m /v:m
if ($LASTEXITCODE -ne 0) { throw "msbuild failed" }

# Copy web project outputs (bin + content)
function Publish-Web($projectDir, $dest) {
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  robocopy "$projectDir" $dest /E /XD obj packages .vs /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "robocopy failed for $projectDir -> $dest code=$LASTEXITCODE" }
}

Publish-Web "$root\src\ShipmentsWeb" "C:\lab\app\ShipmentsWeb"
Publish-Web "$root\src\TrackingApi" "C:\lab\app\TrackingApi"

# Worker binaries
robocopy "$root\src\ShipmentsWorker\bin\Release" "C:\lab\app\ShipmentsWorker" /E /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
Copy-Item "$root\src\Contoso.Shipments.Business\bin\Release\Contoso.Shipments.Business.dll" "C:\lab\app\ShipmentsWorker\" -Force -ErrorAction SilentlyContinue

powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\Deploy-Iis.ps1"

# Restart worker as a simple scheduled-ish process if not running
$workerExe = "C:\lab\app\ShipmentsWorker\ShipmentsWorker.exe"
if (Test-Path $workerExe) {
  Get-Process ShipmentsWorker -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Process -FilePath $workerExe -WorkingDirectory "C:\lab\app\ShipmentsWorker" -WindowStyle Hidden
  Write-Output "ShipmentsWorker started"
}

Write-Output "Build-And-Deploy complete"
