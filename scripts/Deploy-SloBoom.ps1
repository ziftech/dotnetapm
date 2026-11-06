$ErrorActionPreference = 'Stop'
$msbuild = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' 2>$null | Select-Object -First 1
if (-not $msbuild) {
  $msbuild = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
}
$proj = 'C:\lab\src\src\ShipmentsWeb\ShipmentsWeb.csproj'
Import-Module WebAdministration
Stop-WebAppPool SharedPool -ErrorAction SilentlyContinue
Start-Sleep 2
& $msbuild $proj /p:Configuration=Release /p:Platform=AnyCPU /v:m /t:Build
if ($LASTEXITCODE -ne 0) { throw 'msbuild ShipmentsWeb failed' }
Copy-Item 'C:\lab\src\src\ShipmentsWeb\bin\ShipmentsWeb.dll' 'C:\lab\app\ShipmentsWeb\bin\' -Force
# Keep DiagnosticSource 10 after rebuild
& 'C:\lab\src\scripts\Fix-DiagnosticSource.ps1'
Write-Output 'Deploy-SloBoom done'
