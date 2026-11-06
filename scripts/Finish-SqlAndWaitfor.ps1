$ErrorActionPreference = "Continue"
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
$sqlcmd = Get-ChildItem "C:\Program Files\Microsoft SQL Server" -Recurse -Filter sqlcmd.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $sqlcmd) { throw "sqlcmd.exe not found" }
$env:Path += ";" + $sqlcmd.DirectoryName
Write-Output "whoami=$(whoami)"
Write-Output "sqlcmd=$($sqlcmd.FullName)"

$sql = ".\SQLEXPRESS"
$ok=$false
for ($i=0; $i -lt 40; $i++) {
  $null = & sqlcmd -S $sql -E -Q "SELECT @@VERSION" -h -1 2>&1
  if ($LASTEXITCODE -eq 0) { $ok=$true; break }
  Write-Output "wait connect i=$i exit=$LASTEXITCODE"
  Start-Sleep 3
}
if (-not $ok) { throw "SQL not accepting connections as $(whoami)" }

& sqlcmd -S $sql -E -Q "IF DB_ID('ContosoShipments') IS NULL CREATE DATABASE ContosoShipments;" | Write-Output
& sqlcmd -S $sql -E -d ContosoShipments -Q @"
IF OBJECT_ID('dbo.Shipments') IS NULL
CREATE TABLE dbo.Shipments (
  TrackingId NVARCHAR(64) NOT NULL PRIMARY KEY,
  Lane NVARCHAR(64) NOT NULL,
  WeightKg INT NOT NULL,
  Status NVARCHAR(32) NOT NULL,
  CreatedUtc DATETIME2 NOT NULL
);
"@ | Write-Output

# Grant IIS pool + interactive lab user
$users = @('IIS APPPOOL\SharedPool', 'ARAMEX-APM-LAB\yakov_keranchuk')
foreach ($u in $users) {
  & sqlcmd -S $sql -E -Q "IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'$u') CREATE LOGIN [$u] FROM WINDOWS;" | Write-Output
  & sqlcmd -S $sql -E -d ContosoShipments -Q "IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'$u') BEGIN CREATE USER [$u] FOR LOGIN [$u]; ALTER ROLE db_owner ADD MEMBER [$u]; END" | Write-Output
}

$cs = "Server=.\SQLEXPRESS;Database=ContosoShipments;Integrated Security=True;Connection Timeout=5"
foreach ($cfg in @('C:\lab\app\ShipmentsWeb\Web.config','C:\lab\app\TrackingApi\Web.config','C:\lab\app\ShipmentsWorker\ShipmentsWorker.exe.config')) {
  if (-not (Test-Path $cfg)) { continue }
  [xml]$xml = Get-Content $cfg -Raw
  $node = $xml.SelectSingleNode("//connectionStrings/add[@name='ContosoShipments']")
  if ($node) { $node.SetAttribute('connectionString', $cs); $xml.Save($cfg); Write-Output "Updated $cfg" }
}
try {
  Import-Module WebAdministration
  Restart-WebAppPool SharedPool
} catch { Write-Output "pool restart: $($_.Exception.Message)" }

Set-Content C:\lab-sql.done ("server=$sql; whoami=$(whoami); " + (Get-Date).ToString('o'))
Write-Output "SQL_READY"
& sqlcmd -S $sql -E -d ContosoShipments -Q "DECLARE @t DATETIME2 = SYSUTCDATETIME(); WAITFOR DELAY '00:00:02'; SELECT DATEDIFF(MILLISECOND, @t, SYSUTCDATETIME()) AS WaitMs;" | Write-Output
Get-Service 'MSSQL$SQLEXPRESS' | Format-Table Name,Status | Out-String | Write-Output
