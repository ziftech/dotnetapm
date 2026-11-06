$ErrorActionPreference = 'Stop'
$msbuild = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe'
& $msbuild 'C:\lab\src\src\ShipmentsWeb\ShipmentsWeb.csproj' /p:Configuration=Release /v:m
if ($LASTEXITCODE -ne 0) { throw 'ShipmentsWeb build failed' }
& $msbuild 'C:\lab\src\src\TrackingApi\TrackingApi.csproj' /p:Configuration=Release /v:m
if ($LASTEXITCODE -ne 0) { throw 'TrackingApi build failed' }
robocopy 'C:\lab\src\src\ShipmentsWeb' 'C:\lab\app\ShipmentsWeb' /E /XD obj packages .vs /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
robocopy 'C:\lab\src\src\TrackingApi' 'C:\lab\app\TrackingApi' /E /XD obj packages .vs /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
Copy-Item 'C:\lab\src\src\Contoso.Shipments.Business\bin\Release\Contoso.Shipments.Business.dll' 'C:\lab\app\ShipmentsWeb\bin\' -Force
Copy-Item 'C:\lab\src\src\Contoso.Shipments.Business\bin\Release\Contoso.Shipments.Business.dll' 'C:\lab\app\TrackingApi\bin\' -Force
& 'C:\lab\src\scripts\Fix-TrackingBuffers.ps1'
& 'C:\lab\src\scripts\Fix-WebLogging.ps1'
Write-Output 'REBUILD_WEBAPI_OK'
