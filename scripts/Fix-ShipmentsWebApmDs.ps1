$ErrorActionPreference = 'Stop'
$bin = 'C:\lab\app\ShipmentsWeb\bin'
$packages = 'C:\lab\src\packages'
$profilerHome = 'C:\elastic\apm-agent-dotnet'

Write-Output '=== profiler home DiagnosticSource / Elastic.Apm ==='
Get-ChildItem $profilerHome -Recurse -Include 'System.Diagnostics.DiagnosticSource.dll','Elastic.Apm.dll','System.Memory.dll' -ErrorAction SilentlyContinue |
  ForEach-Object {
    $an = [Reflection.AssemblyName]::GetAssemblyName($_.FullName)
    '{0} ver={1} path={2}' -f $_.Name, $an.Version, $_.FullName
  }

Write-Output '=== currently in ShipmentsWeb bin ==='
Get-ChildItem $bin -Include 'System.Diagnostics.DiagnosticSource.dll','System.Memory.dll','System.Buffers.dll','System.Runtime.CompilerServices.Unsafe.dll','System.Threading.Tasks.Extensions.dll','System.Numerics.Vectors.dll','Elastic.Apm.dll' -Recurse -ErrorAction SilentlyContinue |
  ForEach-Object {
    $an = [Reflection.AssemblyName]::GetAssemblyName($_.FullName)
    '{0} ver={1}' -f $_.Name, $an.Version
  }

function Find-PkgDll($idPattern, $tfmSubpath) {
  $dirs = Get-ChildItem $packages -Directory -Filter $idPattern -ErrorAction SilentlyContinue | Sort-Object Name -Descending
  foreach ($d in $dirs) {
    $p = Join-Path $d.FullName $tfmSubpath
    if (Test-Path $p) { return $p }
  }
  return $null
}

# Prefer DS 8.0.1 (packages.config for Contoso.Observability) — Elastic APM 1.34.x is validated with 8.x on net462.
# DS 10 can pull Activity APIs that conflict when System.Memory isn't aligned.
$ds = Find-PkgDll 'System.Diagnostics.DiagnosticSource.8.*' 'lib\net462\System.Diagnostics.DiagnosticSource.dll'
if (-not $ds) { $ds = Find-PkgDll 'System.Diagnostics.DiagnosticSource.8.*' 'lib\netstandard2.0\System.Diagnostics.DiagnosticSource.dll' }
if (-not $ds) { $ds = Find-PkgDll 'System.Diagnostics.DiagnosticSource.6.*' 'lib\net461\System.Diagnostics.DiagnosticSource.dll' }
if (-not $ds) {
  # last resort: profiler-bundled
  $ds = Get-ChildItem $profilerHome -Recurse -Filter 'System.Diagnostics.DiagnosticSource.dll' -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty FullName
}
if (-not $ds) { throw 'No suitable DiagnosticSource.dll found' }

$dsVer = [Reflection.AssemblyName]::GetAssemblyName($ds).Version
Write-Output "USING_DS=$ds ver=$dsVer"

$mem = Find-PkgDll 'System.Memory.4.*' 'lib\net461\System.Memory.dll'
if (-not $mem) { $mem = Find-PkgDll 'System.Memory.4.*' 'lib\netstandard2.0\System.Memory.dll' }
$buf = Find-PkgDll 'System.Buffers.4.*' 'lib\netstandard2.0\System.Buffers.dll'
$unsafe = Find-PkgDll 'System.Runtime.CompilerServices.Unsafe.6.*' 'lib\net462\System.Runtime.CompilerServices.Unsafe.dll'
if (-not $unsafe) { $unsafe = Find-PkgDll 'System.Runtime.CompilerServices.Unsafe.*' 'lib\net461\System.Runtime.CompilerServices.Unsafe.dll' }
$tasks = Find-PkgDll 'System.Threading.Tasks.Extensions.4.*' 'lib\net461\System.Threading.Tasks.Extensions.dll'
if (-not $tasks) { $tasks = Find-PkgDll 'System.Threading.Tasks.Extensions.4.*' 'lib\netstandard2.0\System.Threading.Tasks.Extensions.dll' }
$vectors = Find-PkgDll 'System.Numerics.Vectors.4.*' 'lib\net46\System.Numerics.Vectors.dll'
if (-not $vectors) { $vectors = Find-PkgDll 'System.Numerics.Vectors.4.*' 'lib\netstandard2.0\System.Numerics.Vectors.dll' }

foreach ($pair in @(
  @{ Src = $ds; Name = 'System.Diagnostics.DiagnosticSource.dll' },
  @{ Src = $mem; Name = 'System.Memory.dll' },
  @{ Src = $buf; Name = 'System.Buffers.dll' },
  @{ Src = $unsafe; Name = 'System.Runtime.CompilerServices.Unsafe.dll' },
  @{ Src = $tasks; Name = 'System.Threading.Tasks.Extensions.dll' },
  @{ Src = $vectors; Name = 'System.Numerics.Vectors.dll' }
)) {
  if ($pair.Src) {
    Copy-Item $pair.Src (Join-Path $bin $pair.Name) -Force
    $v = [Reflection.AssemblyName]::GetAssemblyName((Join-Path $bin $pair.Name)).Version
    "copied $($pair.Name) => $v"
  } else {
    "MISSING $($pair.Name)"
  }
}

