# Restore EDOT packages, build TrackingApi, copy transitive deps, configure pool.
$ErrorActionPreference = "Stop"
$msb = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe'
$nuget = 'C:\lab\nuget.exe'
$packages = 'C:\lab\src\packages'
$app = 'C:\lab\app\TrackingApi'

if (-not (Test-Path $nuget)) {
  Invoke-WebRequest -Uri 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile $nuget -UseBasicParsing
}
New-Item -ItemType Directory -Force -Path $packages | Out-Null

# Pre-release transitive deps required by Elastic.OpenTelemetry 1.7.0
$toInstall = @(
  @{ Id='OpenTelemetry.Instrumentation.GrpcNetClient'; Version='1.20.1-beta.1'; Pre=$true },
  @{ Id='OpenTelemetry.Instrumentation.Process'; Version='1.20.1-rc.1'; Pre=$true },
  @{ Id='OpenTelemetry.Resources.Host'; Version='1.20.1-beta.1'; Pre=$true },
  @{ Id='OpenTelemetry.Resources.ProcessRuntime'; Version='1.20.1-beta.1'; Pre=$true },
  @{ Id='OpenTelemetry.OpAmp.Client'; Version='0.9.0-alpha.1'; Pre=$true },
  @{ Id='OpenTelemetry'; Version='1.20.1'; Pre=$false },
  @{ Id='OpenTelemetry.Api'; Version='1.20.1'; Pre=$false },
  @{ Id='OpenTelemetry.Api.ProviderBuilderExtensions'; Version='1.20.1'; Pre=$false },
  @{ Id='OpenTelemetry.Exporter.OpenTelemetryProtocol'; Version='1.20.1'; Pre=$false },
  @{ Id='OpenTelemetry.Instrumentation.Http'; Version='1.20.1'; Pre=$false },
  @{ Id='OpenTelemetry.Instrumentation.SqlClient'; Version='1.20.1'; Pre=$false },
  @{ Id='OpenTelemetry.Instrumentation.AspNet'; Version='1.20.3'; Pre=$false },
  @{ Id='OpenTelemetry.Instrumentation.AspNet.TelemetryHttpModule'; Version='1.20.3'; Pre=$false },
  @{ Id='Elastic.OpenTelemetry'; Version='1.7.0'; Pre=$true }
)
foreach ($p in $toInstall) {
  $dir = Join-Path $packages ($p.Id + '.' + $p.Version)
  if (Test-Path $dir) { Write-Output "have $($p.Id) $($p.Version)"; continue }
  Write-Output "nuget install $($p.Id) $($p.Version)"
  $args = @('install', $p.Id, '-Version', $p.Version, '-OutputDirectory', $packages, '-NonInteractive')
  if ($p.Pre) { $args += '-PreRelease' }
  & $nuget @args
  if ($LASTEXITCODE -ne 0) { throw "nuget failed for $($p.Id)" }
}

# Build
& $msb C:\lab\src\src\TrackingApi\TrackingApi.csproj /p:Configuration=Release /v:m
if ($LASTEXITCODE -ne 0) { throw "msbuild TrackingApi failed" }

# Deploy app files
New-Item -ItemType Directory -Force -Path "$app\bin" | Out-Null
Copy-Item C:\lab\src\src\TrackingApi\bin\* "$app\bin\" -Recurse -Force
Copy-Item C:\lab\src\src\TrackingApi\Web.config $app -Force
Copy-Item C:\lab\src\src\TrackingApi\Global.asax $app -Force
Copy-Item C:\lab\src\src\TrackingApi\NLog.config $app -Force -ErrorAction SilentlyContinue
Copy-Item C:\lab\src\src\Contoso.Observability\bin\Release\Contoso.Observability.dll "$app\bin\" -Force
Copy-Item C:\lab\src\src\Contoso.Shipments.Business\bin\Release\Contoso.Shipments.Business.dll "$app\bin\" -Force
Copy-Item C:\lab\src\packages\MethodBoundaryAspect.Fody.2.0.149\lib\net462\MethodBoundaryAspect.dll "$app\bin\" -Force -ErrorAction SilentlyContinue

