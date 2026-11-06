# Patch deployed web.configs for lab stages. Does not print secrets.
param(
  [ValidateSet('B0','B1','B2','S1','S2')]
  [string]$Stage = 'S1',
  [string]$WebRoot = 'C:\lab\app\ShipmentsWeb',
  [string]$ApiRoot = 'C:\lab\app\TrackingApi',
  [string]$ServerUrl = '',
  [string]$ApiKey = '',
  [switch]$PerAppNames,
  [switch]$EnableNuGetModule,
  [string]$WebServiceName = 'ShipmentsWeb',
  [string]$ApiServiceName = 'TrackingApi',
  [string]$Environment = 'lab',
  [string]$ServiceVersion = '1.0.0-lab'
)
$ErrorActionPreference = "Stop"

function Get-AppSettings([xml]$xml) {
  $app = $xml.SelectSingleNode('/configuration/appSettings')
  if (-not $app) {
    $app = $xml.CreateElement('appSettings')
    $xml.DocumentElement.AppendChild($app) | Out-Null
  }
  return $app
}

function Set-AppSetting([xml]$xml, [string]$key, [string]$value) {
  $app = Get-AppSettings $xml
  $node = $app.SelectSingleNode("add[@key='$key']")
  if (-not $node) {
    $node = $xml.CreateElement('add')
    $node.SetAttribute('key', $key)
    $app.AppendChild($node) | Out-Null
  }
  $node.SetAttribute('value', $value)
}

function Remove-AppSetting([xml]$xml, [string]$key) {
  $app = $xml.SelectSingleNode('/configuration/appSettings')
  if (-not $app) { return }
  $node = $app.SelectSingleNode("add[@key='$key']")
  if ($node) { $app.RemoveChild($node) | Out-Null }
}

function Ensure-Module([xml]$xml, [bool]$enable) {
  $sws = $xml.SelectSingleNode('/configuration/system.webServer')
  if (-not $sws) {
    $sws = $xml.CreateElement('system.webServer')
    $xml.DocumentElement.AppendChild($sws) | Out-Null
  }
  $modules = $sws.SelectSingleNode('modules')
  if (-not $modules) {
    $modules = $xml.CreateElement('modules')
    $sws.AppendChild($modules) | Out-Null
  }
  $existing = $modules.SelectSingleNode("add[@name='ElasticApmModule']")
  if ($enable) {
    if (-not $existing) {
      $add = $xml.CreateElement('add')
      $add.SetAttribute('name', 'ElasticApmModule')
      $add.SetAttribute('type', 'Elastic.Apm.AspNetFullFramework.ElasticApmModule, Elastic.Apm.AspNetFullFramework')
      $modules.AppendChild($add) | Out-Null
    }
  } else {
    if ($existing) { $modules.RemoveChild($existing) | Out-Null }
  }
}

