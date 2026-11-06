# Rebuild Contoso.Observability + Contoso.Shipments.Business for weave mode, redeploy, restart pool.
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

# Stop worker + recycle pool before replacing DLLs (file locks)
Get-Process ShipmentsWorker -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Import-Module WebAdministration
Stop-WebAppPool SharedPool -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

$obs = Join-Path $SrcRoot 'src\Contoso.Observability\Contoso.Observability.csproj'
& $msbuild $obs /p:Configuration=Release /p:Platform=AnyCPU /v:m /t:Rebuild
if ($LASTEXITCODE -ne 0) { throw "msbuild Contoso.Observability failed" }

$biz = Join-Path $SrcRoot 'src\Contoso.Shipments.Business\Contoso.Shipments.Business.csproj'
& $msbuild $biz /p:Configuration=Release /p:Platform=AnyCPU /v:m /t:Rebuild
if ($LASTEXITCODE -ne 0) { throw "msbuild Contoso.Shipments.Business failed" }

$track = Join-Path $SrcRoot 'src\TrackingApi\TrackingApi.csproj'
& $msbuild $track /p:Configuration=Release /p:Platform=AnyCPU /v:m /t:Rebuild
if ($LASTEXITCODE -ne 0) { throw "msbuild TrackingApi failed" }

$web = Join-Path $SrcRoot 'src\ShipmentsWeb\ShipmentsWeb.csproj'
& $msbuild $web /p:Configuration=Release /p:Platform=AnyCPU /v:m /t:Rebuild
if ($LASTEXITCODE -ne 0) { throw "msbuild ShipmentsWeb failed" }

$obsDll = Join-Path $SrcRoot 'src\Contoso.Observability\bin\Release\Contoso.Observability.dll'
$bizDll = Join-Path $SrcRoot 'src\Contoso.Shipments.Business\bin\Release\Contoso.Shipments.Business.dll'
foreach ($dest in @('C:\lab\app\ShipmentsWeb\bin','C:\lab\app\TrackingApi\bin')) {
  Copy-Item $obsDll $dest -Force
  Copy-Item $bizDll $dest -Force
}
Copy-Item $bizDll 'C:\lab\app\ShipmentsWorker\' -Force
Copy-Item $obsDll 'C:\lab\app\ShipmentsWorker\' -Force -ErrorAction SilentlyContinue

# Deploy TrackingApi / ShipmentsWeb site binaries (controllers + NLog.config)
$trackOut = Join-Path $SrcRoot 'src\TrackingApi\bin'
Copy-Item (Join-Path $trackOut 'TrackingApi.dll') 'C:\lab\app\TrackingApi\bin\' -Force
if (Test-Path (Join-Path $SrcRoot 'src\TrackingApi\NLog.config')) {
  Copy-Item (Join-Path $SrcRoot 'src\TrackingApi\NLog.config') 'C:\lab\app\TrackingApi\NLog.config' -Force
}
$webOut = Join-Path $SrcRoot 'src\ShipmentsWeb\bin'
Copy-Item (Join-Path $webOut 'ShipmentsWeb.dll') 'C:\lab\app\ShipmentsWeb\bin\' -Force

$worker = 'C:\lab\app\ShipmentsWorker\ShipmentsWorker.exe'
if (Test-Path $worker) {
  Start-Process -FilePath $worker -WorkingDirectory 'C:\lab\app\ShipmentsWorker' -WindowStyle Hidden
}
Start-WebAppPool SharedPool
Start-Sleep -Seconds 3
& (Join-Path $SrcRoot 'scripts\Verify-AssemblyWeave.ps1') -Dll 'C:\lab\app\ShipmentsWeb\bin\Contoso.Shipments.Business.dll'
Write-Output "OVERHEAD_BUILD weave=$WeaveMode done"
