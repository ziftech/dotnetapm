$ErrorActionPreference = "Stop"
$dir = 'C:\lab\app\ShipmentsWorker'
$dll = Join-Path $dir 'System.Threading.Tasks.Dataflow.dll'
if (-not (Test-Path $dll)) { throw "missing Dataflow dll" }
$an = [System.Reflection.AssemblyName]::GetAssemblyName($dll)
Write-Output "DataflowVersion=$($an.Version)"

$cfgPath = Join-Path $dir 'ShipmentsWorker.exe.config'
[xml]$xml = Get-Content $cfgPath
$ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
$ns.AddNamespace('asm','urn:schemas-microsoft-com:asm.v1')
$asm = $xml.SelectSingleNode('//runtime/asm:assemblyBinding', $ns)
if (-not $asm) {
  $runtime = $xml.SelectSingleNode('//runtime')
  if (-not $runtime) {
    $runtime = $xml.CreateElement('runtime')
    [void]$xml.configuration.AppendChild($runtime)
  }
  $asm = $xml.CreateElement('assemblyBinding')
  $asm.SetAttribute('xmlns','urn:schemas-microsoft-com:asm.v1')
  [void]$runtime.AppendChild($asm)
}
# remove existing Dataflow redirects
foreach ($dep in @($asm.SelectNodes('asm:dependentAssembly', $ns))) {
  $n = $dep.SelectSingleNode('asm:assemblyIdentity', $ns)
  if ($n -and $n.GetAttribute('name') -eq 'System.Threading.Tasks.Dataflow') { [void]$asm.RemoveChild($dep) }
}
function Add-Redirect([string]$name,[string]$token,[string]$newVer) {
  $dep = $xml.CreateElement('dependentAssembly')
  $id = $xml.CreateElement('assemblyIdentity')
  $id.SetAttribute('name',$name); $id.SetAttribute('publicKeyToken',$token); $id.SetAttribute('culture','neutral')
  $br = $xml.CreateElement('bindingRedirect')
  $br.SetAttribute('oldVersion','0.0.0.0-99.0.0.0'); $br.SetAttribute('newVersion',$newVer)
  [void]$dep.AppendChild($id); [void]$dep.AppendChild($br); [void]$script:asm.AppendChild($dep)
}
Add-Redirect 'System.Threading.Tasks.Dataflow' 'b03f5f7f11d50a3a' $an.Version.ToString()
Add-Redirect 'System.Diagnostics.DiagnosticSource' 'cc7b13ffcd2ddd51' '8.0.0.1'
Add-Redirect 'System.Runtime.CompilerServices.Unsafe' 'b03f5f7f11d50a3a' '6.0.0.0'
Add-Redirect 'System.Memory' 'cc7b13ffcd2ddd51' '4.0.1.2'
Add-Redirect 'System.Buffers' 'cc7b13ffcd2ddd51' '4.0.3.0'
Add-Redirect 'System.Threading.Tasks.Extensions' 'cc7b13ffcd2ddd51' '4.2.0.1'
$xml.Save($cfgPath)
Write-Output 'config ok'
Get-Content $cfgPath

Get-Process ShipmentsWorker -EA SilentlyContinue | Stop-Process -Force
Start-Sleep 2
Copy-Item $dll C:\lab\apm-diag\ -Force -ErrorAction SilentlyContinue
Start-ScheduledTask ContosoShipmentsWorker
Start-Sleep 8
Write-Output "worker=$((Get-Process ShipmentsWorker -EA SilentlyContinue).Id)"
Get-Content C:\lab\logs\worker-out.txt -Tail 20
