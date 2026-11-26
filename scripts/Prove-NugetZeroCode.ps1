# Phase 5: switch Contoso.Shipments.Business + LegacyVb to Contoso.Observability NuGet,
# rebuild/deploy, and write results/nuget-zero-code/verification.md
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path "$root\Contoso.Shipments.sln")) { throw "repo root not found: $root" }

$outDir = Join-Path $root 'results\nuget-zero-code'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Write-Output '=== Ensure nupkg ==='
$nupkg = Join-Path $root 'artifacts\Contoso.Observability.1.0.0.nupkg'
if (-not (Test-Path $nupkg)) {
  & "$PSScriptRoot\Pack-And-Verify.ps1"
  if (-not (Test-Path $nupkg)) { throw 'Pack-And-Verify failed and no nupkg present' }
} else {
  Write-Output "Using existing $nupkg"
}

$artifacts = Join-Path $root 'artifacts'
$feed = "$artifacts;https://api.nuget.org/v3/index.json"
$nuget = Join-Path $root 'nuget.exe'
if (-not (Test-Path $nuget)) { $nuget = 'C:\lab\nuget.exe' }

function Convert-LibToPackage([string]$ProjectDir, [string]$ProjFile, [string]$TypeFilter) {
  $pkgDir = Join-Path $ProjectDir 'packages'
  if (Test-Path $pkgDir) { Remove-Item $pkgDir -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $pkgDir | Out-Null

  # packages.config
  $pc = Join-Path $ProjectDir 'packages.config'
  if (-not (Test-Path $pc)) {
    @"
<?xml version="1.0" encoding="utf-8"?>
<packages>
  <package id="Contoso.Observability" version="1.0.0" targetFramework="net48" />
</packages>
"@ | Set-Content $pc -Encoding UTF8
  } else {
    $xml = [xml](Get-Content $pc -Raw)
    if (-not ($xml.packages.package | Where-Object { $_.id -eq 'Contoso.Observability' })) {
      $n = $xml.CreateElement('package')
      $n.SetAttribute('id', 'Contoso.Observability')
      $n.SetAttribute('version', '1.0.0')
      $n.SetAttribute('targetFramework', 'net48')
      $xml.packages.AppendChild($n) | Out-Null
      $xml.Save($pc)
    }
  }

  & $nuget install Contoso.Observability -Version 1.0.0 -OutputDirectory $pkgDir -Source $feed -NonInteractive
  if ($LASTEXITCODE -ne 0) { throw "nuget install failed for $ProjectDir" }

  # Strip hand-written Trace / FodyWeavers
  Remove-Item (Join-Path $ProjectDir 'FodyWeavers.xml') -Force -ErrorAction SilentlyContinue
  $asmCs = Join-Path $ProjectDir 'Properties\AssemblyInfo.cs'
  $asmVb = Join-Path $ProjectDir 'My Project\AssemblyInfo.vb'
  foreach ($asm in @($asmCs, $asmVb)) {
    if (-not (Test-Path $asm)) { continue }
    $t = Get-Content $asm -Raw
    $t = [regex]::Replace($t, '(?s)// BEGIN_WEAVE.*?// END_WEAVE', '')
    $t = [regex]::Replace($t, "(?s)<Assembly:\s*Trace\([^)]*\)>", '')
    $t = [regex]::Replace($t, "(?s)\[assembly:\s*Trace\([^\]]*\)\]", '')
    $t = $t -replace 'using Contoso\.Observability;\r?\n', ''
    $t = $t -replace 'using MethodBoundaryAspect\.Fody\.Attributes;\r?\n', ''
    $t = $t -replace 'Imports Contoso\.Observability\r?\n', ''
    $t = $t -replace 'Imports MethodBoundaryAspect\.Fody\.Attributes\r?\n', ''
    Set-Content $asm -Value $t -Encoding UTF8
  }

  $projPath = Join-Path $ProjectDir $ProjFile
  $proj = Get-Content $projPath -Raw
  # Remove ProjectReference to Contoso.Observability
  $proj = [regex]::Replace($proj, '(?s)\s*<ProjectReference Include="\.\.\\Contoso\.Observability\\Contoso\.Observability\.csproj">.*?</ProjectReference>', '')
  # Remove old Fody imports / MBA props from repo packages path
  $proj = [regex]::Replace($proj, '(?m)^\s*<Import Project="\.\.\\\.\.\\packages\\[^"]+"[^/]*/>\s*\r?\n', '')
  $proj = $proj -replace '<None Include="FodyWeavers.xml" />', ''
  # Drop MethodBoundaryAspect HintPath from repo packages (package import supplies WeaverFiles)
  $proj = [regex]::Replace($proj, '(?s)\s*<Reference Include="MethodBoundaryAspect">.*?</Reference>', '')

  if ($proj -notmatch 'Contoso\.Observability\.props') {
    $early = @"
  <Import Project="packages\MethodBoundaryAspect.Fody.3.6.0\build\MethodBoundaryAspect.Fody.props" Condition="Exists('packages\MethodBoundaryAspect.Fody.3.6.0\build\MethodBoundaryAspect.Fody.props')" />
  <Import Project="packages\Contoso.Observability.1.0.0\build\Contoso.Observability.props" Condition="Exists('packages\Contoso.Observability.1.0.0\build\Contoso.Observability.props')" />
"@
    $proj = $proj -replace '(<Import Project="\$\(MSBuildExtensionsPath\)\\\$\(MSBuildToolsVersion\)\\Microsoft\.Common\.props"[^/]*/>)', "`$1`r`n$early"
    if ($proj -notmatch 'ContosoTraceTypeFilter') {
      $proj = $proj -replace '(<RootNamespace>[^<]+</RootNamespace>)', "`$1`r`n    <ContosoTraceTypeFilter>$TypeFilter</ContosoTraceTypeFilter>`r`n    <ContosoTraceNamespaceFilter>^Contoso\.Shipments</ContosoTraceNamespaceFilter>"
    }
    if ($ProjFile -match '\.vbproj' -and $proj -notmatch 'Include="mscorlib"') {
      $proj = $proj -replace '<Reference Include="System" />', "<Reference Include=`"mscorlib`" />`r`n    <Reference Include=`"System`" />"
    }
    $tail = @"
  <ItemGroup>
    <Reference Include="Contoso.Observability">
      <HintPath>packages\Contoso.Observability.1.0.0\lib\net462\Contoso.Observability.dll</HintPath>
      <Private>True</Private>
    </Reference>
    <Reference Include="MethodBoundaryAspect">
      <HintPath>packages\MethodBoundaryAspect.Fody.3.6.0\lib\net462\MethodBoundaryAspect.dll</HintPath>
      <Private>True</Private>
    </Reference>
    <Reference Include="Elastic.Apm">
      <HintPath>packages\Elastic.Apm.1.34.7\lib\net462\Elastic.Apm.dll</HintPath>
      <Private>True</Private>
    </Reference>
    <Reference Include="System.Diagnostics.DiagnosticSource">
      <HintPath>packages\System.Diagnostics.DiagnosticSource.8.0.1\lib\net462\System.Diagnostics.DiagnosticSource.dll</HintPath>
      <Private>True</Private>
    </Reference>
  </ItemGroup>
  <Import Project="packages\Fody.6.8.2\build\Fody.targets" Condition="Exists('packages\Fody.6.8.2\build\Fody.targets')" />
  <Import Project="packages\Contoso.Observability.1.0.0\build\Contoso.Observability.targets" Condition="Exists('packages\Contoso.Observability.1.0.0\build\Contoso.Observability.targets')" />
</Project>
"@
    $proj = $proj -replace '</Project>', $tail
  }

  Set-Content $projPath -Value $proj -Encoding UTF8
  @"
<?xml version="1.0" encoding="utf-8"?>
<Weavers>
  <MethodBoundaryAspect />
</Weavers>
"@ | Set-Content (Join-Path $ProjectDir 'FodyWeavers.xml') -Encoding UTF8

  Write-Output "Converted $ProjectDir"
}

$biz = Join-Path $root 'src\Contoso.Shipments.Business'
$vb = Join-Path $root 'src\Contoso.Shipments.LegacyVb'
# Prefer nested src layout on lab
if (-not (Test-Path $biz) -and (Test-Path (Join-Path $root 'src\src\Contoso.Shipments.Business'))) {
  $biz = Join-Path $root 'src\src\Contoso.Shipments.Business'
  $vb = Join-Path $root 'src\src\Contoso.Shipments.LegacyVb'
}

Convert-LibToPackage $biz 'Contoso.Shipments.Business.csproj' 'Service$'
Convert-LibToPackage $vb 'Contoso.Shipments.LegacyVb.vbproj' 'Service$'

Write-Output '=== Stop IIS for deploy ==='
Import-Module WebAdministration -ErrorAction SilentlyContinue
Stop-WebAppPool -Name SharedPool -ErrorAction SilentlyContinue
Get-Process ShipmentsWorker,w3wp -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Output '=== Build + deploy ==='
& "$PSScriptRoot\Build-And-Deploy.ps1"
if ($LASTEXITCODE -ne 0) { throw 'Build-And-Deploy failed' }

Start-WebAppPool -Name SharedPool -ErrorAction SilentlyContinue

Write-Output '=== Weave verify ==='
& "$PSScriptRoot\Verify-AssemblyWeave.ps1" | Tee-Object (Join-Path $outDir 'weave-csharp.json')
& "$PSScriptRoot\Verify-VbAssemblyWeave.ps1" | Tee-Object (Join-Path $outDir 'weave-vb.json')

Write-Output '=== Traffic smoke ==='
$ok = 0
$fail = 0
1..20 | ForEach-Object {
  try {
    $r = Invoke-WebRequest -Uri 'http://localhost/web/Checkout' -UseBasicParsing -TimeoutSec 30
    if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 400) { $ok++ } else { $fail++ }
  } catch { $fail++ }
}
# POST checkout
try {
  $body = 'trackingId=NUGET1&lane=STANDARD&weightKg=5'
  $r = Invoke-WebRequest -Uri 'http://localhost/web/Checkout' -Method POST -Body $body -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing -TimeoutSec 60
  $checkoutStatus = $r.StatusCode
  $checkoutBody = $r.Content.Substring(0, [Math]::Min(500, $r.Content.Length))
} catch {
  $checkoutStatus = 'ERR'
  $checkoutBody = $_.Exception.Message
}

