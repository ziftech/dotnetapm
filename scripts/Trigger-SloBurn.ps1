# Generate failed ShipmentsWeb POST Checkout/Index transactions so the SLO burn-rate rule fires.
$ErrorActionPreference = 'Continue'
Write-Output 'Generating SLOBOOM checkout failures (event.outcome=failure on POST Checkout/Index)'
for ($i = 1; $i -le 60; $i++) {
  $code = cmd /c "curl -sS -o NUL -w %{http_code} -X POST --data-urlencode trackingId=SLOBOOM-$i --data-urlencode lane=DXB-AMM --data-urlencode weightKg=5 http://127.0.0.1/web/Checkout"
  Write-Output "boom_$i=$code"
}
Write-Output 'Trigger-SloBurn done'
