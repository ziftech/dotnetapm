# Prove Contoso.Shipments.LegacyVb was woven by MethodBoundaryAspect.Fody.
param(
  [string]$Dll = 'C:\lab\app\ShipmentsWeb\bin\Contoso.Shipments.LegacyVb.dll'
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path $Dll)) { throw "missing $Dll" }

$bytes = [IO.File]::ReadAllBytes($Dll)
$text = [Text.Encoding]::Unicode.GetString($bytes) + [Text.Encoding]::ASCII.GetString($bytes)
$markers = @('MethodBoundaryAspect', 'MethodExecutionArgs', 'Contoso.Observability.TraceAttribute', 'OnEntry')
$found = @{}
foreach ($m in $markers) { $found[$m] = $text.Contains($m) }

Add-Type -Path (Join-Path (Split-Path $Dll) 'Contoso.Observability.dll') -ErrorAction SilentlyContinue
Add-Type -Path (Join-Path (Split-Path $Dll) 'MethodBoundaryAspect.dll') -ErrorAction SilentlyContinue
$asm = [Reflection.Assembly]::LoadFrom((Resolve-Path $Dll))
$svc = $asm.GetType('Contoso.Shipments.LegacyVb.LegacyShipmentService')
if (-not $svc) { throw 'LegacyShipmentService type not found' }

function Get-IlLen([Reflection.MethodInfo]$mi) {
  if (-not $mi) { return -1 }
  $body = $mi.GetMethodBody()
  if (-not $body) { return -1 }
  return $body.GetILAsByteArray().Length
}

$enrich = $svc.GetMethod('EnrichQuoteNote')
$norm = $svc.GetMethod('NormalizeTrackingId')
$ilEnrich = Get-IlLen $enrich
$ilNorm = Get-IlLen $norm
$hasTrace = @($asm.GetCustomAttributes($false) | ForEach-Object { $_.GetType().FullName }) -match 'TraceAttribute'
$woven = ($found['MethodBoundaryAspect'] -or $found['MethodExecutionArgs']) -and $ilEnrich -gt 40

$result = [ordered]@{
  dll = $Dll
  markers = $found
  hasTraceAttribute = [bool]$hasTrace
  il = @{ EnrichQuoteNote = $ilEnrich; NormalizeTrackingId = $ilNorm }
  woven = $woven
  verdict = $(if ($woven -and $hasTrace) { 'PASS' } else { 'FAIL' })
}
$result | ConvertTo-Json -Depth 5
if ($result.verdict -ne 'PASS') { throw "VB weave verification failed" }
