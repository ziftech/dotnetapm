$ErrorActionPreference = 'Stop'
$msb = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe'
& $msb 'C:\lab\src\src\Contoso.Observability\Contoso.Observability.csproj' /p:Configuration=Release /v:m
if ($LASTEXITCODE -ne 0) { throw 'msbuild Contoso.Observability failed' }
Copy-Item 'C:\lab\src\src\Contoso.Observability\bin\Release\Contoso.Observability.dll' 'C:\lab\app\ShipmentsWeb\bin\' -Force
Copy-Item 'C:\lab\src\src\Contoso.Observability\bin\Release\Contoso.Observability.dll' 'C:\lab\app\TrackingApi\bin\' -Force
if (Test-Path 'C:\lab\src\scripts\Fix-DiagnosticSource.ps1') {
  & 'C:\lab\src\scripts\Fix-DiagnosticSource.ps1'
} else {
  Import-Module WebAdministration
  Restart-WebAppPool SharedPool
  Start-Sleep 5
  $code = & curl.exe -s -o C:\lab\logs\dsfix.html -w '%{http_code}' -X POST -d 'trackingId=DSFIX2&lane=DXB-AMM&weightKg=5' -H 'Content-Type: application/x-www-form-urlencoded' http://127.0.0.1/web/Checkout
  Write-Output "checkout=$code"
}
$tid = 'VBSHOT-' + (Get-Date -Format 'HHmmss')
$code = & curl.exe -s -X POST -d "trackingId=$tid&lane=DXB-AMM&weightKg=5" -H 'Content-Type: application/x-www-form-urlencoded' http://127.0.0.1/web/Checkout -o C:\lab\logs\vbshot-live.html -w '%{http_code}'
Write-Output "HTTP=$code TID=$tid"
Get-Content C:\lab\logs\shipments-web.log -Tail 12 | Where-Object { $_ -match [regex]::Escape($tid) }
if ((Get-Content C:\lab\logs\vbshot-live.html -Raw) -match 'VB enrich') { 'VB_PAGE_OK' }
