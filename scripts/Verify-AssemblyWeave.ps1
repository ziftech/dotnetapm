# Prove Contoso.Shipments.Business was woven by MethodBoundaryAspect.Fody.
# Looks for OnEntry/OnExit aspect helper types or MethodBoundaryAspect IL markers.
param(
  [string]$Dll = 'C:\lab\app\ShipmentsWeb\bin\Contoso.Shipments.Business.dll'
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path $Dll)) { throw "missing $Dll" }

$bytes = [IO.File]::ReadAllBytes($Dll)
$text = [Text.Encoding]::Unicode.GetString($bytes) + [Text.Encoding]::ASCII.GetString($bytes)
$markers = @(
  'MethodBoundaryAspect',
  'OnEntry',
  'OnExit',
  'Contoso.Observability.TraceAttribute',
  'MethodExecutionArgs'
)
$found = @{}
foreach ($m in $markers) { $found[$m] = $text.Contains($m) }

# Reflect public types / methods we expect woven vs not
Add-Type -Path $Dll
$asm = [Reflection.Assembly]::LoadFrom($Dll)
$service = $asm.GetType('Contoso.Shipments.Business.ShipmentService')
$repo = $asm.GetType('Contoso.Shipments.Business.ShipmentRepository')
$pricing = $asm.GetType('Contoso.Shipments.Business.PricingCalculator')

# IL size heuristic: woven methods are larger. Disassemble via MethodBody.
function Get-IlLen([Reflection.MethodInfo]$mi) {
  if (-not $mi) { return -1 }
  $body = $mi.GetMethodBody()
  if (-not $body) { return -1 }
  return $body.GetILAsByteArray().Length
}

$createQuote = $service.GetMethod('CreateQuote')
$createQuoteAsync = $service.GetMethod('CreateQuoteAsync')
$runSlow = if ($repo) { $repo.GetMethod('RunSlowQueryAsync') } else { $null }
$calc = if ($pricing) { $pricing.GetMethod('CalculateHeavy') } else { $null }

$result = [ordered]@{
  dll = $Dll
  length = (Get-Item $Dll).Length
  markers = $found
  il = [ordered]@{
    ShipmentService_CreateQuote = Get-IlLen $createQuote
    ShipmentService_CreateQuoteAsync = Get-IlLen $createQuoteAsync
    ShipmentRepository_RunSlowQueryAsync = Get-IlLen $runSlow
    PricingCalculator_CalculateHeavy = Get-IlLen $calc
  }
  assemblyAttrs = @($asm.GetCustomAttributes($false) | ForEach-Object { $_.GetType().FullName })
  verdict = $null
}

# Narrow weave: Service methods large; Repository/Pricing small (not woven) unless broad.
$svcIl = [int]$result.il.ShipmentService_CreateQuote
$woven = ($found['MethodBoundaryAspect'] -or $found['MethodExecutionArgs']) -and $svcIl -gt 40
$hasDisable = $result.assemblyAttrs -contains 'MethodBoundaryAspect.Fody.Attributes.DisableWeavingAttribute'
$hasTrace = ($result.assemblyAttrs | Where-Object { $_ -like '*TraceAttribute*' }).Count -gt 0

if ($hasDisable) {
  $result.verdict = 'DISABLE_WEAVING_PRESENT'
} elseif ($woven -and $hasTrace) {
  $result.verdict = 'WEAVE_OK_ASSEMBLY_TRACE'
} elseif ($woven) {
  $result.verdict = 'WEAVE_OK_MARKERS'
} else {
  $result.verdict = 'WEAVE_FAIL_OR_NOT_APPLIED'
}

$result | ConvertTo-Json -Depth 6
Write-Output "VERDICT=$($result.verdict)"
