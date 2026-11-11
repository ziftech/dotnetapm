$ErrorActionPreference = "Stop"
$dir = 'C:\lab\app\ShipmentsWorker'
$pkg = 'C:\lab\src\packages'
Get-Process ShipmentsWorker -EA SilentlyContinue | Stop-Process -Force
Start-Sleep 2

# Core agent + known transitive deps used by 1.34.x net462
$copies = @(
  "$pkg\Elastic.Apm.1.34.7\lib\net462\Elastic.Apm.dll",
  "$pkg\System.Diagnostics.DiagnosticSource.8.0.1\lib\net462\System.Diagnostics.DiagnosticSource.dll",
  "$pkg\System.Runtime.CompilerServices.Unsafe.6.0.0\lib\net461\System.Runtime.CompilerServices.Unsafe.dll",
  "$pkg\System.Memory.4.5.5\lib\net461\System.Memory.dll",
  "$pkg\System.Buffers.4.5.1\lib\net461\System.Buffers.dll",
  "$pkg\System.Threading.Tasks.Extensions.4.5.4\lib\net461\System.Threading.Tasks.Extensions.dll",
  "$pkg\System.Numerics.Vectors.4.5.0\lib\net46\System.Numerics.Vectors.dll",
  "$pkg\Microsoft.Bcl.AsyncInterfaces.8.0.0\lib\net462\Microsoft.Bcl.AsyncInterfaces.dll",
  "$pkg\System.Text.Json.8.0.5\lib\net462\System.Text.Json.dll",
  "$pkg\System.Text.Encodings.Web.8.0.0\lib\net462\System.Text.Encodings.Web.dll",
  "$pkg\System.IO.Pipelines.8.0.0\lib\net462\System.IO.Pipelines.dll",
  "$pkg\Microsoft.Extensions.Configuration.Abstractions.8.0.0\lib\net462\Microsoft.Extensions.Configuration.Abstractions.dll",
  "$pkg\Microsoft.Extensions.Primitives.8.0.0\lib\net462\Microsoft.Extensions.Primitives.dll",
  "$pkg\Newtonsoft.Json.13.0.3\lib\net45\Newtonsoft.Json.dll",
  "$pkg\Ben.Demystifier.0.4.1\lib\netstandard2.0\Ben.Demystifier.dll",
  "$pkg\System.Reflection.Metadata.5.0.0\lib\net461\System.Reflection.Metadata.dll",
  "$pkg\System.Collections.Immutable.5.0.0\lib\net461\System.Collections.Immutable.dll",
  "$pkg\MethodBoundaryAspect.Fody.3.6.0\lib\net462\MethodBoundaryAspect.dll"
)
foreach ($c in $copies) {
  if (Test-Path $c) { Copy-Item $c $dir -Force; Write-Output "copied $(Split-Path $c -Leaf)" }
  else { Write-Output "MISSING $c" }
}
Copy-Item C:\lab\src\src\Contoso.Observability\bin\Release\*.dll $dir -Force
Copy-Item C:\lab\src\src\Contoso.Shipments.Business\bin\Release\*.dll $dir -Force

# binding redirects in exe.config
$cfgPath = Join-Path $dir 'ShipmentsWorker.exe.config'
[xml]$xml = Get-Content $cfgPath
$runtime = $xml.configuration.runtime
if (-not $runtime) {
  $runtime = $xml.CreateElement('runtime')
  $xml.configuration.AppendChild($runtime) | Out-Null
}
$asm = $runtime.assemblyBinding
if (-not $asm) {
  $asm = $xml.CreateElement('assemblyBinding')
  $asm.SetAttribute('xmlns','urn:schemas-microsoft-com:asm.v1')
  $runtime.AppendChild($asm) | Out-Null
}
# wipe and add key redirects
$asm.RemoveAll()
$asm.SetAttribute('xmlns','urn:schemas-microsoft-com:asm.v1')
function Add-Redirect($name, $token, $old, $new) {
  $dep = $xml.CreateElement('dependentAssembly')
  $id = $xml.CreateElement('assemblyIdentity'); $id.SetAttribute('name',$name); $id.SetAttribute('publicKeyToken',$token); $id.SetAttribute('culture','neutral')
  $br = $xml.CreateElement('bindingRedirect'); $br.SetAttribute('oldVersion',$old); $br.SetAttribute('newVersion',$new)
  $dep.AppendChild($id) | Out-Null; $dep.AppendChild($br) | Out-Null; $script:asm.AppendChild($dep) | Out-Null
}
Add-Redirect 'System.Diagnostics.DiagnosticSource' 'cc7b13ffcd2ddd51' '0.0.0.0-8.0.0.1' '8.0.0.1'
Add-Redirect 'System.Runtime.CompilerServices.Unsafe' 'b03f5f7f11d50a3a' '0.0.0.0-6.0.0.0' '6.0.0.0'
Add-Redirect 'System.Memory' 'cc7b13ffcd2ddd51' '0.0.0.0-4.0.1.2' '4.0.1.2'
Add-Redirect 'System.Buffers' 'cc7b13ffcd2ddd51' '0.0.0.0-4.0.3.0' '4.0.3.0'
Add-Redirect 'System.Threading.Tasks.Extensions' 'cc7b13ffcd2ddd51' '0.0.0.0-4.2.0.1' '4.2.0.1'
$xml.Save($cfgPath)
Write-Output "config updated"

# Fix diagnostic too: copy dll beside D.exe and rerun
$diag = 'C:\lab\apm-diag'
New-Item -ItemType Directory -Force -Path $diag | Out-Null
Copy-Item "$pkg\Elastic.Apm.1.34.7\lib\net462\Elastic.Apm.dll" $diag -Force
Get-ChildItem $dir -Filter *.dll | Copy-Item -Destination $diag -Force

if (Get-ScheduledTask -TaskName ContosoShipmentsWorker -EA SilentlyContinue) {
  Start-ScheduledTask ContosoShipmentsWorker
  Start-Sleep 6
  Write-Output "worker=$((Get-Process ShipmentsWorker -EA SilentlyContinue).Id)"
}
Get-ChildItem $dir | Format-Table Name,Length -AutoSize
