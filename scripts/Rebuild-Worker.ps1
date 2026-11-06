$ErrorActionPreference = "Stop"
$msb = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
if (-not (Test-Path $msb)) { throw "msbuild missing at $msb" }
Get-Process ShipmentsWorker -EA SilentlyContinue | Stop-Process -Force
Start-Sleep 2
Set-Location C:\lab\src
& $msb .\src\ShipmentsWorker\ShipmentsWorker.csproj /p:Configuration=Release /v:m
if ($LASTEXITCODE -ne 0) { throw "msbuild failed $LASTEXITCODE" }
Copy-Item .\src\ShipmentsWorker\bin\Release\ShipmentsWorker.exe C:\lab\app\ShipmentsWorker\ -Force
Copy-Item .\src\ShipmentsWorker\bin\Release\*.dll C:\lab\app\ShipmentsWorker\ -Force -ErrorAction SilentlyContinue
Write-Output "BUILD_OK"
Get-Item C:\lab\app\ShipmentsWorker\ShipmentsWorker.exe | Format-List FullName,Length,LastWriteTime
if (Get-ScheduledTask -TaskName ContosoShipmentsWorker -EA SilentlyContinue) {
  Start-ScheduledTask -TaskName ContosoShipmentsWorker
  Start-Sleep 5
  Write-Output "worker=$((Get-Process ShipmentsWorker -EA SilentlyContinue).Id)"
}
