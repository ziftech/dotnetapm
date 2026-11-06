# Recovery + Phase 2: tolerate partial first-boot, install OpenSSH, pull Contoso from GCS, build/deploy.
$ErrorActionPreference = "Continue"
Start-Transcript -Path "C:\lab-recover.log" -Append
New-Item -ItemType Directory -Force -Path "C:\lab", "C:\lab\logs" | Out-Null

function Ensure-OpenSSH {
  try {
    $cap = Get-WindowsCapability -Online -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'OpenSSH.Server*' }
    if ($cap -and $cap.State -ne 'Installed') {
      Write-Output "Installing OpenSSH Server capability..."
      Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 | Out-Null
    }
  } catch { Write-Output "OpenSSH install note: $_" }
  Start-Service sshd -ErrorAction SilentlyContinue
  Set-Service -Name sshd -StartupType Automatic -ErrorAction SilentlyContinue
  if (-not (Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -DisplayName "OpenSSH Server (sshd)" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction SilentlyContinue | Out-Null
  }
  Write-Output "sshd=$((Get-Service sshd -ErrorAction SilentlyContinue).Status)"
}

function Have-Iis { (Get-WindowsFeature Web-Server -ErrorAction SilentlyContinue).InstallState -eq 'Installed' }
function Have-MsBuild {
  $c = @(
    "${env:ProgramFiles}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
  ) | Where-Object { Test-Path $_ }
  return [bool]$c
}

Ensure-OpenSSH

if (-not (Have-Iis)) {
  Write-Output "Installing IIS..."
  Install-WindowsFeature -Name Web-Server, Web-Asp-Net45, Web-Net-Ext45, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Mgmt-Console, NET-Framework-45-ASPNET -IncludeManagementTools | Out-Null
}

if (-not (Have-MsBuild)) {
  Write-Output "Installing VS Build Tools..."
  Invoke-WebRequest "https://aka.ms/vs/17/release/vs_buildtools.exe" -OutFile "C:\lab\vs_buildtools.exe"
  Start-Process "C:\lab\vs_buildtools.exe" -Wait -ArgumentList "--quiet --wait --norestart --nocache --add Microsoft.VisualStudio.Workload.WebBuildTools --add Microsoft.Net.Component.4.8.TargetingPack --includeRecommended"
}

if (-not (Test-Path "C:\lab\nuget.exe")) {
  Invoke-WebRequest "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" -OutFile "C:\lab\nuget.exe"
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Output "Installing Git (optional)..."
  try {
    Invoke-WebRequest "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.1/Git-2.47.1-64-bit.exe" -OutFile "C:\lab\Git-64-bit.exe"
    Start-Process "C:\lab\Git-64-bit.exe" -Wait -ArgumentList "/VERYSILENT /NORESTART /NOCANCEL /SP-"
  } catch { Write-Output "Git install skipped: $_" }
}

# SQL Express best-effort with timeout; do not block Contoso deploy
$sqlSvc = Get-Service -Name 'MSSQL$SQLEXPRESS' -ErrorAction SilentlyContinue
if (-not $sqlSvc) {
  Write-Output "SQL Express not detected; attempting timed install (10 min max)..."
  try {
    $sqlMedia = "C:\lab\SQL2022-SSEI-Expr.exe"
    if (-not (Test-Path $sqlMedia)) {
      Invoke-WebRequest "https://go.microsoft.com/fwlink/?linkid=2215158" -OutFile $sqlMedia
    }
    $sqlExtract = "C:\lab\sqlexpress"
    New-Item -ItemType Directory -Force -Path $sqlExtract | Out-Null
    $p = Start-Process $sqlMedia -PassThru -ArgumentList "/ACTION=Download /MEDIAPATH=$sqlExtract /MEDIATYPE=Core /QUIET"
    if (-not $p.WaitForExit(300000)) { try { $p.Kill() } catch {}; Write-Output "SQL download timed out; continuing" }
    $sqlSetup = Get-ChildItem -Path $sqlExtract -Filter "SETUP.EXE" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($sqlSetup) {
      $p2 = Start-Process $sqlSetup.FullName -PassThru -ArgumentList "/Q /ACTION=Install /IACCEPTSQLSERVERLICENSETERMS /FEATURES=SQLENGINE /INSTANCENAME=SQLEXPRESS /SQLSYSADMINACCOUNTS=`"Builtin\Administrators`" /TCPENABLED=1 /UPDATEENABLED=0 /INDICATEPROGRESS"
      if (-not $p2.WaitForExit(600000)) { try { $p2.Kill() } catch {}; Write-Output "SQL setup timed out; continuing without SQL" }
    } else {
      Write-Output "SQL SETUP.EXE missing; continuing without SQL"
    }
  } catch { Write-Output "SQL install error (non-fatal): $_" }
} else {
  Write-Output "SQL Express service present: $($sqlSvc.Status)"
}

Set-Content -Path "C:\lab-setup.done" -Value ((Get-Date).ToString("o") + " recover")

if (Test-Path "C:\lab-phase2.done") {
  Write-Output "Phase 2 already complete"
  Stop-Transcript
  exit 0
}

Write-Output "Downloading Contoso sources..."
$token = (Invoke-RestMethod -Headers @{ "Metadata-Flavor" = "Google" } -Uri "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token").access_token
$zip = "C:\lab\contoso-shipments.zip"
Invoke-WebRequest -Uri "https://storage.googleapis.com/storage/v1/b/elastic-sa-contoso-apm-lab-yakovkeranchuk/o/contoso-shipments.zip?alt=media" -Headers @{ Authorization = "Bearer $token" } -OutFile $zip
Remove-Item "C:\lab\src" -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path "C:\lab\src" | Out-Null
Expand-Archive -Path $zip -DestinationPath "C:\lab\src" -Force
$sln = Get-ChildItem -Path "C:\lab\src" -Filter "Contoso.Shipments.sln" -Recurse | Select-Object -First 1
if (-not $sln) { throw "Contoso.Shipments.sln not found" }
$tree = $sln.Directory.FullName
Write-Output "Building from $tree"
& powershell -ExecutionPolicy Bypass -File "$tree\scripts\Build-And-Deploy.ps1"
$buildExit = $LASTEXITCODE

try {
  $r1 = Invoke-WebRequest -UseBasicParsing "http://127.0.0.1/web/" -TimeoutSec 30
  Write-Output "SMOKE /web -> $($r1.StatusCode)"
} catch { Write-Output "SMOKE /web FAIL: $($_.Exception.Message)" }
try {
  $r2 = Invoke-WebRequest -UseBasicParsing "http://127.0.0.1/tracking/api/tracking/CTR-DEMO01" -TimeoutSec 60
  Write-Output "SMOKE /tracking -> $($r2.StatusCode)"
} catch { Write-Output "SMOKE /tracking NOTE: $($_.Exception.Message)" }

if ($buildExit -eq 0) {
  Set-Content -Path "C:\lab-phase2.done" -Value ((Get-Date).ToString("o"))
  Write-Output "Phase 2 SUCCESS"
} else {
  Write-Output "Phase 2 BUILD FAILED exit=$buildExit"
}
Stop-Transcript
exit $buildExit
