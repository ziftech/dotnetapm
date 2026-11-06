$ErrorActionPreference = 'Continue'
Import-Module WebAdministration

Write-Output '=== ServiceName appSettings ==='
foreach ($p in @('C:\lab\app\ShipmentsWeb\Web.config','C:\lab\app\TrackingApi\Web.config')) {
  Select-String -Path $p -Pattern 'ElasticApm:ServiceName|ElasticApm:ServerUrl|ElasticApmModule' |
    ForEach-Object { Write-Output ($p + ': ' + $_.Line.Trim()) }
}

Write-Output '=== bin Trace/MBA/Apm ==='
Get-ChildItem 'C:\lab\app\ShipmentsWeb\bin' -Filter '*.dll' |
  Where-Object { $_.Name -match 'Contoso|MethodBoundary|Elastic.Apm' } |
  ForEach-Object { Write-Output ($_.Name + ' ' + $_.Length + ' ' + $_.LastWriteTime) }

Write-Output '=== weave verify ==='
& 'C:\lab\src\scripts\Verify-AssemblyWeave.ps1' -Dll 'C:\lab\app\ShipmentsWeb\bin\Contoso.Shipments.Business.dll'

Write-Output '=== checkout POST (form) ==='
$code = cmd /c "curl -sS -D C:\lab\logs\co-headers.txt -o C:\lab\logs\co-body.html -w %{http_code} -X POST -H `"Content-Type: application/x-www-form-urlencoded`" --data `"trackingId=DIAG-NARROW&lane=DXB-AMM&weightKg=5`" http://127.0.0.1/web/Checkout"
Write-Output "checkout_http=$code"
Get-Content C:\lab\logs\co-headers.txt -TotalCount 20
Select-String -Path C:\lab\logs\co-body.html -Pattern '<title>|Exception|Server Error|error|Validation' |
  Select-Object -First 15 | ForEach-Object { $_.Line.Trim().Substring(0, [Math]::Min(200, $_.Line.Trim().Length)) }

Write-Output '=== event log ==='
Get-WinEvent -LogName Application -MaxEvents 20 -EA SilentlyContinue |
  Where-Object { $_.Message -match 'ShipmentsWeb|Checkout|Contoso|Exception' } |
  Select-Object -First 5 |
  ForEach-Object {
    Write-Output ('--- ' + $_.TimeCreated)
    Write-Output $_.Message.Substring(0, [Math]::Min(900, $_.Message.Length))
  }

Write-Output '=== recent web log ==='
Get-Content 'C:\lab\logs\shipments-web.log' -Tail 15 -EA SilentlyContinue
Write-Output DONE
