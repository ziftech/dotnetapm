$ErrorActionPreference = 'Stop'
$vb = 'C:\lab\src\samples\CleanVbLib'
$upload = 'C:\lab\src\samples-upload\CleanVbLib.vbproj'
if (Test-Path $upload) { Copy-Item $upload "$vb\CleanVbLib.vbproj" -Force }

# Ensure mscorlib present in the project file
$t = Get-Content "$vb\CleanVbLib.vbproj" -Raw
if ($t -notmatch 'Include="mscorlib"') {
  $t = $t -replace '(<ItemGroup>\s*)(<Reference Include="System")', '$1<Reference Include="mscorlib" />`r`n    $2'
  # fallback if replace failed style
  if ($t -notmatch 'Include="mscorlib"') {
    $t = $t -replace '<Reference Include="System" />', "<Reference Include=`"mscorlib`" />`r`n    <Reference Include=`"System`" />"
  }
}

@'
<?xml version="1.0" encoding="utf-8"?>
<Weavers>
  <MethodBoundaryAspect />
</Weavers>
'@ | Set-Content "$vb\FodyWeavers.xml" -Encoding UTF8

if ($t -notmatch 'MethodBoundaryAspect\.Fody\.props') {
  $early = @"
  <Import Project="packages\MethodBoundaryAspect.Fody.3.6.0\build\MethodBoundaryAspect.Fody.props" Condition="Exists('packages\MethodBoundaryAspect.Fody.3.6.0\build\MethodBoundaryAspect.Fody.props')" />
  <Import Project="packages\Contoso.Observability.1.0.0\build\Contoso.Observability.props" Condition="Exists('packages\Contoso.Observability.1.0.0\build\Contoso.Observability.props')" />
"@
  $t = $t -replace '(<Import Project="\$\(MSBuildExtensionsPath\)\\\$\(MSBuildToolsVersion\)\\Microsoft\.Common\.props"[^/]*/>)', "`$1`r`n$early"
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
  $t = $t -replace '</Project>', $tail
}

Set-Content "$vb\CleanVbLib.vbproj" -Value $t -Encoding UTF8
Write-Output '--- mscorlib check ---'
Select-String -Path "$vb\CleanVbLib.vbproj" -Pattern 'mscorlib'

$msbuild = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
if (-not (Test-Path $msbuild)) { throw "MSBuild missing at $msbuild" }
& $msbuild "$vb\CleanVbLib.vbproj" /p:Configuration=Release /v:m
if ($LASTEXITCODE -ne 0) { throw "CleanVbLib build failed exit=$LASTEXITCODE" }
Write-Output 'CLEANVB_BUILD_OK'