function Upsert-Redirect([xml]$x, [string]$name, [string]$token, [string]$newVersion) {
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
}

$cfgPath = 'C:\lab\app\ShipmentsWeb\Web.config'
[xml]$cfg = Get-Content $cfgPath
$dsNew = "$($dsVer.Major).$($dsVer.Minor).$($dsVer.Build).0"
# AssemblyVersion for DS nuget packages typically Major.Minor.0.0 or exact
$dsAsmVer = [Reflection.AssemblyName]::GetAssemblyName((Join-Path $bin 'System.Diagnostics.DiagnosticSource.dll')).Version.ToString()
Upsert-Redirect $cfg 'System.Diagnostics.DiagnosticSource' 'cc7b13ffcd2ddd51' $dsAsmVer

if (Test-Path (Join-Path $bin 'System.Memory.dll')) {
  $v = [Reflection.AssemblyName]::GetAssemblyName((Join-Path $bin 'System.Memory.dll')).Version.ToString()
  Upsert-Redirect $cfg 'System.Memory' 'cc7b13ffcd2ddd51' $v
}
if (Test-Path (Join-Path $bin 'System.Buffers.dll')) {
  $v = [Reflection.AssemblyName]::GetAssemblyName((Join-Path $bin 'System.Buffers.dll')).Version.ToString()
  Upsert-Redirect $cfg 'System.Buffers' 'cc7b13ffcd2ddd51' $v
}
if (Test-Path (Join-Path $bin 'System.Runtime.CompilerServices.Unsafe.dll')) {
  $v = [Reflection.AssemblyName]::GetAssemblyName((Join-Path $bin 'System.Runtime.CompilerServices.Unsafe.dll')).Version.ToString()
  Upsert-Redirect $cfg 'System.Runtime.CompilerServices.Unsafe' 'b03f5f7f11d50a3a' $v
}
if (Test-Path (Join-Path $bin 'System.Threading.Tasks.Extensions.dll')) {
  $v = [Reflection.AssemblyName]::GetAssemblyName((Join-Path $bin 'System.Threading.Tasks.Extensions.dll')).Version.ToString()
  Upsert-Redirect $cfg 'System.Threading.Tasks.Extensions' 'cc7b13ffcd2ddd51' $v
}
if (Test-Path (Join-Path $bin 'System.Numerics.Vectors.dll')) {
  $v = [Reflection.AssemblyName]::GetAssemblyName((Join-Path $bin 'System.Numerics.Vectors.dll')).Version.ToString()
  Upsert-Redirect $cfg 'System.Numerics.Vectors' 'b03f5f7f11d50a3a' $v
}
# Align Elastic.Apm so NuGet + profiler share one identity
Upsert-Redirect $cfg 'Elastic.Apm' '' '1.34.0.0'

$cfg.Save($cfgPath)
Write-Output "Web.config redirects updated (DS->$dsAsmVer)"

# Align Contoso.Observability to same DS so it doesn't force 10.0 load
$obsCsproj = 'C:\lab\src\src\Contoso.Observability\Contoso.Observability.csproj'
if (Test-Path $obsCsproj) {
  Write-Output 'Rebuilding Contoso.Observability against chosen DS...'
  # copy chosen DS into a predictable place referenced by rebuild - update HintPath via package if 8.x exists
}

Import-Module WebAdministration
Restart-WebAppPool SharedPool
Start-Sleep 8

$tid = 'DSAPM-' + (Get-Date -Format 'HHmmss')
$code = & curl.exe -s -o C:\lab\logs\dsapm.html -w '%{http_code}' -X POST `
  -d "trackingId=$tid&lane=DXB-AMM&weightKg=5" `
  -H 'Content-Type: application/x-www-form-urlencoded' `
  http://127.0.0.1/web/Checkout
Write-Output "checkout=$code tid=$tid"
Get-Content C:\lab\logs\shipments-web.log -Tail 8 | Where-Object { $_ -match [regex]::Escape($tid) }

# profiler agent log errors?
$logDir = 'C:\ProgramData\elastic\apm-agent-dotnet\logs'
$newest = Get-ChildItem $logDir -Filter '*.agent.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($newest) {
  Write-Output ("agent_log={0}" -f $newest.Name)
  Select-String -Path $newest.FullName -Pattern 'MissingMethod|BeginRequest|Error|CurrentTransaction is null' |
    Select-Object -Last 15 |
    ForEach-Object { $_.Line }
}

# loaded modules
$proc = Get-CimInstance Win32_Process -Filter "Name='w3wp.exe'" | Where-Object { $_.CommandLine -match 'SharedPool' }
if ($proc) {
  Write-Output "pid=$($proc.ProcessId)"
  (Get-Process -Id $proc.ProcessId).Modules |
    Where-Object { $_.ModuleName -match 'DiagnosticSource|System.Memory|Elastic.Apm' } |
    ForEach-Object { '{0} => {1}' -f $_.ModuleName, $_.FileName }
}
