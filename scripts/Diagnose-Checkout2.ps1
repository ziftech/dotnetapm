$ErrorActionPreference = 'Continue'
Write-Output '=== ShipmentsWeb Web.config (appSettings + modules) ==='
Get-Content 'C:\lab\app\ShipmentsWeb\Web.config'
Write-Output '=== curl variants ==='
@(
  @{ n='form-Checkout'; c='curl -sS -o NUL -w %{http_code} -X POST -d trackingId=K6A -d lane=DXB-AMM -d weightKg=8 http://127.0.0.1/web/Checkout' },
  @{ n='form-Index'; c='curl -sS -o NUL -w %{http_code} -X POST -d trackingId=K6B -d lane=DXB-AMM -d weightKg=8 http://127.0.0.1/web/Checkout/Index' },
  @{ n='urlencoded'; c='curl -sS -o NUL -w %{http_code} -X POST -H Content-Type:application/x-www-form-urlencoded --data trackingId=K6C^&lane=DXB-AMM^&weightKg=8 http://127.0.0.1/web/Checkout' }
) | ForEach-Object {
  $code = cmd /c $_.c
  Write-Output ($_.n + '=' + $code)
}
# 20 rapid checkouts under load
$ok=0; $bad=0
1..20 | ForEach-Object {
  $c = cmd /c "curl -sS -o NUL -w %{http_code} -X POST -d trackingId=BURST-$_ -d lane=DXB-AMM -d weightKg=8 http://127.0.0.1/web/Checkout"
  if ($c -eq '200') { $ok++ } else { $bad++; Write-Output ("fail $_=$c") }
}
Write-Output "burst ok=$ok bad=$bad"
Write-Output '=== Observability timestamps ==='
Get-Item 'C:\lab\app\ShipmentsWeb\bin\Contoso.Observability.dll','C:\lab\src\src\Contoso.Observability\bin\Release\Contoso.Observability.dll' -EA SilentlyContinue |
  ForEach-Object { Write-Output ($_.FullName + ' ' + $_.LastWriteTime + ' ' + $_.Length) }