# Kill-switch config presence (runtime Contoso:Trace:Enabled)
$webConfig = 'C:\lab\app\ShipmentsWeb\Web.config'
$hasKill = $false
if (Test-Path $webConfig) {
  $wc = Get-Content $webConfig -Raw
  if ($wc -notmatch 'Contoso:Trace:Enabled') {
    $wc = $wc -replace '(</appSettings>)', "    <add key=`"Contoso:Trace:Enabled`" value=`"true`" />`r`n`$1"
    Set-Content $webConfig -Value $wc -Encoding UTF8
  }
  $hasKill = (Get-Content $webConfig -Raw) -match 'Contoso:Trace:Enabled'
}

$verification = @"
# NuGet zero-code verification

Generated: $([DateTime]::UtcNow.ToString('o')) (UTC)

## Package install (lab)

- Contoso.Shipments.Business and Contoso.Shipments.LegacyVb consume **Contoso.Observability 1.0.0** from ``./artifacts`` (no hand-written ``[assembly: Trace]``, package generates the attribute).
- FodyWeavers.xml restored as ``<MethodBoundaryAspect />`` only; Contoso props/targets drive filters (``ContosoTraceTypeFilter=Service$``).

## Weave

See ``weave-csharp.json`` / ``weave-vb.json`` in this folder (Verify-AssemblyWeave / Verify-VbAssemblyWeave).

## Traffic smoke

- GET /web/Checkout: ok=$ok fail=$fail (20 tries)
- POST /web/Checkout: status=$checkoutStatus
- Body snippet: $checkoutBody

## Runtime kill switch

- ``Contoso:Trace:Enabled`` present in ShipmentsWeb Web.config: $hasKill
- Setting ``false`` disables new spans without rebuild (TraceSettings / TraceAspect.OnEntry).

## Screenshots

Kept local under ``screenshots/`` (gitignored). Capture waterfall / per-app service names / log4net+NLog trace.id on the lab workstation after traffic.

## Overhead

Run ``scripts/Run-Overhead10m.ps1`` separately for the 10-minute checkout success-rate gate (must stay 100%).
"@

Set-Content (Join-Path $outDir 'verification.md') -Value $verification -Encoding UTF8
Write-Output "Wrote $outDir\verification.md"
Write-Output 'PROVE_NUGET_ZERO_CODE_OK'
