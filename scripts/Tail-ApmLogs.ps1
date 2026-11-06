$ErrorActionPreference = "Continue"
$dir = "C:\ProgramData\elastic\apm-agent-dotnet\logs"
$agent = Get-ChildItem $dir -Filter "*.agent.log" | Where-Object { $_.Length -gt 0 } | Sort-Object LastWriteTime -Descending | Select-Object -First 2
foreach ($f in $agent) {
  Write-Output ("==== " + $f.Name + " len=" + $f.Length + " ====")
  Select-String -Path $f.FullName -Pattern "Error|Exception|Fail|service|ServerUrl|started|ElasticApmModule" |
    Select-Object -Last 40 |
    ForEach-Object { ($_.Line -replace 'ApiKey[=:][^,\s\"]+','ApiKey=***' -replace 'Bearer [^,\s]+','Bearer ***') }
}
Write-Output "==== loader latest ===="
$loader = Get-ChildItem $dir -Filter "*loader*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($loader) {
  Write-Output $loader.Name
  Get-Content $loader.FullName -Tail 30 | ForEach-Object { $_ -replace 'ApiKey[=:][^,\s\"]+','ApiKey=***' }
}
