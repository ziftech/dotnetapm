$ErrorActionPreference = "Stop"
$msb = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe'
& $msb C:\lab\src\src\Contoso.Shipments.Business\Contoso.Shipments.Business.csproj /p:Configuration=Release /v:m
if ($LASTEXITCODE -ne 0) { throw "msbuild failed" }
Copy-Item C:\lab\src\src\Contoso.Shipments.Business\bin\Release\Contoso.Shipments.Business.dll C:\lab\app\ShipmentsWeb\bin\ -Force
Copy-Item C:\lab\src\src\Contoso.Shipments.Business\bin\Release\Contoso.Shipments.Business.dll C:\lab\app\TrackingApi\bin\ -Force
Copy-Item C:\lab\src\src\Contoso.Shipments.Business\bin\Release\Contoso.Shipments.Business.dll C:\lab\app\ShipmentsWorker\ -Force
Import-Module WebAdministration
Restart-WebAppPool SharedPool
Write-Output "REDEPLOY_OK"
Get-Item C:\lab\app\ShipmentsWeb\bin\Contoso.Shipments.Business.dll | Format-List FullName,LastWriteTime,Length
