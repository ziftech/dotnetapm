$ErrorActionPreference = "Continue"
Write-Output "=== pool ==="
Import-Module WebAdministration
Get-ItemProperty 'IIS:\Sites\Shipments\tracking' | Select applicationPool | Format-List
Get-WebAppPoolState TrackingEdotPool
Write-Output "=== recent app errors ==="
try {
  Get-EventLog -LogName Application -Newest 80 |
    Where-Object { $_.EntryType -eq 'Error' -or $_.Message -match 'TrackingApi|OpenTelemetry|Exception' } |
    Select-Object -First 15 TimeGenerated, EntryType, Source, Message |
    ForEach-Object {
      Write-Output ("---- " + $_.TimeGenerated + " " + $_.Source + " ----")
      Write-Output ($_.Message.Substring(0, [Math]::Min(1200, $_.Message.Length)))
    }
} catch { Write-Output $_.Exception.Message }
Write-Output "=== stdout/aspnet temp ==="
Get-ChildItem 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\Temporary ASP.NET Files' -Recurse -Filter '*.log' -EA SilentlyContinue | Select -First 5
Write-Output "=== tracking log ==="
if (Test-Path C:\lab\logs\tracking-api.log) { Get-Content C:\lab\logs\tracking-api.log -Tail 40 }
Write-Output "=== bin DiagnosticSource ==="
$p='C:\lab\app\TrackingApi\bin\System.Diagnostics.DiagnosticSource.dll'
if (Test-Path $p) { [Reflection.AssemblyName]::GetAssemblyName($p).Version }
Get-ChildItem C:\lab\app\TrackingApi\bin -Filter 'System.Diagnostics*.dll' | Format-Table Name,Length
Write-Output "=== http probe local ==="
try {
  $r = Invoke-WebRequest -Uri 'http://127.0.0.1/tracking/api/Tracking/LOCAL1' -UseBasicParsing -TimeoutSec 30
  Write-Output ("status=" + $r.StatusCode)
} catch {
  Write-Output ("local fail: " + $_.Exception.Message)
  if ($_.Exception.Response) {
    $sr = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())
    Write-Output $sr.ReadToEnd().Substring(0, [Math]::Min(2000, 99999))
  }
}
