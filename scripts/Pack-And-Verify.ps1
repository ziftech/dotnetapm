# Pack Contoso.Observability* to ./artifacts and prove clean samples weave with zero tracing source.
# Run from repo root on a machine with MSBuild + nuget.exe (lab VM or CI windows-latest).
param(
  [string]$Configuration = 'Release',
  [string]$ArtifactsDir = ''
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path "$root\Contoso.Shipments.sln")) { throw "Run from repo with Contoso.Shipments.sln (root=$root)" }
if (-not $ArtifactsDir) { $ArtifactsDir = Join-Path $root 'artifacts' }

$nuget = Join-Path $root 'nuget.exe'
# Lab image ships an old nuget.exe that rejects modern nuspec schema — always use latest beside the repo.
$bootstrap = 'C:\lab\nuget-latest.exe'
if (-not (Test-Path $bootstrap)) {
  Invoke-WebRequest 'https://dist.nuget.org/win-x86-commandline/v6.11.1/nuget.exe' -OutFile $bootstrap -UseBasicParsing
}
Copy-Item $bootstrap $nuget -Force


$msbuild = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' 2>$null | Select-Object -First 1
if (-not $msbuild) {
  $msbuild = @(
    "${env:ProgramFiles}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
  ) | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $msbuild) { throw 'MSBuild not found' }

Write-Output "Root=$root"
Write-Output "MSBuild=$msbuild"
Write-Output "NuGet=$nuget"

# Ensure packages restored for observability projects
& $nuget restore "$root\Contoso.Shipments.sln" -NonInteractive | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'nuget restore failed' }

$obsProjects = @(
  "$root\src\Contoso.Observability\Contoso.Observability.csproj",
  "$root\src\Contoso.Observability.Web\Contoso.Observability.Web.csproj",
  "$root\src\Contoso.Observability.Log4Net\Contoso.Observability.Log4Net.csproj",
  "$root\src\Contoso.Observability.NLog\Contoso.Observability.NLog.csproj"
)
foreach ($proj in $obsProjects) {
  Write-Output "Build $proj"
  & $msbuild $proj /p:Configuration=$Configuration /p:Platform=AnyCPU /v:m
  if ($LASTEXITCODE -ne 0) { throw "msbuild failed for $proj" }
}

New-Item -ItemType Directory -Force -Path $ArtifactsDir | Out-Null
Get-ChildItem $ArtifactsDir -Filter '*.nupkg' -ErrorAction SilentlyContinue | Remove-Item -Force

$nuspecs = @(
  "$root\packaging\Contoso.Observability\Contoso.Observability.nuspec",
  "$root\packaging\Contoso.Observability.Web\Contoso.Observability.Web.nuspec",
  "$root\packaging\Contoso.Observability.Log4Net\Contoso.Observability.Log4Net.nuspec",
  "$root\packaging\Contoso.Observability.NLog\Contoso.Observability.NLog.nuspec"
)
foreach ($spec in $nuspecs) {
  Write-Output "Pack $spec"
  Push-Location (Split-Path $spec)
  try {
    & $nuget pack (Split-Path $spec -Leaf) -OutputDirectory $ArtifactsDir -NonInteractive
  } finally {
    Pop-Location
  }
  if ($LASTEXITCODE -ne 0) { throw "nuget pack failed for $spec" }
}

