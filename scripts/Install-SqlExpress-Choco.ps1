# Alternate SQL Express install via Chocolatey (more reliable than SSEI media download on this VM)
$ErrorActionPreference = "Continue"
Start-Transcript -Path "C:\lab-sql-choco.log" -Append
New-Item -ItemType Directory -Force -Path C:\lab\sql | Out-Null

if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
  Write-Output "Installing Chocolatey..."
  Set-ExecutionPolicy Bypass -Scope Process -Force
  [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
  iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
  $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
}

$svc = Get-Service 'MSSQL$SQLEXPRESS' -ErrorAction SilentlyContinue
if (-not $svc) {
  Write-Output "choco install sql-server-express..."
  choco install sql-server-express -y --no-progress
  Start-Sleep 10
  $svc = Get-Service 'MSSQL$SQLEXPRESS' -ErrorAction SilentlyContinue
}
if (-not $svc) {
  # fallback LocalDB for lab DB demos if Express package fails
  Write-Output "Express missing; trying SqlLocalDB..."
  choco install sqllocaldb -y --no-progress
}

if ($svc) {
  if ($svc.Status -ne 'Running') { Start-Service 'MSSQL$SQLEXPRESS' }
  $server = '.\SQLEXPRESS'
} else {
  $server = '(localdb)\MSSQLLocalDB'
  sqllocaldb start MSSQLLocalDB 2>$null
}

$sqlcmd = Get-ChildItem "C:\Program Files\Microsoft SQL Server" -Recurse -Filter sqlcmd.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if ($sqlcmd) { $env:Path += ";" + $sqlcmd.DirectoryName }

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
if ($server -like '*SQLEXPRESS*') {
  sqlcmd -S $server -E -Q "IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'IIS APPPOOL\SharedPool') CREATE LOGIN [IIS APPPOOL\SharedPool] FROM WINDOWS;"
  sqlcmd -S $server -E -d ContosoShipments -Q "IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'IIS APPPOOL\SharedPool') BEGIN CREATE USER [IIS APPPOOL\SharedPool] FOR LOGIN [IIS APPPOOL\SharedPool]; ALTER ROLE db_owner ADD MEMBER [IIS APPPOOL\SharedPool]; END"
}
Set-Content C:\lab-sql.done ("server=$server; " + (Get-Date).ToString('o'))
Write-Output "SQL ready on $server"
Stop-Transcript
