$ErrorActionPreference = 'Stop'
Get-Process MSBuild -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
$root = 'C:\lab\src'

function Publish-Web($projectDir, $dest) {
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  robocopy $projectDir $dest /E /XD obj packages .vs /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "robocopy failed $projectDir code=$LASTEXITCODE" }
}

Publish-Web "$root\src\ShipmentsWeb" 'C:\lab\app\ShipmentsWeb'
Publish-Web "$root\src\TrackingApi" 'C:\lab\app\TrackingApi'

Copy-Item "$root\src\Contoso.Observability\bin\Release\Contoso.Observability.dll" 'C:\lab\app\ShipmentsWeb\bin\' -Force
Copy-Item "$root\src\Contoso.Observability\bin\Release\Contoso.Observability.dll" 'C:\lab\app\TrackingApi\bin\' -Force
Copy-Item "$root\packages\log4net.2.0.17\lib\net45\log4net.dll" 'C:\lab\app\ShipmentsWeb\bin\' -Force -ErrorAction SilentlyContinue
Copy-Item "$root\src\Contoso.Shipments.LegacyVb\bin\Release\Contoso.Shipments.LegacyVb.dll" 'C:\lab\app\ShipmentsWeb\bin\' -Force
Copy-Item "$root\src\Contoso.Shipments.Business\bin\Release\Contoso.Shipments.Business.dll" 'C:\lab\app\ShipmentsWeb\bin\' -Force
Copy-Item "$root\src\Contoso.Shipments.Business\bin\Release\Contoso.Shipments.Business.dll" 'C:\lab\app\TrackingApi\bin\' -Force

Write-Output '--- ShipmentsWeb Web.config markers ---'
Select-String -Path 'C:\lab\app\ShipmentsWeb\Web.config' -Pattern 'apm_trace_id|ContosoCheckoutLabels|ElasticApm:ServiceName' |
  ForEach-Object { $_.Line.Trim() }

Write-Output '--- TrackingApi Global.asax.cs SDK markers ---'
$hits = Select-String -Path 'C:\lab\app\TrackingApi\Global.asax.cs' -Pattern 'OpenTelemetrySdk|WithElasticDefaults|new ActivitySourceTraceBackend'
if ($hits) { $hits | ForEach-Object { $_.Line.Trim() } } else { 'no SDK bootstrap markers (OK)' }

Import-Module WebAdministration
Restart-WebAppPool SharedPool
Start-Sleep 3
Write-Output 'PUBLISH_OK'
