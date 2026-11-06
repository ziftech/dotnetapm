$ErrorActionPreference = 'Stop'
$dsCandidates = @(
  'C:\lab\src\packages\System.Diagnostics.DiagnosticSource.10.0.0\lib\net462\System.Diagnostics.DiagnosticSource.dll',
  'C:\lab\src\packages\System.Diagnostics.DiagnosticSource.10.0.0\lib\netstandard2.0\System.Diagnostics.DiagnosticSource.dll'
)
$ds10 = $dsCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $ds10) {
  Write-Output 'Available DiagnosticSource packages:'
  Get-ChildItem 'C:\lab\src\packages' -Directory -Filter 'System.Diagnostics.DiagnosticSource*' |
    ForEach-Object { Write-Output $_.FullName }
  throw 'DiagnosticSource 10 package DLL not found'
}
Write-Output "SRC=$ds10 ver=$([Reflection.AssemblyName]::GetAssemblyName($ds10).Version)"

foreach ($dest in @('C:\lab\app\ShipmentsWeb\bin', 'C:\lab\app\TrackingApi\bin')) {
  Copy-Item $ds10 (Join-Path $dest 'System.Diagnostics.DiagnosticSource.dll') -Force
  $p = Join-Path $dest 'System.Diagnostics.DiagnosticSource.dll'
  Write-Output "$p => $([Reflection.AssemblyName]::GetAssemblyName($p).Version)"
}

$ns = 'urn:schemas-microsoft-com:asm.v1'
foreach ($cfg in @('C:\lab\app\ShipmentsWeb\Web.config', 'C:\lab\app\TrackingApi\Web.config')) {
  [xml]$x = Get-Content $cfg
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
  $da = $ab.SelectSingleNode("asm:dependentAssembly[asm:assemblyIdentity/@name='System.Diagnostics.DiagnosticSource']", $nsmgr)
  if (-not $da) {
    $da = $x.CreateElement('dependentAssembly', $ns)
    $ai = $x.CreateElement('assemblyIdentity', $ns)
    $ai.SetAttribute('name', 'System.Diagnostics.DiagnosticSource')
    $ai.SetAttribute('publicKeyToken', 'cc7b13ffcd2ddd51')
    $ai.SetAttribute('culture', 'neutral')
    $br = $x.CreateElement('bindingRedirect', $ns)
    $br.SetAttribute('oldVersion', '0.0.0.0-99.0.0.0')
    $br.SetAttribute('newVersion', '10.0.0.0')
    [void]$da.AppendChild($ai)
    [void]$da.AppendChild($br)
    [void]$ab.AppendChild($da)
  } else {
    $br = $da.SelectSingleNode('asm:bindingRedirect', $nsmgr)
    $br.SetAttribute('newVersion', '10.0.0.0')
    $br.SetAttribute('oldVersion', '0.0.0.0-99.0.0.0')
  }
  $x.Save($cfg)
  Write-Output "redirect_ok $cfg"
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
Write-Output 'DiagnosticSource_FIX_OK'
