$ErrorActionPreference = 'Stop'
$app = 'C:\lab\app\TrackingApi'
$bin = Join-Path $app 'bin'
$cfgPath = Join-Path $app 'Web.config'

# Ensure System.* facade packages present
$packages = 'C:\lab\src\packages'
foreach ($id in @('System.Buffers','System.Memory','System.Runtime.CompilerServices.Unsafe','System.Threading.Tasks.Extensions','System.Numerics.Vectors')) {
  $dir = Get-ChildItem $packages -Directory | Where-Object { $_.Name -like "$id.*" } | Sort-Object Name -Descending | Select-Object -First 1
  if (-not $dir) { continue }
  foreach ($tfm in @('net462','netstandard2.0','netstandard1.1','net45')) {
    $lib = Join-Path $dir.FullName "lib\$tfm"
    if (Test-Path $lib) {
      Get-ChildItem $lib -Filter "$id.dll" | ForEach-Object { Copy-Item $_.FullName $bin -Force; Write-Output ("copied " + $_.Name + " " + $tfm) }
      break
    }
  }
}

function Ver([string]$name) {
  $p = Join-Path $bin ($name + '.dll')
  if (-not (Test-Path $p)) { return $null }
  return ([Reflection.AssemblyName]::GetAssemblyName($p)).Version.ToString()
}

[xml]$xml = Get-Content $cfgPath
$ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
$ns.AddNamespace('asm','urn:schemas-microsoft-com:asm.v1')

$pairs = @(
  @{n='System.Buffers'; t='cc7b13ffcd2ddd51'},
  @{n='System.Memory'; t='cc7b13ffcd2ddd51'},
  @{n='System.Runtime.CompilerServices.Unsafe'; t='b03f5f7f11d50a3a'},
  @{n='System.Threading.Tasks.Extensions'; t='cc7b13ffcd2ddd51'},
  @{n='System.Numerics.Vectors'; t='b03f5f7f11d50a3a'},
  @{n='System.Diagnostics.DiagnosticSource'; t='cc7b13ffcd2ddd51'},
  @{n='Microsoft.Extensions.DependencyInjection.Abstractions'; t='adb9793829ddae60'},
  @{n='Microsoft.Extensions.Configuration.Abstractions'; t='adb9793829ddae60'},
  @{n='Microsoft.Extensions.Options'; t='adb9793829ddae60'},
  @{n='Microsoft.Extensions.Logging.Abstractions'; t='adb9793829ddae60'},
  @{n='Microsoft.Extensions.Primitives'; t='adb9793829ddae60'}
)
foreach ($pair in $pairs) {
  $v = Ver $pair.n
  if (-not $v) { Write-Output ("missing " + $pair.n); continue }
  Write-Output ("redirect " + $pair.n + " -> " + $v)
  $node = $xml.SelectSingleNode("//asm:assemblyBinding/asm:dependentAssembly[asm:assemblyIdentity[@name='$($pair.n)']]/asm:bindingRedirect", $ns)
  if ($node) {
    $node.SetAttribute('newVersion', $v)
    $node.SetAttribute('oldVersion','0.0.0.0-99.0.0.0')
  } else {
    $binding = $xml.SelectSingleNode('//asm:assemblyBinding', $ns)
    $da = $xml.CreateElement('dependentAssembly', 'urn:schemas-microsoft-com:asm.v1')
    $ai = $xml.CreateElement('assemblyIdentity', 'urn:schemas-microsoft-com:asm.v1')
    $ai.SetAttribute('name', $pair.n)
    $ai.SetAttribute('publicKeyToken', $pair.t)
    $ai.SetAttribute('culture', 'neutral')
    $br = $xml.CreateElement('bindingRedirect', 'urn:schemas-microsoft-com:asm.v1')
    $br.SetAttribute('oldVersion','0.0.0.0-99.0.0.0')
    $br.SetAttribute('newVersion', $v)
    [void]$da.AppendChild($ai); [void]$da.AppendChild($br); [void]$binding.AppendChild($da)
  }
}
$xml.Save($cfgPath)

# Sync source Web.config redirects for System.Buffers at least
Copy-Item $cfgPath 'C:\lab\src\src\TrackingApi\Web.config' -Force

Import-Module WebAdministration
Restart-WebAppPool TrackingEdotPool
Start-Sleep 3
& curl.exe -s -o C:\lab\logs\tracking-ok.txt -w '%{http_code}' http://127.0.0.1/tracking/api/tracking/bindfix1
Write-Output ''
Get-Content C:\lab\logs\tracking-ok.txt
Get-Content C:\lab\logs\tracking-api.log -Tail 5