function Ensure-BindingRedirects([xml]$xml) {
  $runtime = $xml.SelectSingleNode('/configuration/runtime')
  if (-not $runtime) {
    $runtime = $xml.CreateElement('runtime')
    $xml.DocumentElement.AppendChild($runtime) | Out-Null
  }
  $ns = 'urn:schemas-microsoft-com:asm.v1'
  $nsmgr = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
  $nsmgr.AddNamespace('asm', $ns)
  $ab = $runtime.SelectSingleNode('asm:assemblyBinding', $nsmgr)
  if (-not $ab) {
    $ab = $xml.CreateElement('assemblyBinding', $ns)
    $runtime.AppendChild($ab) | Out-Null
  }
  $redirects = @(
    @{ name='System.Diagnostics.DiagnosticSource'; token='cc7b13ffcd2ddd51'; old='0.0.0.0-8.0.0.1'; neu='8.0.0.1' },
    @{ name='System.Threading.Tasks.Dataflow'; token='b03f5f7f11d50a3a'; old='0.0.0.0-8.0.0.1'; neu='8.0.0.1' },
    @{ name='System.Memory'; token='cc7b13ffcd2ddd51'; old='0.0.0.0-4.0.1.2'; neu='4.0.1.2' },
    @{ name='System.Buffers'; token='cc7b13ffcd2ddd51'; old='0.0.0.0-4.0.3.0'; neu='4.0.3.0' },
    @{ name='System.Runtime.CompilerServices.Unsafe'; token='b03f5f7f11d50a3a'; old='0.0.0.0-6.0.0.0'; neu='6.0.0.0' },
    @{ name='System.Threading.Tasks.Extensions'; token='cc7b13ffcd2ddd51'; old='0.0.0.0-4.2.0.1'; neu='4.2.0.1' },
    @{ name='System.Collections.Immutable'; token='b03f5f7f11d50a3a'; old='0.0.0.0-8.0.0.0'; neu='8.0.0.0' },
    @{ name='System.Reflection.Metadata'; token='b03f5f7f11d50a3a'; old='0.0.0.0-8.0.0.1'; neu='8.0.0.1' },
    @{ name='Elastic.Apm'; token='ae7400d2c189cf22'; old='0.0.0.0-1.34.0.0'; neu='1.34.0.0' },
    @{ name='NLog'; token='5120e14c03d0593c'; old='0.0.0.0-5.0.0.0'; neu='5.0.0.0' }
  )
  foreach ($r in $redirects) {
    $da = $ab.SelectSingleNode("asm:dependentAssembly[asm:assemblyIdentity/@name='$($r.name)']", $nsmgr)
    if (-not $da) {
      $da = $xml.CreateElement('dependentAssembly', $ns)
      $ai = $xml.CreateElement('assemblyIdentity', $ns)
      $ai.SetAttribute('name', $r.name)
      $ai.SetAttribute('publicKeyToken', $r.token)
      $ai.SetAttribute('culture', 'neutral')
      $br = $xml.CreateElement('bindingRedirect', $ns)
      $br.SetAttribute('oldVersion', $r.old)
      $br.SetAttribute('newVersion', $r.neu)
      $da.AppendChild($ai) | Out-Null
      $da.AppendChild($br) | Out-Null
      $ab.AppendChild($da) | Out-Null
    }
  }
}

function Patch-WebConfig([string]$path, [string]$serviceName) {
  if (-not (Test-Path $path)) { throw "Missing $path" }
  [xml]$xml = Get-Content $path -Raw
  $enableModule = $false
  if ($EnableNuGetModule) { $enableModule = $true }
  if ($Stage -eq 'B2') { $enableModule = $true }
  if ($Stage -eq 'S2') { $enableModule = $true }

  Ensure-Module $xml $enableModule
  Ensure-BindingRedirects $xml

  if ($ServerUrl) { Set-AppSetting $xml 'ElasticApm:ServerUrl' $ServerUrl }
  if ($ApiKey) { Set-AppSetting $xml 'ElasticApm:ApiKey' $ApiKey }
  Set-AppSetting $xml 'ElasticApm:Environment' $Environment
  Set-AppSetting $xml 'ElasticApm:ServiceVersion' $ServiceVersion
  Set-AppSetting $xml 'ElasticApm:ApplicationNamespaces' 'Contoso.'
  Set-AppSetting $xml 'ElasticApm:SpanStackTraceMinDuration' '0ms'

  if ($PerAppNames -or $Stage -in @('S1','S2') -or ($Stage -eq 'B2' -and $PerAppNames)) {
    Set-AppSetting $xml 'ElasticApm:ServiceName' $serviceName
  } elseif ($Stage -eq 'B2' -and -not $PerAppNames) {
    Remove-AppSetting $xml 'ElasticApm:ServiceName'
  }

  $xml.Save($path)
  Write-Output "Patched $path stage=$Stage service=$serviceName module=$enableModule"
}

Patch-WebConfig (Join-Path $WebRoot 'Web.config') $WebServiceName
Patch-WebConfig (Join-Path $ApiRoot 'Web.config') $ApiServiceName
Import-Module WebAdministration
Restart-WebAppPool SharedPool
Write-Output "Apply-LabStage $Stage done"