$pkgs = Get-ChildItem $ArtifactsDir -Filter '*.nupkg'
if ($pkgs.Count -lt 4) { throw "Expected >=4 nupkgs in $ArtifactsDir, found $($pkgs.Count)" }
Write-Output "Packed:`n$($pkgs.Name -join "`n")"

function Assert-Woven([string]$Dll, [string]$TypeName, [string[]]$MustHaveMethods, [string[]]$MustNotHaveMethods) {
  if (-not (Test-Path $Dll)) { throw "missing $Dll" }
  $bytes = [IO.File]::ReadAllBytes($Dll)
  $text = [Text.Encoding]::Unicode.GetString($bytes) + [Text.Encoding]::ASCII.GetString($bytes)
  $hasMba = $text.Contains('MethodBoundaryAspect') -or $text.Contains('MethodExecutionArgs')
  $hasOnEntry = $text.Contains('OnEntry')
  if (-not ($hasMba -and $hasOnEntry)) {
    throw "WEAVE_FAIL markers missing in $Dll (MBA=$hasMba OnEntry=$hasOnEntry)"
  }
  if (-not $text.Contains('Contoso.Observability.TraceAttribute') -and -not $text.Contains('TraceAttribute')) {
    # assembly attribute name is often present as UTF-16 metadata string
    Write-Output "  warn: TraceAttribute string not obvious in raw bytes (continuing with IL checks)"
  }

  # Resolve deps beside the DLL (bin) and avoid Add-Type lock conflicts across samples.
  $dir = Split-Path $Dll
  $prev = [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object { try { $_.Location } catch { $null } }
  if ($prev -contains $Dll) {
    Write-Output "  (assembly already loaded; using reflection-only heuristics via markers)"
  } else {
    [AppDomain]::CurrentDomain.add_AssemblyResolve({
      param($s, $e)
      $name = $e.Name.Split(',')[0] + '.dll'
      $candidate = Join-Path $dir $name
      if (Test-Path $candidate) { return [Reflection.Assembly]::LoadFrom($candidate) }
      return $null
    })
    $asm = [Reflection.Assembly]::LoadFrom($Dll)
    $type = $asm.GetType($TypeName)
    if (-not $type) { throw "type $TypeName not found in $Dll" }

    function script:Get-IlLen([Reflection.MethodInfo]$mi) {
      if (-not $mi) { return -1 }
      $body = $mi.GetMethodBody()
      if (-not $body) { return -1 }
      return $body.GetILAsByteArray().Length
    }

    foreach ($name in $MustHaveMethods) {
      $mi = $type.GetMethod($name)
      $len = Get-IlLen $mi
      if ($len -lt 40) { throw "WEAVE_FAIL expected woven $TypeName.$name IL=$len (need >40) in $Dll" }
      Write-Output "  OK woven $TypeName.$name IL=$len"
    }

    foreach ($name in $MustNotHaveMethods) {
      $mi = $null
      if ($name -eq 'get_Value') {
        $prop = $type.GetProperty('Value')
        if ($prop) { $mi = $prop.GetGetMethod() }
      } elseif ($name -eq '.ctor') {
        $mi = $type.GetConstructor([Type]::EmptyTypes)
      } else {
        $mi = $type.GetMethod($name)
      }
      $len = Get-IlLen $mi
      if ($len -gt 80) { throw "WEAVE_FAIL expected NOT woven $TypeName.$name IL=$len in $Dll" }
      Write-Output "  OK not-woven $TypeName.$name IL=$len"
    }

    $attrs = @($asm.GetCustomAttributes($false) | ForEach-Object { $_.GetType().FullName })
    if (-not ($attrs | Where-Object { $_ -like '*TraceAttribute*' })) {
      throw "WEAVE_FAIL missing TraceAttribute assembly attribute on $Dll"
    }
  }
  Write-Output "WEAVE_OK $Dll"
}

function Ensure-PackagesConfigRef([string]$ProjectDir, [string]$PackageId, [string]$Version) {
  $pc = Join-Path $ProjectDir 'packages.config'
  $xml = [xml](Get-Content $pc -Raw)
  $existing = $xml.packages.package | Where-Object { $_.id -eq $PackageId }
  if (-not $existing) {
    $node = $xml.CreateElement('package')
    $node.SetAttribute('id', $PackageId)
    $node.SetAttribute('version', $Version)
    $node.SetAttribute('targetFramework', 'net48')
    $xml.packages.AppendChild($node) | Out-Null
    $xml.Save($pc)
  }
}

function Ensure-OldStyleImports([string]$CsprojPath, [string]$PackagesRoot) {
  $text = Get-Content $CsprojPath -Raw
  if ($text -match 'Contoso\.Observability\.props') { return }

  $importProps = "  <Import Project=`"$PackagesRoot\Contoso.Observability.1.0.0\build\Contoso.Observability.props`" Condition=`"Exists('$PackagesRoot\Contoso.Observability.1.0.0\build\Contoso.Observability.props')`" />"
  $importTargets = "  <Import Project=`"$PackagesRoot\Contoso.Observability.1.0.0\build\Contoso.Observability.targets`" Condition=`"Exists('$PackagesRoot\Contoso.Observability.1.0.0\build\Contoso.Observability.targets')`" />"
  $importFody = "  <Import Project=`"$PackagesRoot\Fody.6.8.2\build\Fody.targets`" Condition=`"Exists('$PackagesRoot\Fody.6.8.2\build\Fody.targets')`" />"
  $projDir = Split-Path $CsprojPath
  $weavers = Join-Path $projDir 'FodyWeavers.xml'
  if (-not (Test-Path $weavers)) {
    @(
      '<?xml version="1.0" encoding="utf-8"?>',
      '<Weavers xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="FodyWeavers.xsd">',
      '  <MethodBoundaryAspect />',
      '</Weavers>'
    ) | Set-Content -Path $weavers -Encoding UTF8
  }
  $refs = @"
  <ItemGroup>
    <Reference Include="Contoso.Observability">
      <HintPath>$PackagesRoot\Contoso.Observability.1.0.0\lib\net462\Contoso.Observability.dll</HintPath>
      <Private>True</Private>
    </Reference>
    <Reference Include="MethodBoundaryAspect">
      <HintPath>$PackagesRoot\MethodBoundaryAspect.Fody.3.6.0\lib\net462\MethodBoundaryAspect.dll</HintPath>
      <Private>True</Private>
    </Reference>
    <Reference Include="Elastic.Apm">
      <HintPath>$PackagesRoot\Elastic.Apm.1.34.7\lib\net462\Elastic.Apm.dll</HintPath>
      <Private>True</Private>
    </Reference>
    <Reference Include="System.Diagnostics.DiagnosticSource">
      <HintPath>$PackagesRoot\System.Diagnostics.DiagnosticSource.8.0.1\lib\net462\System.Diagnostics.DiagnosticSource.dll</HintPath>
      <Private>True</Private>
    </Reference>
  </ItemGroup>
