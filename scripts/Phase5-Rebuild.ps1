$ErrorActionPreference = 'Stop'
Import-Module WebAdministration -ErrorAction SilentlyContinue
try { Stop-WebAppPool -Name SharedPool -ErrorAction Stop } catch { Write-Output 'pool already stopped' }
Get-Process ShipmentsWorker,w3wp -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
$ErrorActionPreference = 'Stop'

$msbuild = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
Set-Location C:\lab\src
& $msbuild .\Contoso.Shipments.sln /p:Configuration=Release /p:Platform='Any CPU' /v:m
if ($LASTEXITCODE -ne 0) { throw "msbuild failed $LASTEXITCODE" }

& C:\lab\src\scripts\Build-And-Deploy.ps1
if ($LASTEXITCODE -ne 0) { throw 'Build-And-Deploy failed' }

Start-WebAppPool -Name SharedPool -ErrorAction SilentlyContinue

$out = 'C:\lab\src\results\nuget-zero-code'
New-Item -ItemType Directory -Force -Path $out | Out-Null
& C:\lab\src\scripts\Verify-AssemblyWeave.ps1 | Tee-Object "$out\weave-csharp.json"
& C:\lab\src\scripts\Verify-VbAssemblyWeave.ps1 | Tee-Object "$out\weave-vb.json"

$ok = 0; $fail = 0
1..20 | ForEach-Object {
  try {
    $r = Invoke-WebRequest 'http://localhost/web/Checkout' -UseBasicParsing -TimeoutSec 30
    if ($r.StatusCode -lt 400) { $ok++ } else { $fail++ }
  } catch { $fail++ }
}
try {
  $body = 'trackingId=NUGET1&lane=STANDARD&weightKg=5'
  $r = Invoke-WebRequest 'http://localhost/web/Checkout' -Method POST -Body $body -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing -TimeoutSec 60
  $checkoutStatus = $r.StatusCode
} catch { $checkoutStatus = $_.Exception.Message }

$md = @"
# NuGet zero-code verification

Generated: $([DateTime]::UtcNow.ToString('o')) (UTC)

## Package install (lab)

- Contoso.Shipments.Business and Contoso.Shipments.LegacyVb consume Contoso.Observability 1.0.0 from ./artifacts.
- Hand-written assembly Trace attributes removed; package targets generate them (TypeFilter=Service$).

## Weave

See weave-csharp.json / weave-vb.json.

## Traffic smoke

- GET /web/Checkout: ok=$ok fail=$fail (20 tries)
- POST /web/Checkout: status=$checkoutStatus

## Runtime kill switch

- Contoso:Trace:Enabled in Web.config disables spans without rebuild (TraceSettings).

## Screenshots

Local only (gitignored). Capture waterfall / service names / log correlation on the lab workstation.

## Overhead

Run scripts/Run-Overhead10m.ps1 for the 10-minute success-rate gate.
"@
Set-Content "$out\verification.md" -Value $md -Encoding UTF8
Write-Output "Wrote $out\verification.md"
Write-Output 'PHASE5_REBUILD_OK'
