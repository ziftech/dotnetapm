# Install SQL Server Express via Chocolatey (SSEI media download previously timed out).
$ErrorActionPreference = "Continue"
Start-Transcript -Path "C:\lab-sql-choco.log" -Append
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')

if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
  Set-ExecutionPolicy Bypass -Scope Process -Force
  [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
  iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
  $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
}

$svc = Get-Service 'MSSQL$SQLEXPRESS' -ErrorAction SilentlyContinue
if (-not $svc) {
  Write-Output "choco install sql-server-express..."
  choco install sql-server-express -y --no-progress --params "/INSTANCE:SQLEXPRESS"
  Start-Sleep 15
  $svc = Get-Service 'MSSQL$SQLEXPRESS' -ErrorAction SilentlyContinue
}
if (-not $svc) { throw "SQLEXPRESS service still missing after choco install" }
if ($svc.Status -ne 'Running') { Start-Service 'MSSQL$SQLEXPRESS' }

$sqlcmd = Get-ChildItem "C:\Program Files\Microsoft SQL Server" -Recurse -Filter sqlcmd.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if ($sqlcmd) { $env:Path += ";" + $sqlcmd.DirectoryName }

$sql = ".\SQLEXPRESS"
sqlcmd -S $sql -E -Q "IF DB_ID('ContosoShipments') IS NULL CREATE DATABASE ContosoShipments;"
sqlcmd -S $sql -E -d ContosoShipments -Q @"
IF OBJECT_ID('dbo.Shipments') IS NULL
CREATE TABLE dbo.Shipments (
  TrackingId NVARCHAR(64) NOT NULL PRIMARY KEY,
  Lane NVARCHAR(64) NOT NULL,
  WeightKg INT NOT NULL,
  Status NVARCHAR(32) NOT NULL,
  CreatedUtc DATETIME2 NOT NULL
);
"@
sqlcmd -S $sql -E -Q "IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'IIS APPPOOL\SharedPool') CREATE LOGIN [IIS APPPOOL\SharedPool] FROM WINDOWS;"
sqlcmd -S $sql -E -d ContosoShipments -Q "IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'IIS APPPOOL\SharedPool') BEGIN CREATE USER [IIS APPPOOL\SharedPool] FOR LOGIN [IIS APPPOOL\SharedPool]; ALTER ROLE db_owner ADD MEMBER [IIS APPPOOL\SharedPool]; END"

# Ensure web apps use SQLEXPRESS connection string
$cs = "Server=.\SQLEXPRESS;Database=ContosoShipments;Integrated Security=True;Connection Timeout=5"
foreach ($cfg in @('C:\lab\app\ShipmentsWeb\Web.config','C:\lab\app\TrackingApi\Web.config','C:\lab\app\ShipmentsWorker\ShipmentsWorker.exe.config')) {
  if (-not (Test-Path $cfg)) { continue }
  [xml]$xml = Get-Content $cfg -Raw
  $node = $xml.SelectSingleNode("//connectionStrings/add[@name='ContosoShipments']")
  if ($node) { $node.SetAttribute('connectionString', $cs); $xml.Save($cfg); Write-Output "Updated $cfg" }
}
Import-Module WebAdministration
Restart-WebAppPool SharedPool
Set-Content C:\lab-sql.done ("server=$sql; " + (Get-Date).ToString('o'))
Write-Output "SQL Express ready"
Get-Service 'MSSQL$SQLEXPRESS' | Format-Table Name,Status
Stop-Transcript