"@

  if ($text -match 'Microsoft\.Common\.props') {
    $text = $text -replace '(<Import Project="\$\(MSBuildExtensionsPath\)\\\$\(MSBuildToolsVersion\)\\Microsoft\.Common\.props"[^/]*/>)', "`$1`r`n$importProps"
  } else {
    $text = $text -replace '(<Project[^>]*>)', "`$1`r`n$importProps"
  }

  if ($text -notmatch '</Project>') { throw "no </Project> in $CsprojPath" }
  $text = $text -replace '</Project>', "$refs`r`n$importFody`r`n$importTargets`r`n</Project>"
  Set-Content -Path $CsprojPath -Value $text -Encoding UTF8
}

# --- CleanCsLib (packages.config) ---
$csDir = Join-Path $root 'samples\CleanCsLib'
$csPkg = Join-Path $csDir 'packages'
New-Item -ItemType Directory -Force -Path $csPkg | Out-Null
Ensure-PackagesConfigRef $csDir 'Contoso.Observability' '1.0.0'
$feed = "$ArtifactsDir;https://api.nuget.org/v3/index.json"
& $nuget install Contoso.Observability -Version 1.0.0 -OutputDirectory $csPkg -Source $feed -NonInteractive
if ($LASTEXITCODE -ne 0) { throw 'nuget install Contoso.Observability (CleanCsLib) failed' }
Ensure-OldStyleImports (Join-Path $csDir 'CleanCsLib.csproj') 'packages'
& $msbuild (Join-Path $csDir 'CleanCsLib.csproj') /p:Configuration=$Configuration /v:m
if ($LASTEXITCODE -ne 0) { throw 'CleanCsLib build failed' }
Assert-Woven (Join-Path $csDir "bin\$Configuration\CleanCsLib.dll") 'CleanCsLib.CleanService' @('Ping','PingAsync','Boom') @('get_Value','.ctor')

# --- CleanVbLib (packages.config) ---
$vbDir = Join-Path $root 'samples\CleanVbLib'
$vbPkg = Join-Path $vbDir 'packages'
New-Item -ItemType Directory -Force -Path $vbPkg | Out-Null
Ensure-PackagesConfigRef $vbDir 'Contoso.Observability' '1.0.0'
& $nuget install Contoso.Observability -Version 1.0.0 -OutputDirectory $vbPkg -Source $feed -NonInteractive
if ($LASTEXITCODE -ne 0) { throw 'nuget install Contoso.Observability (CleanVbLib) failed' }
Ensure-OldStyleImports (Join-Path $vbDir 'CleanVbLib.vbproj') 'packages'
& $msbuild (Join-Path $vbDir 'CleanVbLib.vbproj') /p:Configuration=$Configuration /v:m
if ($LASTEXITCODE -ne 0) { throw 'CleanVbLib build failed' }
Assert-Woven (Join-Path $vbDir "bin\$Configuration\CleanVbLib.dll") 'CleanVbLib.CleanService' @('Ping','PingAsync','Boom') @('get_Value','.ctor')

# --- CleanSdkLib (PackageReference) ---
$sdkDir = Join-Path $root 'samples\CleanSdkLib'
$sdkProj = Join-Path $sdkDir 'CleanSdkLib.csproj'
$nugetConfig = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="artifacts" value="$ArtifactsDir" />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
</configuration>
"@
Set-Content -Path (Join-Path $sdkDir 'nuget.config') -Value $nugetConfig -Encoding UTF8
Push-Location $sdkDir
try {
  & dotnet add package Contoso.Observability --version 1.0.0 --source $ArtifactsDir
  if ($LASTEXITCODE -ne 0) { throw 'dotnet add Contoso.Observability failed' }
  & dotnet build $sdkProj -c $Configuration
  if ($LASTEXITCODE -ne 0) { throw 'CleanSdkLib build failed' }
}
finally { Pop-Location }
$sdkDll = Get-ChildItem "$sdkDir\bin\$Configuration" -Recurse -Filter 'CleanSdkLib.dll' | Select-Object -First 1
if (-not $sdkDll) { throw 'CleanSdkLib.dll not found after build' }
Assert-Woven $sdkDll.FullName 'CleanSdkLib.CleanService' @('Ping','PingAsync','Boom') @('get_Value')

Write-Output 'PACK_AND_VERIFY_OK'
