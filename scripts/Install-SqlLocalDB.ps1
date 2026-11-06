# Lightweight SQL path for Contoso lab when Express media download fails.
# Installs SqlLocalDB via Chocolatey (or Chocolatey first), creates ContosoShipments,
# and switches IIS app connection strings to LocalDB shared instance if Express absent.
$ErrorActionPreference = "Continue"
Start-Transcript -Path "C:\lab-sql-localdb.log" -Append
New-Item -ItemType Directory -Force -Path C:\lab\sql | Out-Null

if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
  Write-Output "Installing Chocolatey..."
  Set-ExecutionPolicy Bypass -Scope Process -Force
  [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
  iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
  $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
}

$server = $null
$svc = Get-Service 'MSSQL$SQLEXPRESS' -ErrorAction SilentlyContinue
if ($svc) {
  if ($svc.Status -ne 'Running') { Start-Service 'MSSQL$SQLEXPRESS' }
  $server = '.\SQLEXPRESS'
  Write-Output "Using existing SQLEXPRESS"
} else {
  Write-Output "Installing SqlLocalDB via chocolatey..."
  choco install sqllocaldb -y --no-progress
  $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
  & sqllocaldb create MSSQLLocalDB -s 2>$null
  & sqllocaldb start MSSQLLocalDB
  # Share for IIS: create shared instance alias
  & sqllocaldb share MSSQLLocalDB ContosoShared 2>$null
  $server = '(localdb)\.\ContosoShared'
  # Fallback if share fails
  $probe = & sqlcmd -S $server -E -Q "SELECT 1" 2>&1
  if ($LASTEXITCODE -ne 0) {
    $server = '(localdb)\MSSQLLocalDB'
    Write-Output "Share unavailable; using $server (may need IIS pool profile)"
  }
}

$sqlcmd = Get-ChildItem "C:\Program Files\Microsoft SQL Server" -Recurse -Filter sqlcmd.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if ($sqlcmd) { $env:Path += ";" + $sqlcmd.DirectoryName }

Write-Output "Creating ContosoShipments on $server"
sqlcmd -S $server -E -Q "IF DB_ID('ContosoShipments') IS NULL CREATE DATABASE ContosoShipments;"
sqlcmd -S $server -E -d ContosoShipments -Q @"
IF OBJECT_ID('dbo.Shipments') IS NULL
CREATE TABLE dbo.Shipments (
  TrackingId NVARCHAR(64) NOT NULL PRIMARY KEY,
  Lane NVARCHAR(64) NOT NULL,
  WeightKg INT NOT NULL,
  Status NVARCHAR(32) NOT NULL,
  CreatedUtc DATETIME2 NOT NULL
);
"@

$cs = "Server=$server;Database=ContosoShipments;Integrated Security=True;Connection Timeout=5"
foreach ($cfg in @('C:\lab\app\ShipmentsWeb\Web.config','C:\lab\app\TrackingApi\Web.config','C:\lab\app\ShipmentsWorker\ShipmentsWorker.exe.config','C:\lab\app\ShipmentsWorker\App.config')) {
  if (-not (Test-Path $cfg)) { continue }
  [xml]$xml = Get-Content $cfg -Raw
  $node = $xml.SelectSingleNode("//connectionStrings/add[@name='ContosoShipments']")
  if ($node) {
    $node.SetAttribute('connectionString', $cs)
    $xml.Save($cfg)
    Write-Output "Updated connection string in $cfg"
  }
}

if ($server -like '*SQLEXPRESS*') {
  sqlcmd -S $server -E -Q "IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'IIS APPPOOL\SharedPool') CREATE LOGIN [IIS APPPOOL\SharedPool] FROM WINDOWS;"
  sqlcmd -S $server -E -d ContosoShipments -Q "IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'IIS APPPOOL\SharedPool') BEGIN CREATE USER [IIS APPPOOL\SharedPool] FOR LOGIN [IIS APPPOOL\SharedPool]; ALTER ROLE db_owner ADD MEMBER [IIS APPPOOL\SharedPool]; END"
} else {
  # LocalDB: enable loadUserProfile on pool so LocalDB works under app pool identity
  Import-Module WebAdministration
  Set-ItemProperty IIS:\AppPools\SharedPool -Name processModel.loadUserProfile -Value $true
  Write-Output "Enabled SharedPool loadUserProfile for LocalDB"
}

Import-Module WebAdministration
Restart-WebAppPool SharedPool
Set-Content C:\lab-sql.done ("server=$server; " + (Get-Date).ToString('o'))
Write-Output "SQL ready on $server"
Stop-Transcript
