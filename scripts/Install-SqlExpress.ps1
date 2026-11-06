# SQL Server 2022 Express install + ContosoShipments DB (longer media timeout; reuse partial downloads)
$ErrorActionPreference = "Continue"
Start-Transcript -Path "C:\lab-sql-install.log" -Append
New-Item -ItemType Directory -Force -Path "C:\lab\sql" | Out-Null

$svc = Get-Service 'MSSQL$SQLEXPRESS' -ErrorAction SilentlyContinue
if ($svc) {
  Write-Output "SQL Express already present: $($svc.Status)"
  if ($svc.Status -ne 'Running') { Start-Service 'MSSQL$SQLEXPRESS' }
} else {
  # Prefer chocolatey if present
  $choco = Get-Command choco -ErrorAction SilentlyContinue
  if ($choco) {
    Write-Output "Installing via chocolatey sql-server-express..."
    & choco install sql-server-express -y --params "'/INSTANCE=SQLEXPRESS'"
  }

  $svc = Get-Service 'MSSQL$SQLEXPRESS' -ErrorAction SilentlyContinue
  if (-not $svc) {
    Write-Output "Downloading SQL Express bootstrapper..."
    $bootstrap = "C:\lab\sql\SQL2022-SSEI-Expr.exe"
    if (-not (Test-Path $bootstrap) -and (Test-Path "C:\lab\SQL2022-SSEI-Expr.exe")) {
      Copy-Item "C:\lab\SQL2022-SSEI-Expr.exe" $bootstrap -Force
    }
    if (-not (Test-Path $bootstrap)) {
      Invoke-WebRequest "https://go.microsoft.com/fwlink/?linkid=2215158" -OutFile $bootstrap
    }
    $media = "C:\lab\sql\media"
    New-Item -ItemType Directory -Force -Path $media | Out-Null
    $setup = Get-ChildItem $media -Filter SETUP.EXE -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $setup) {
      Write-Output "Downloading media (up to 45 min)..."
      $p = Start-Process $bootstrap -PassThru -ArgumentList "/ACTION=Download /MEDIAPATH=$media /MEDIATYPE=Core /QUIET"
      if (-not $p.WaitForExit(2700000)) { try { $p.Kill() } catch {}; throw "SQL media download timeout" }
      Write-Output "Media download exit=$($p.ExitCode)"
      $setup = Get-ChildItem $media -Filter SETUP.EXE -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    if (-not $setup) { throw "SETUP.EXE not found after media download" }
    Write-Output "Installing SQLENGINE from $($setup.FullName)"
    $args = "/Q /ACTION=Install /IACCEPTSQLSERVERLICENSETERMS /FEATURES=SQLENGINE /INSTANCENAME=SQLEXPRESS /SQLSYSADMINACCOUNTS=`"Builtin\Administrators`" /TCPENABLED=1 /NPENABLED=0 /UpdateEnabled=0 /INDICATEPROGRESS"
    $p2 = Start-Process $setup.FullName -PassThru -ArgumentList $args
    if (-not $p2.WaitForExit(2700000)) { try { $p2.Kill() } catch {}; throw "SQL setup timeout" }
    Write-Output "SQL setup exit=$($p2.ExitCode)"
    Start-Sleep 5
    $svc = Get-Service 'MSSQL$SQLEXPRESS' -ErrorAction SilentlyContinue
    if (-not $svc) { throw "SQL Express service missing after install" }
  }
  Start-Service 'MSSQL$SQLEXPRESS' -ErrorAction SilentlyContinue
}

$sqlcmd = Get-Command sqlcmd -ErrorAction SilentlyContinue
if (-not $sqlcmd) {
  $sqlcmdPath = Get-ChildItem "C:\Program Files\Microsoft SQL Server" -Recurse -Filter sqlcmd.exe -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($sqlcmdPath) { $env:Path += ";" + $sqlcmdPath.DirectoryName }
}
sqlcmd -S ".\SQLEXPRESS" -E -Q "IF DB_ID('ContosoShipments') IS NULL CREATE DATABASE ContosoShipments;"
sqlcmd -S ".\SQLEXPRESS" -E -d ContosoShipments -Q @"
IF OBJECT_ID('dbo.Shipments') IS NULL
CREATE TABLE dbo.Shipments (
  TrackingId NVARCHAR(64) NOT NULL PRIMARY KEY,
  Lane NVARCHAR(64) NOT NULL,
  WeightKg INT NOT NULL,
  Status NVARCHAR(32) NOT NULL,
  CreatedUtc DATETIME2 NOT NULL
);
"@
sqlcmd -S ".\SQLEXPRESS" -E -Q @"
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'IIS APPPOOL\SharedPool')
BEGIN
  CREATE LOGIN [IIS APPPOOL\SharedPool] FROM WINDOWS;
END
"@
sqlcmd -S ".\SQLEXPRESS" -E -d ContosoShipments -Q @"
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'IIS APPPOOL\SharedPool')
BEGIN
  CREATE USER [IIS APPPOOL\SharedPool] FOR LOGIN [IIS APPPOOL\SharedPool];
  ALTER ROLE db_owner ADD MEMBER [IIS APPPOOL\SharedPool];
END
"@
Write-Output "SQL Express ready"
Set-Content C:\lab-sql.done ((Get-Date).ToString('o'))
Stop-Transcript
