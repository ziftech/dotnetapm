# Install MethodBoundaryAspect.Fody 3.6.0 into C:\lab\src\packages (VB weave fixes).
$ErrorActionPreference = 'Stop'
$root = 'C:\lab\src'
Set-Location $root
$nuget = 'C:\lab\nuget.exe'
if (-not (Test-Path $nuget)) {
  Invoke-WebRequest 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile $nuget
}
& $nuget install MethodBoundaryAspect.Fody -Version 3.6.0 -OutputDirectory "$root\packages" -NonInteractive
if ($LASTEXITCODE -ne 0) { throw "nuget install MethodBoundaryAspect.Fody 3.6.0 failed" }
$pkg = Join-Path $root 'packages\MethodBoundaryAspect.Fody.3.6.0'
if (-not (Test-Path $pkg)) { throw "package folder missing: $pkg" }
Write-Output "INSTALLED=$pkg"
Get-ChildItem $pkg -Recurse -File | Select-Object -ExpandProperty FullName
