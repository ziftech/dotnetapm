# Rebuild Contoso.Shipments.Business for weave mode, redeploy, restart pool.
# Modes: none (DisableWeaving), narrow, broad. Pair with Configure-ApmPool externally.
param(
  [ValidateSet('none','narrow','broad')]
  [string]$WeaveMode = 'narrow',
  [string]$SrcRoot = 'C:\lab\src'
)
$ErrorActionPreference = 'Stop'
$ai = Join-Path $SrcRoot 'src\Contoso.Shipments.Business\Properties\AssemblyInfo.cs'
& (Join-Path $SrcRoot 'scripts\Set-WeaveMode.ps1') -Mode $WeaveMode -AssemblyInfo $ai

$msbuild = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' 2>$null | Select-Object -First 1
if (-not $msbuild -or -not (Test-Path $msbuild)) {
  $candidates = @(
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
    "${env:ProgramFiles}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
  )
  $msbuild = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $msbuild) { throw 'MSBuild not found' }
Write-Output "MSBUILD=$msbuild"
$proj = Join-Path $SrcRoot 'src\Contoso.Shipments.Business\Contoso.Shipments.Business.csproj'
& $msbuild $proj /p:Configuration=Release /p:Platform=AnyCPU /v:m /t:Rebuild
if ($LASTEXITCODE -ne 0) { throw "msbuild failed" }

$dll = Join-Path $SrcRoot 'src\Contoso.Shipments.Business\bin\Release\Contoso.Shipments.Business.dll'
# Stop worker before replacing DLL (file lock)
Get-Process ShipmentsWorker -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Copy-Item $dll 'C:\lab\app\ShipmentsWeb\bin\' -Force
Copy-Item $dll 'C:\lab\app\TrackingApi\bin\' -Force
Copy-Item $dll 'C:\lab\app\ShipmentsWorker\' -Force
$worker = 'C:\lab\app\ShipmentsWorker\ShipmentsWorker.exe'
if (Test-Path $worker) {
  Start-Process -FilePath $worker -WorkingDirectory 'C:\lab\app\ShipmentsWorker' -WindowStyle Hidden
}
Import-Module WebAdministration
Restart-WebAppPool SharedPool
Start-Sleep -Seconds 3
& (Join-Path $SrcRoot 'scripts\Verify-AssemblyWeave.ps1') -Dll 'C:\lab\app\ShipmentsWeb\bin\Contoso.Shipments.Business.dll'
Write-Output "OVERHEAD_BUILD weave=$WeaveMode done"
