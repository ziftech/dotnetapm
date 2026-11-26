$ErrorActionPreference = 'Stop'
# Keep DiagnosticSource on 8.0.1 — matches Elastic APM profiler net462 bundle.
# DiagnosticSource 10.0.0 caused MissingMethodException ActivitySpanId.CopyTo on SharedPool BeginRequest.
$dsCandidates = @(
  'C:\lab\src\packages\System.Diagnostics.DiagnosticSource.8.0.1\lib\net462\System.Diagnostics.DiagnosticSource.dll',
  'C:\lab\src\packages\System.Diagnostics.DiagnosticSource.8.0.1\lib\netstandard2.0\System.Diagnostics.DiagnosticSource.dll',
  'C:\elastic\apm-agent-dotnet\net462\System.Diagnostics.DiagnosticSource.dll'
)
$ds = $dsCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $ds) { throw 'DiagnosticSource 8.0.1 DLL not found' }
$dsVer = [Reflection.AssemblyName]::GetAssemblyName($ds).Version.ToString()
Write-Output "SRC=$ds ver=$dsVer"

function Copy-Dep($candidates, $destName) {
  $src = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
  if (-not $src) { Write-Output "MISSING $destName"; return }
  foreach ($dest in @('C:\lab\app\ShipmentsWeb\bin', 'C:\lab\app\TrackingApi\bin')) {
    if (-not (Test-Path $dest)) { continue }
    Copy-Item $src (Join-Path $dest $destName) -Force
  }
  Write-Output "copied $destName from $src"
}

Copy-Dep @($ds) 'System.Diagnostics.DiagnosticSource.dll'
Copy-Dep @(
  'C:\lab\src\packages\System.Memory.4.5.5\lib\net461\System.Memory.dll',
  'C:\elastic\apm-agent-dotnet\net462\System.Memory.dll'
) 'System.Memory.dll'
Copy-Dep @(
  'C:\lab\src\packages\System.Buffers.4.5.1\lib\netstandard2.0\System.Buffers.dll',
  'C:\lab\src\packages\System.Buffers.4.6.1\lib\netstandard2.0\System.Buffers.dll'
) 'System.Buffers.dll'
Copy-Dep @(
  'C:\lab\src\packages\System.Runtime.CompilerServices.Unsafe.6.1.2\lib\net462\System.Runtime.CompilerServices.Unsafe.dll',
  'C:\lab\src\packages\System.Runtime.CompilerServices.Unsafe.6.0.0\lib\net461\System.Runtime.CompilerServices.Unsafe.dll'
) 'System.Runtime.CompilerServices.Unsafe.dll'

function Upsert-Redirect([string]$cfgPath, [string]$name, [string]$token, [string]$newVersion) {
  [xml]$x = Get-Content $cfgPath
  $ns = 'urn:schemas-microsoft-com:asm.v1'
  $nsmgr = New-Object System.Xml.XmlNamespaceManager($x.NameTable)
  $nsmgr.AddNamespace('asm', $ns)
  $runtime = $x.SelectSingleNode('/configuration/runtime')
  if (-not $runtime) {
    $runtime = $x.CreateElement('runtime')
    [void]$x.DocumentElement.AppendChild($runtime)
  }
  $ab = $runtime.SelectSingleNode('asm:assemblyBinding', $nsmgr)
  if (-not $ab) {
    $ab = $x.CreateElement('assemblyBinding', $ns)
    [void]$runtime.AppendChild($ab)
  }
  $da = $ab.SelectSingleNode("asm:dependentAssembly[asm:assemblyIdentity/@name='$name']", $nsmgr)
  if (-not $da) {
    $da = $x.CreateElement('dependentAssembly', $ns)
    $ai = $x.CreateElement('assemblyIdentity', $ns)
    $ai.SetAttribute('name', $name)
    if ($token) { $ai.SetAttribute('publicKeyToken', $token) }
    $ai.SetAttribute('culture', 'neutral')
    $br = $x.CreateElement('bindingRedirect', $ns)
    $br.SetAttribute('oldVersion', '0.0.0.0-99.0.0.0')
    $br.SetAttribute('newVersion', $newVersion)
    [void]$da.AppendChild($ai)
    [void]$da.AppendChild($br)
    [void]$ab.AppendChild($da)
  } else {
    $br = $da.SelectSingleNode('asm:bindingRedirect', $nsmgr)
    $br.SetAttribute('oldVersion', '0.0.0.0-99.0.0.0')
    $br.SetAttribute('newVersion', $newVersion)
  }
  $x.Save($cfgPath)
}

foreach ($cfg in @('C:\lab\app\ShipmentsWeb\Web.config', 'C:\lab\app\TrackingApi\Web.config')) {
  if (-not (Test-Path $cfg)) { continue }
  Upsert-Redirect $cfg 'System.Diagnostics.DiagnosticSource' 'cc7b13ffcd2ddd51' $dsVer
  if (Test-Path 'C:\lab\app\ShipmentsWeb\bin\System.Memory.dll') {
    $v = [Reflection.AssemblyName]::GetAssemblyName('C:\lab\app\ShipmentsWeb\bin\System.Memory.dll').Version.ToString()
    Upsert-Redirect $cfg 'System.Memory' 'cc7b13ffcd2ddd51' $v
  }
  Write-Output "redirect_ok $cfg DS->$dsVer"
}

Import-Module WebAdministration
$state = (Get-WebAppPoolState -Name SharedPool).Value
if ($state -eq 'Stopped') { Start-WebAppPool SharedPool } else { Restart-WebAppPool SharedPool }
Start-Sleep 6
$code = cmd /c "curl -sS -o C:\lab\logs\dsfix.html -w %{http_code} -X POST --data-urlencode trackingId=DSFIX1 --data-urlencode lane=DXB-AMM --data-urlencode weightKg=5 http://127.0.0.1/web/Checkout"
Write-Output "checkout=$code"
if ($code -ne '200') {
  Select-String -Path C:\lab\logs\dsfix.html -Pattern 'Exception Details' | Select-Object -First 3
  throw "checkout still failing: $code"
}
# Confirm APM IDs present
$line = Get-Content C:\lab\logs\shipments-web.log -Tail 20 | Where-Object { $_ -match 'trackingId=DSFIX1' -and $_ -match 'Checkout start' } | Select-Object -Last 1
Write-Output $line
if ($line -notmatch 'trace\.id=[0-9a-f]{32}') { throw 'APM trace.id missing after DS fix' }
Write-Output 'DiagnosticSource_FIX_OK'
