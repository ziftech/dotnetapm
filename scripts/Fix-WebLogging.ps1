$ErrorActionPreference = 'Stop'
$webBin = 'C:\lab\app\ShipmentsWeb\bin'
$cfg = 'C:\lab\app\ShipmentsWeb\Web.config'

# Prefer EcsLayout if package present; else PatternLayout with explicit placeholders filled by code.
$ecs = Get-ChildItem 'C:\lab\src\packages\Elastic.CommonSchema.Log4net*\lib' -Recurse -Filter 'Elastic.CommonSchema.Log4net.dll' -EA SilentlyContinue | Select-Object -First 1
$ecsCore = Get-ChildItem 'C:\lab\src\packages\Elastic.CommonSchema*\lib' -Recurse -Filter 'Elastic.CommonSchema.dll' -EA SilentlyContinue | Select-Object -First 1
if ($ecs) {
  Copy-Item $ecs.FullName $webBin -Force
  if ($ecsCore) { Copy-Item $ecsCore.FullName $webBin -Force }
  Write-Output ("ECS_LOG4NET=" + $ecs.FullName)
} else {
  Write-Output 'ECS_LOG4NET missing - falling back to PatternLayout'
  [xml]$x = Get-Content $cfg
  $layout = $x.SelectSingleNode('//layout')
  if ($layout) {
    $layout.SetAttribute('type', 'log4net.Layout.PatternLayout')
    $cp = $layout.SelectSingleNode('conversionPattern')
    if (-not $cp) {
      $cp = $x.CreateElement('conversionPattern')
      $layout.AppendChild($cp) | Out-Null
    }
    $cp.SetAttribute('value', '%date %-5level %logger - %message%newline')
    $x.Save($cfg)
  }
}

# Ensure Contoso / MBA / DiagnosticSource present
Copy-Item 'C:\lab\src\src\Contoso.Observability\bin\Release\Contoso.Observability.dll' $webBin -Force
Copy-Item 'C:\lab\src\src\Contoso.Shipments.Business\bin\Release\Contoso.Shipments.Business.dll' $webBin -Force
$mba = Get-ChildItem 'C:\lab\src\packages\MethodBoundaryAspect.Fody*\lib' -Recurse -Filter MethodBoundaryAspect.dll | Select-Object -First 1
if ($mba) { Copy-Item $mba.FullName $webBin -Force }

Import-Module WebAdministration
Restart-WebAppPool SharedPool
Start-Sleep 5

$codeHome = cmd /c "curl -sS -o NUL -w %{http_code} http://127.0.0.1/web/"
Write-Output "home=$codeHome"
$codeCo = cmd /c "curl -sS -o C:\lab\logs\checkout-out.html -w %{http_code} -X POST -d trackingId=LOGCORR-1 -d lane=SLOW -d weightKg=5 http://127.0.0.1/web/Checkout"
Write-Output "checkout=$codeCo"
if ($codeCo -ne '200') { Select-String -Path C:\lab\logs\checkout-out.html -Pattern '<title>|Exception Details' | Select-Object -First 5 }
Get-Content C:\lab\logs\shipments-web.log -Tail 8 -EA SilentlyContinue
Get-Content C:\lab\logs\tracking-api.log -Tail 8 -EA SilentlyContinue
