# S5: TrackingApi on dedicated pool with EDOT (no Elastic APM profiler).
$ErrorActionPreference = "Stop"
Import-Module WebAdministration
Add-Type -AssemblyName "Microsoft.Web.Administration, Version=7.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35" -ErrorAction SilentlyContinue

$poolName = 'TrackingEdotPool'
$siteApp = 'Shipments/tracking'

$map = @{}
Get-Content "$env:USERPROFILE\edot.env" | ForEach-Object {
  if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
  $i = $_.IndexOf('='); $map[$_.Substring(0,$i).Trim()] = $_.Substring($i+1).Trim()
}
if (-not $map['OTEL_EXPORTER_OTLP_ENDPOINT']) { throw 'missing OTEL_EXPORTER_OTLP_ENDPOINT' }
if (-not $map['OTEL_EXPORTER_OTLP_HEADERS']) { throw 'missing OTEL_EXPORTER_OTLP_HEADERS' }

if (-not (Test-Path "IIS:\AppPools\$poolName")) {
  New-WebAppPool -Name $poolName | Out-Null
}
Set-ItemProperty "IIS:\AppPools\$poolName" -Name managedRuntimeVersion -Value 'v4.0'
Set-ItemProperty "IIS:\AppPools\$poolName" -Name enable32BitAppOnWin64 -Value $false

$sm = New-Object Microsoft.Web.Administration.ServerManager
$pool = $sm.ApplicationPools[$poolName]
if (-not $pool) { throw "pool missing $poolName" }
$envColl = $pool.GetCollection('environmentVariables')
# remove all existing
for ($i = $envColl.Count - 1; $i -ge 0; $i--) { $envColl.RemoveAt($i) }

function Add-Env([string]$name, [string]$value) {
  $el = $script:envColl.CreateElement('add')
  $el['name'] = $name
  $el['value'] = $value
  [void]$script:envColl.Add($el)
}

# Explicitly no Elastic APM profiler
Add-Env 'COR_ENABLE_PROFILING' '0'
Add-Env 'OTEL_SERVICE_NAME' 'TrackingApi-EDOT'
Add-Env 'OTEL_RESOURCE_ATTRIBUTES' 'deployment.environment=lab,service.version=s5-edot'
Add-Env 'OTEL_EXPORTER_OTLP_ENDPOINT' $map['OTEL_EXPORTER_OTLP_ENDPOINT']
Add-Env 'OTEL_EXPORTER_OTLP_HEADERS' $map['OTEL_EXPORTER_OTLP_HEADERS']
Add-Env 'OTEL_EXPORTER_OTLP_PROTOCOL' 'http/protobuf'
Add-Env 'OTEL_TRACES_EXPORTER' 'otlp'
Add-Env 'OTEL_METRICS_EXPORTER' 'otlp'
Add-Env 'OTEL_LOGS_EXPORTER' 'none'
Add-Env 'OTEL_DOTNET_AUTO_TRACES_ADDITIONAL_SOURCES' 'Contoso.Observability'
$sm.CommitChanges()

# Bind tracking application to EDOT pool
Set-ItemProperty "IIS:\Sites\$siteApp" -Name applicationPool -Value $poolName

# SQL permission for new pool identity
$sqlcmd = Get-ChildItem 'C:\Program Files\Microsoft SQL Server' -Recurse -Filter sqlcmd.exe -EA SilentlyContinue | Select-Object -First 1
if ($sqlcmd) {
  $env:Path += ';' + $sqlcmd.DirectoryName
  $login = "IIS APPPOOL\$poolName"
  sqlcmd -S '.\SQLEXPRESS' -E -Q "IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'$login') CREATE LOGIN [$login] FROM WINDOWS;" | Out-Null
  sqlcmd -S '.\SQLEXPRESS' -E -d ContosoShipments -Q "IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'$login') BEGIN CREATE USER [$login] FOR LOGIN [$login]; ALTER ROLE db_owner ADD MEMBER [$login]; END" | Out-Null
}

Restart-WebAppPool $poolName
Write-Output "EDOT_POOL_OK pool=$poolName"
Write-Output "endpoint=$($map['OTEL_EXPORTER_OTLP_ENDPOINT'])"
Get-ItemProperty "IIS:\Sites\$siteApp" | Select-Object applicationPool | Format-List
