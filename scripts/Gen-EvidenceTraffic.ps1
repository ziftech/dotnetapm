$ErrorActionPreference = 'Continue'
1..8 | ForEach-Object {
  $id = "EV-$_-$(Get-Random -Maximum 9999)"
  cmd /c "curl -sS -o NUL -w %{http_code} -X POST --data-urlencode trackingId=$id --data-urlencode lane=SLOW --data-urlencode weightKg=5 http://127.0.0.1/web/Checkout"
  Write-Output " $id"
  Start-Sleep -Seconds 2
}
Write-Output 'TRAFFIC_DONE'
