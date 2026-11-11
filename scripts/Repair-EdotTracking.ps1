$ErrorActionPreference = 'Stop'
$msb = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe'
$app = 'C:\lab\app\TrackingApi'
& $msb 'C:\lab\src\src\TrackingApi\TrackingApi.csproj' /p:Configuration=Release /v:m
if ($LASTEXITCODE -ne 0) { throw 'msbuild TrackingApi failed' }
Copy-Item 'C:\lab\src\src\TrackingApi\bin\*' "$app\bin\" -Recurse -Force
Copy-Item 'C:\lab\src\src\TrackingApi\Web.config' $app -Force
Copy-Item 'C:\lab\src\src\TrackingApi\Global.asax' $app -Force
Copy-Item 'C:\lab\src\src\Contoso.Observability\bin\Release\Contoso.Observability.dll' "$app\bin\" -Force
Copy-Item 'C:\lab\src\src\Contoso.Shipments.Business\bin\Release\Contoso.Shipments.Business.dll' "$app\bin\" -Force
Copy-Item 'C:\lab\src\packages\MethodBoundaryAspect.Fody.3.6.0\lib\net462\MethodBoundaryAspect.dll' "$app\bin\" -Force
$sql = 'C:\lab\src\packages\OpenTelemetry.Instrumentation.SqlClient.1.20.2\lib\net462\OpenTelemetry.Instrumentation.SqlClient.dll'
Copy-Item $sql "$app\bin\OpenTelemetry.Instrumentation.SqlClient.dll" -Force
$ds = Get-ChildItem 'C:\lab\src\packages\System.Diagnostics.DiagnosticSource.10.*\lib\net462\System.Diagnostics.DiagnosticSource.dll' |
  Sort-Object FullName -Descending | Select-Object -First 1
if ($ds) { Copy-Item $ds.FullName "$app\bin\" -Force }
Import-Module WebAdministration
# Ensure EDOT pool binding
Set-ItemProperty 'IIS:\Sites\Shipments\tracking' -Name applicationPool -Value TrackingEdotPool
Restart-WebAppPool TrackingEdotPool
Start-Sleep -Seconds 4
$r = Invoke-WebRequest -UseBasicParsing 'http://127.0.0.1/tracking/api/tracking/VB-DEMO-01' -TimeoutSec 20
Write-Output ("STATUS=" + $r.StatusCode)
Write-Output $r.Content
Get-Content C:\lab\logs\tracking-api.log -Tail 5
