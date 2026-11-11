$ErrorActionPreference = 'Stop'
Import-Module WebAdministration
Add-Type -AssemblyName 'Microsoft.Web.Administration, Version=7.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35'

$sm = New-Object Microsoft.Web.Administration.ServerManager
$pool = $sm.ApplicationPools['SharedPool']
if (-not $pool) { throw 'SharedPool missing' }
$envColl = $pool.GetCollection('environmentVariables')

function Get-Env([string]$name) {
  foreach ($e in $envColl) {
    if ($e.GetAttributeValue('name') -eq $name) { return $e.GetAttributeValue('value') }
  }
  return $null
}
function Set-Env([string]$name, [string]$value) {
  foreach ($e in $script:envColl) {
    if ($e.GetAttributeValue('name') -eq $name) {
      $e.SetAttributeValue('value', $value)
      return
    }
  }
  $el = $script:envColl.CreateElement('add')
  $el['name'] = $name
  $el['value'] = $value
  [void]$script:envColl.Add($el)
}

Write-Output 'BEFORE:'
foreach ($n in @('ELASTIC_APM_SERVICE_NAME','ELASTIC_APM_ENVIRONMENT','COR_ENABLE_PROFILING','OTEL_SERVICE_NAME')) {
  Write-Output ("  {0}={1}" -f $n, (Get-Env $n))
}

# Per-app name must win for ShipmentsWeb demos.
Set-Env 'ELASTIC_APM_SERVICE_NAME' 'ShipmentsWeb'
Set-Env 'ELASTIC_APM_ENVIRONMENT' 'lab'
$sm.CommitChanges()

# Also ensure Web.config appSettings
$cfgPath = 'C:\lab\app\ShipmentsWeb\Web.config'
[xml]$xml = Get-Content $cfgPath
$app = $xml.configuration.appSettings
if (-not $app) { throw 'appSettings missing' }
function Upsert-AppSetting([string]$key, [string]$value) {
  $node = $script:app.SelectSingleNode("add[@key='$key']")
  if ($node) { $node.SetAttribute('value', $value) }
  else {
    $el = $script:xml.CreateElement('add')
    $el.SetAttribute('key', $key)
    $el.SetAttribute('value', $value)
    [void]$script:app.AppendChild($el)
  }
}
Upsert-AppSetting 'ElasticApm:ServiceName' 'ShipmentsWeb'
Upsert-AppSetting 'ElasticApm:Environment' 'lab'
$xml.Save($cfgPath)

Restart-WebAppPool SharedPool
Start-Sleep 4

Write-Output 'AFTER:'
$sm2 = New-Object Microsoft.Web.Administration.ServerManager
$envColl = $sm2.ApplicationPools['SharedPool'].GetCollection('environmentVariables')
foreach ($n in @('ELASTIC_APM_SERVICE_NAME','ELASTIC_APM_ENVIRONMENT')) {
  Write-Output ("  {0}={1}" -f $n, (Get-Env $n))
}
Select-String -Path $cfgPath -Pattern 'ElasticApm:ServiceName' | ForEach-Object { $_.Line.Trim() }

# Smoke checkout
$code = cmd /c 'curl -sS -o C:\lab\logs\vb-fix.html -w %{http_code} -X POST -H "Content-Type: application/x-www-form-urlencoded" --data "trackingId=VB-SHIPMENTSWEB-1&lane=DXB-AMM&weightKg=5" http://127.0.0.1/web/Checkout'
Write-Output ("CHECKOUT=$code")
Select-String -Path C:\lab\logs\vb-fix.html -Pattern 'VB enrich' | Select-Object -First 1 -ExpandProperty Line
