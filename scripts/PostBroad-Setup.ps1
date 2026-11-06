$ErrorActionPreference = "Stop"
$envFile = "$env:USERPROFILE\apm-secrets.env"
$map = @{}
Get-Content $envFile | ForEach-Object {
  if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
  $i = $_.IndexOf('=')
  $map[$_.Substring(0,$i).Trim()] = $_.Substring($i+1).Trim()
}
& C:\lab\Apply-LabStage.ps1 -Stage S2 -PerAppNames -ServerUrl $map['ELASTIC_APM_SERVER_URL'] -ApiKey $map['ELASTIC_APM_API_KEY']
& C:\lab\Fix-S2-Coexistence.ps1
& C:\lab\Repair-ProfilerDeps.ps1
Remove-Item $envFile -Force -ErrorAction SilentlyContinue
foreach ($app in @('C:\lab\app\ShipmentsWeb\bin','C:\lab\app\TrackingApi\bin','C:\lab\app\ShipmentsWorker')) {
  New-Item -ItemType Directory -Force -Path $app | Out-Null
  Copy-Item C:\lab\src\src\Contoso.Observability\bin\Release\*.dll $app -Force -ErrorAction SilentlyContinue
  Copy-Item C:\lab\src\src\Contoso.Shipments.Business\bin\Release\*.dll $app -Force -ErrorAction SilentlyContinue
  Copy-Item C:\lab\src\packages\Elastic.Apm.1.34.7\lib\net462\Elastic.Apm.dll $app -Force -ErrorAction SilentlyContinue
}
Select-String -Path C:\lab\app\ShipmentsWeb\Web.config,C:\lab\app\TrackingApi\Web.config -Pattern 'ElasticApmModule|ServiceName' |
  ForEach-Object { $_.Line.Trim() }
Write-Output "PostBroad-Setup complete"
