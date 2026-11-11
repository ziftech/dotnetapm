$ErrorActionPreference = 'Stop'
$src = 'C:\lab\src\packages\Elastic.Apm.1.34.7\lib\net462\Elastic.Apm.dll'
$dest = 'C:\lab\app\TrackingApi\bin\Elastic.Apm.dll'
Copy-Item $src $dest -Force
Write-Output ("COPIED=" + ([Reflection.AssemblyName]::GetAssemblyName($dest).FullName))
Import-Module WebAdministration
Restart-WebAppPool TrackingEdotPool
Start-Sleep 3
$r = Invoke-WebRequest -UseBasicParsing 'http://127.0.0.1/tracking/api/tracking/ping' -TimeoutSec 20
Write-Output ("STATUS=" + $r.StatusCode)
Write-Output $r.Content
