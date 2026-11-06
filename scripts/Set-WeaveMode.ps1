# Rewrite Contoso.Shipments.Business AssemblyInfo Trace attributes: none | narrow | broad
param(
  [ValidateSet('none','narrow','broad')]
  [string]$Mode = 'narrow',
  [string]$AssemblyInfo = 'C:\lab\src\src\Contoso.Shipments.Business\Properties\AssemblyInfo.cs'
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path $AssemblyInfo)) { throw "missing $AssemblyInfo" }
$text = Get-Content $AssemblyInfo -Raw

$narrow = @'
// BEGIN_WEAVE
[assembly: Trace(
    NamespaceFilter = @"^Contoso\.Shipments",
    TypeNameFilter = @"Service$",
    MethodNameFilter = @"^(?!MoveNext$|SetStateMachine$).+",
    AttributeTargetMemberAttributes = MulticastAttributes.Public)]
// END_WEAVE
'@

$broad = @'
// BEGIN_WEAVE
[assembly: Trace(
    NamespaceFilter = @"^Contoso\.Shipments",
    TypeNameFilter = @"Service$",
    MethodNameFilter = @"^(?!MoveNext$|SetStateMachine$).+",
    AttributeTargetMemberAttributes = MulticastAttributes.Public)]
[assembly: Trace(
    NamespaceFilter = @"^Contoso\.Shipments",
    TypeNameFilter = @"^(PricingCalculator|CallChain|ShipmentRepository)$",
    MethodNameFilter = @"^(?!MoveNext$|SetStateMachine$).+",
    AttributeTargetMemberAttributes = MulticastAttributes.Public)]
// END_WEAVE
'@

$none = @'
// BEGIN_WEAVE
// Weave disabled for this build (B0 / S1 no-Fody). MBA built-in DisableWeaving skips weaving entirely.
[assembly: DisableWeaving]
// END_WEAVE
'@

$block = switch ($Mode) {
  'narrow' { $narrow }
  'broad'  { $broad }
  'none'   { $none }
}

if ($text -notmatch '(?s)// BEGIN_WEAVE.*?// END_WEAVE') {
  throw 'BEGIN_WEAVE/END_WEAVE markers missing in AssemblyInfo.cs'
}
$new = [regex]::Replace($text, '(?s)// BEGIN_WEAVE.*?// END_WEAVE', $block.TrimEnd())
Set-Content -Path $AssemblyInfo -Value $new -Encoding UTF8
Write-Output "WEAVE_MODE=$Mode"
Select-String -Path $AssemblyInfo -Pattern 'assembly: Trace|assembly: DisableWeaving|BEGIN_WEAVE' | ForEach-Object { $_.Line.Trim() }