# Copy transitive package DLLs (net462 preferred, else netstandard2.0)
$pkgDirs = Get-ChildItem $packages -Directory | Where-Object {
  $_.Name -match '^(Elastic\.OpenTelemetry|OpenTelemetry|Google\.Protobuf|Microsoft\.Extensions|System\.Diagnostics\.DiagnosticSource|System\.Text\.Json|System\.IO\.Pipelines|System\.Threading\.Channels|Microsoft\.Bcl|System\.Memory|System\.Buffers|System\.Runtime\.CompilerServices\.Unsafe|System\.Threading\.Tasks\.Extensions|System\.Numerics\.Vectors|System\.Text\.Encodings)'
}
foreach ($d in $pkgDirs) {
  $candidates = @()
  foreach ($tfm in @('net462','netstandard2.0','net48','net472','netstandard2.1')) {
    $lib = Join-Path $d.FullName "lib\$tfm"
    if (Test-Path $lib) { $candidates = Get-ChildItem $lib -Filter *.dll -ErrorAction SilentlyContinue; if ($candidates) { break } }
  }
  foreach ($dll in $candidates) {
    Copy-Item $dll.FullName "$app\bin\" -Force
  }
}

# Force DiagnosticSource 10.x last (Observability historically shipped 8.x)
$ds10 = Get-ChildItem "$packages\System.Diagnostics.DiagnosticSource.10.*\lib\net462\System.Diagnostics.DiagnosticSource.dll" | Sort-Object FullName -Descending | Select-Object -First 1
if ($ds10) { Copy-Item $ds10.FullName "$app\bin\" -Force; Write-Output "forced DS $($ds10.FullName)" }

# Fix binding redirects to match on-disk versions where possible
function Ver([string]$name) {
  $p = Join-Path "$app\bin" ($name + '.dll')
  if (-not (Test-Path $p)) { return $null }
  return ([Reflection.AssemblyName]::GetAssemblyName($p)).Version.ToString()
}
$cfgPath = Join-Path $app 'Web.config'
[xml]$xml = Get-Content $cfgPath
$ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
$ns.AddNamespace('asm','urn:schemas-microsoft-com:asm.v1')
foreach ($pair in @(
  @{n='System.Diagnostics.DiagnosticSource'; t='cc7b13ffcd2ddd51'},
  @{n='System.Memory'; t='cc7b13ffcd2ddd51'},
  @{n='System.Buffers'; t='cc7b13ffcd2ddd51'},
  @{n='System.Runtime.CompilerServices.Unsafe'; t='b03f5f7f11d50a3a'},
  @{n='System.Threading.Tasks.Extensions'; t='cc7b13ffcd2ddd51'},
  @{n='Microsoft.Extensions.DependencyInjection.Abstractions'; t='adb9793829ddae60'},
  @{n='Microsoft.Extensions.Configuration.Abstractions'; t='adb9793829ddae60'},
  @{n='Microsoft.Extensions.Options'; t='adb9793829ddae60'},
  @{n='Microsoft.Extensions.Logging.Abstractions'; t='adb9793829ddae60'},
  @{n='Microsoft.Extensions.Primitives'; t='adb9793829ddae60'}
)) {
  $v = Ver $pair.n
  if (-not $v) { continue }
  $node = $xml.SelectSingleNode("//asm:assemblyBinding/asm:dependentAssembly[asm:assemblyIdentity[@name='$($pair.n)']]/asm:bindingRedirect", $ns)
  if ($node) { $node.SetAttribute('newVersion', $v); $node.SetAttribute('oldVersion','0.0.0.0-99.0.0.0') }
}
$xml.Save($cfgPath)

# Pool + env
& C:\lab\Install-EdotTrackingApi.ps1

Import-Module WebAdministration
Restart-WebAppPool TrackingEdotPool
Start-Sleep 3
Write-Output 'DEPLOY_EDOT_OK'
# Remove leftover Elastic APM assemblies from prior profiler deploys
Remove-Item "$app\bin\Elastic.Apm*.dll","$app\bin\Elastic.CommonSchema*.dll" -Force -ErrorAction SilentlyContinue

Get-ChildItem "$app\bin" -Filter 'Elastic*.dll' | Select Name
Get-ChildItem "$app\bin" -Filter 'OpenTelemetry*.dll' | Select Name
