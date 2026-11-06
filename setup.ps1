# Contoso APM lab - Windows Server 2022 first-boot setup (GCE windows-startup-script-ps1)
# Extended from vault clients/contoso/lab/setup.ps1: adds Git + SQL Server 2022 Express.
# Idempotent: exits if C:\lab-setup.done exists. Log: C:\lab-setup.log

$ErrorActionPreference = "Stop"
Start-Transcript -Path "C:\lab-setup.log" -Append
if (Test-Path "C:\lab-setup.done") { Write-Output "Already set up"; Stop-Transcript; exit 0 }

New-Item -ItemType Directory -Force -Path "C:\lab" | Out-Null

Write-Output "Installing IIS + ASP.NET 4.8..."
Install-WindowsFeature -Name Web-Server, Web-Asp-Net45, Web-Net-Ext45, Web-ISAPI-Ext, Web-ISAPI-Filter, `
  Web-Mgmt-Console, NET-Framework-45-ASPNET -IncludeManagementTools

Write-Output "Installing VS 2022 Build Tools (WebBuildTools + .NET Framework 4.8 targeting pack)..."
Invoke-WebRequest "https://aka.ms/vs/17/release/vs_buildtools.exe" -OutFile "C:\lab\vs_buildtools.exe"
Start-Process "C:\lab\vs_buildtools.exe" -Wait -ArgumentList `
  "--quiet --wait --norestart --nocache --add Microsoft.VisualStudio.Workload.WebBuildTools --add Microsoft.Net.Component.4.8.TargetingPack --includeRecommended"

Write-Output "Downloading nuget.exe..."
Invoke-WebRequest "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" -OutFile "C:\lab\nuget.exe"

Write-Output "Installing Git for Windows..."
$gitInstaller = "C:\lab\Git-64-bit.exe"
Invoke-WebRequest "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.1/Git-2.47.1-64-bit.exe" -OutFile $gitInstaller
Start-Process $gitInstaller -Wait -ArgumentList "/VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /COMPONENTS=`"icons,ext\reg\shellhere,assoc,assoc_sh`""

Write-Output "Installing SQL Server 2022 Express (SQLEngine only)..."
$sqlMedia = "C:\lab\SQL2022-SSEI-Expr.exe"
Invoke-WebRequest "https://go.microsoft.com/fwlink/?linkid=2215158" -OutFile $sqlMedia
# Download media then silent install engine
$sqlExtract = "C:\lab\sqlexpress"
New-Item -ItemType Directory -Force -Path $sqlExtract | Out-Null
Start-Process $sqlMedia -Wait -ArgumentList "/ACTION=Download /MEDIAPATH=$sqlExtract /MEDIATYPE=Core /QUIET"
$sqlSetup = Get-ChildItem -Path $sqlExtract -Filter "SETUP.EXE" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $sqlSetup) {
  Write-Output "WARNING: SQL Express SETUP.EXE not found after download; continuing without SQL. Check C:\lab-setup.log"
} else {
  # Windows authentication only — no SA password stored in this script
  Start-Process $sqlSetup.FullName -Wait -ArgumentList `
    "/Q /ACTION=Install /IACCEPTSQLSERVERLICENSETERMS /FEATURES=SQLENGINE /INSTANCENAME=SQLEXPRESS /SQLSYSADMINACCOUNTS=`"Builtin\Administrators`" /TCPENABLED=1 /UPDATEENABLED=0 /INDICATEPROGRESS"
  $sqlcmd = Get-Command sqlcmd -ErrorAction SilentlyContinue
  if ($sqlcmd) {
    sqlcmd -S ".\SQLEXPRESS" -E -Q "IF DB_ID('ContosoShipments') IS NULL CREATE DATABASE ContosoShipments;"
  }
}

Set-Content -Path "C:\lab-setup.done" -Value (Get-Date).ToString("o")
Write-Output "Setup complete"
Stop-Transcript
