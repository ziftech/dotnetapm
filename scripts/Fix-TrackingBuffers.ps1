$ErrorActionPreference = 'Stop'
# Align TrackingApi binding redirects + facade DLLs with the working ShipmentsWeb app.
$webBin = 'C:\lab\app\ShipmentsWeb\bin'
$apiBin = 'C:\lab\app\TrackingApi\bin'
$apiCfg = 'C:\lab\app\TrackingApi\Web.config'
$webCfg = 'C:\lab\app\ShipmentsWeb\Web.config'

$facades = @(
  'System.Buffers','System.Memory','System.Runtime.CompilerServices.Unsafe',
  'System.Threading.Tasks.Extensions','System.ValueTuple','System.Numerics.Vectors',
  'System.Collections.Immutable','System.Reflection.Metadata','Microsoft.Bcl.AsyncInterfaces'
)
foreach ($n in $facades) {
  $src = Join-Path $webBin ($n + '.dll')
  if (Test-Path $src) {
    Copy-Item $src (Join-Path $apiBin ($n + '.dll')) -Force
    $a = [Reflection.AssemblyName]::GetAssemblyName((Join-Path $apiBin ($n + '.dll')))
    Write-Output ("copied $n -> $($a.Version)")
  }
}

# Copy runtime/assemblyBinding from ShipmentsWeb into TrackingApi (merge)
[xml]$web = Get-Content $webCfg
[xml]$api = Get-Content $apiCfg
$ns = 'urn:schemas-microsoft-com:asm.v1'
$webRuntime = $web.SelectSingleNode('/configuration/runtime')
$apiRuntime = $api.SelectSingleNode('/configuration/runtime')
if (-not $apiRuntime) {
  $apiRuntime = $api.CreateElement('runtime')
  $api.DocumentElement.AppendChild($apiRuntime) | Out-Null
}
# Replace assemblyBinding nodes with clones from web
$nsmgr = New-Object System.Xml.XmlNamespaceManager($api.NameTable)
$nsmgr.AddNamespace('asm', $ns)
$existing = @($apiRuntime.SelectNodes('asm:assemblyBinding', $nsmgr))
foreach ($n in $existing) { [void]$apiRuntime.RemoveChild($n) }

$webNsmgr = New-Object System.Xml.XmlNamespaceManager($web.NameTable)
$webNsmgr.AddNamespace('asm', $ns)
foreach ($ab in $webRuntime.SelectNodes('asm:assemblyBinding', $webNsmgr)) {
  $imported = $api.ImportNode($ab, $true)
  [void]$apiRuntime.AppendChild($imported)
}
$api.Save($apiCfg)
Write-Output 'Copied ShipmentsWeb assemblyBinding into TrackingApi Web.config'

# Extra redirects commonly needed by OTel leftover assemblies still in bin
function Ensure-Redirect([xml]$xml, [string]$name, [string]$token, [string]$ver) {
  $nsmgr = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
  $nsmgr.AddNamespace('asm', $ns)
  $runtime = $xml.SelectSingleNode('/configuration/runtime')
  $ab = $runtime.SelectSingleNode('asm:assemblyBinding', $nsmgr)
  if (-not $ab) {
    $ab = $xml.CreateElement('assemblyBinding', $ns)
    $runtime.AppendChild($ab) | Out-Null
  }
  $da = $ab.SelectSingleNode("asm:dependentAssembly[asm:assemblyIdentity/@name='$name']", $nsmgr)
  if (-not $da) {
    $da = $xml.CreateElement('dependentAssembly', $ns)
    $ai = $xml.CreateElement('assemblyIdentity', $ns)
    $ai.SetAttribute('name', $name); $ai.SetAttribute('publicKeyToken', $token); $ai.SetAttribute('culture', 'neutral')
    $br = $xml.CreateElement('bindingRedirect', $ns)
    $br.SetAttribute('oldVersion', '0.0.0.0-999.0.0.0'); $br.SetAttribute('newVersion', $ver)
    $da.AppendChild($ai) | Out-Null; $da.AppendChild($br) | Out-Null; $ab.AppendChild($da) | Out-Null
  } else {
    $br = $da.SelectSingleNode('asm:bindingRedirect', $nsmgr)
    $br.SetAttribute('newVersion', $ver)
    $br.SetAttribute('oldVersion', '0.0.0.0-999.0.0.0')
  }
}

[xml]$api2 = Get-Content $apiCfg
foreach ($n in $facades) {
  $f = Join-Path $apiBin ($n + '.dll')
  if (Test-Path $f) {
    $ver = [Reflection.AssemblyName]::GetAssemblyName($f).Version.ToString()
    $token = if ($n -match 'Unsafe|Immutable|Metadata|AsyncInterfaces') { 'b03f5f7f11d50a3a' } else { 'cc7b13ffcd2ddd51' }
    Ensure-Redirect $api2 $n $token $ver
  }
}
# DiagnosticSource 10 from OTel stack still present
$ds = Join-Path $apiBin 'System.Diagnostics.DiagnosticSource.dll'
if (Test-Path $ds) {
  Ensure-Redirect $api2 'System.Diagnostics.DiagnosticSource' 'cc7b13ffcd2ddd51' ([Reflection.AssemblyName]::GetAssemblyName($ds).Version.ToString())
}
$api2.Save($apiCfg)

Import-Module WebAdministration
Restart-WebAppPool SharedPool
Start-Sleep 5
$code = cmd /c "curl -sS -o C:\lab\logs\tracking-ok.txt -w %{http_code} http://127.0.0.1/tracking/api/tracking/FIXBUF2"
Write-Output "tracking_http=$code"
Get-Content C:\lab\logs\tracking-ok.txt -TotalCount 8 -EA SilentlyContinue
if ($code -ne '200') {
  # show title from error
  Select-String -Path C:\lab\logs\tracking-ok.txt -Pattern '<title>|Exception Details' | Select-Object -First 5
}
