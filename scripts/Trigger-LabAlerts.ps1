# Generate conditions that should fire APM latency/error rules and IIS traffic.
$ErrorActionPreference = 'Continue'
Write-Output 'Trigger latency via SLOW checkouts'
1..15 | ForEach-Object {
  cmd /c "curl -sS -o NUL -w %{http_code} -X POST --data-urlencode trackingId=ALRT-$_ --data-urlencode lane=SLOW --data-urlencode weightKg=5 http://127.0.0.1/web/Checkout"
  Write-Output " slow $_"
}
Write-Output 'Trigger TrackingApi errors'
1..20 | ForEach-Object {
  cmd /c "curl -sS -o NUL -w %{http_code} http://127.0.0.1/tracking/api/tracking/boom"
  Write-Output " boom $_"
}
Write-Output 'CPU burn (infra rule)'
$job = Start-Job { $sw=[Diagnostics.Stopwatch]::StartNew(); while($sw.Elapsed.TotalSeconds -lt 90){ [math]::Sqrt([math]::PI * (Get-Random)) | Out-Null } }
Wait-Job $job | Out-Null
Remove-Job $job
Write-Output 'TRIGGERS_DONE'
