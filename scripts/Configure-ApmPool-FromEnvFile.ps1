param(
  [ValidateSet('none','profiler','profiler-named','clear')]
  [string]$Mode = 'profiler',
  [string]$EnvFile = "$env:USERPROFILE\apm-secrets.env",
  [string]$ServiceName = ''
)
$ErrorActionPreference = "Stop"
$map = @{}
if ($Mode -ne 'clear' -and $Mode -ne 'none') {
  if (-not (Test-Path $EnvFile)) { throw "Env file missing: $EnvFile" }
  Get-Content $EnvFile | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
    $i = $_.IndexOf('=')
    $k = $_.Substring(0, $i).Trim()
    $v = $_.Substring($i + 1).Trim().Trim('"').Trim("'")
    $map[$k] = $v
  }
}
& "$PSScriptRoot\Configure-ApmPool.ps1" -Mode $Mode -ServerUrl $map['ELASTIC_APM_SERVER_URL'] -ApiKey $map['ELASTIC_APM_API_KEY'] -ServiceName $ServiceName
# Always delete secrets file after use
Remove-Item -Force $EnvFile -ErrorAction SilentlyContinue
Write-Output "Secrets file removed"
