$ErrorActionPreference = 'Continue'
Write-Output '=== appcmd pool env ==='
& "$env:windir\system32\inetsrv\appcmd.exe" list config -section:system.applicationHost/applicationPools |
  Select-String -Pattern 'SharedPool|COR_|ELASTIC_APM|environmentVariable' -Context 0,0 |
  Select-Object -First 80

Write-Output '=== curl tracking body ==='
$out = 'C:\lab\logs\tracking-err.html'
cmd /c "curl -sS -o $out -w %{http_code} http://127.0.0.1/tracking/api/tracking/ASM-WEAVE-1"
Write-Output ''
if (Test-Path $out) {
  Get-Content $out -TotalCount 80
}

Write-Output '=== application event log ==='
Get-WinEvent -LogName Application -MaxEvents 30 -EA SilentlyContinue |
  Where-Object { $_.Message -match 'TrackingApi|Contoso|Exception|ASP.NET|Application Error' } |
  Select-Object -First 8 |
  ForEach-Object { Write-Output ('--- ' + $_.TimeCreated); Write-Output $_.Message.Substring(0, [Math]::Min(800, $_.Message.Length)) }

Write-Output '=== stdout/stderr for w3wp ==='
Get-ChildItem 'C:\lab\logs' | Format-Table Name, Length, LastWriteTime
Write-Output DONE
