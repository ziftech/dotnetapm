1..8 | ForEach-Object {
  $id = "EDOTBUS$_-$(Get-Random -Maximum 9999)"
  curl.exe -s "http://127.0.0.1/tracking/api/tracking/$id" | Out-Null
  Start-Sleep -Milliseconds 200
}
curl.exe -s -X POST -d 'trackingId=VBSHOT2&lane=DXB-AMM&weightKg=5' -H 'Content-Type: application/x-www-form-urlencoded' http://127.0.0.1/web/Checkout -o C:\lab\logs\vbshot.html -w '%{http_code}'
Write-Output ''
Select-String -Path C:\lab\logs\tracking-api.log -Pattern 'EDOTBUS' | Select-Object -Last 3
