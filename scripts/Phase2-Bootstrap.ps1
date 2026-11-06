# Phase 2 bootstrap for GCE windows-startup-script-ps1 (runs every boot; gated by done files).
$ErrorActionPreference = "Continue"
Start-Transcript -Path "C:\lab-phase2.log" -Append

function Ensure-OpenSSH {
  try {
    $cap = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
    if ($cap -and $cap.State -ne 'Installed') {
      Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 | Out-Null
    }
  } catch { Write-Output "OpenSSH capability: $_" }
  Start-Service sshd -ErrorAction SilentlyContinue
  Set-Service -Name sshd -StartupType Automatic -ErrorAction SilentlyContinue
  if (-not (Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -DisplayName "OpenSSH Server (sshd)" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
  }
  Write-Output "sshd=$((Get-Service sshd -ErrorAction SilentlyContinue).Status)"
}

Ensure-OpenSSH

if (-not (Test-Path "C:\lab-setup.done")) {
  Write-Output "Waiting for first-boot C:\lab-setup.done ..."
  $deadline = (Get-Date).AddMinutes(90)
  while (-not (Test-Path "C:\lab-setup.done") -and (Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 30
  }
  if (-not (Test-Path "C:\lab-setup.done")) {
    Write-Output "ERROR: lab-setup.done missing after wait"
    Stop-Transcript
    exit 1
  }
}

if (Test-Path "C:\lab-phase2.done") {
  Write-Output "Phase 2 already done"
  Stop-Transcript
  exit 0
}

New-Item -ItemType Directory -Force -Path "C:\lab\src", "C:\lab\logs" | Out-Null
$zip = "C:\lab\contoso-shipments.zip"
Write-Output "Downloading Contoso zip from GCS..."
# Prefer gsutil if present; else BitsTransfer via public signed? Bucket is private — use gcloud/gsutil from guest.
$gsutil = Get-Command gsutil -ErrorAction SilentlyContinue
if (-not $gsutil) {
  # Use Google Cloud SDK path if installed by image, else Invoke via metadata curl alternative with instance SA
  $paths = @(
    "C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk\bin\gsutil.cmd",
    "C:\Program Files\Google\Cloud SDK\google-cloud-sdk\bin\gsutil.cmd"
  )
  foreach ($p in $paths) { if (Test-Path $p) { $gsutil = $p; break } }
}

# Fetch with instance service account via GCS JSON API using metadata token
$token = (Invoke-RestMethod -Headers @{ "Metadata-Flavor" = "Google" } -Uri "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token").access_token
$bucket = if ($env:LAB_BUCKET) { $env:LAB_BUCKET } else { 'dotnet-apm-lab-artifacts' }
$uri = "https://storage.googleapis.com/storage/v1/b/$bucket/o/contoso-shipments.zip?alt=media"
Invoke-WebRequest -Uri $uri -Headers @{ Authorization = "Bearer $token" } -OutFile $zip
if (-not (Test-Path $zip)) { throw "Failed to download contoso-shipments.zip" }

if (Test-Path "C:\lab\src") { Remove-Item "C:\lab\src" -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path "C:\lab\src" | Out-Null
Expand-Archive -Path $zip -DestinationPath "C:\lab\src" -Force

# Zip may expand with Contoso.Shipments.sln at root of C:\lab\src
$sln = Get-ChildItem -Path "C:\lab\src" -Filter "Contoso.Shipments.sln" -Recurse | Select-Object -First 1
if (-not $sln) { throw "Solution not found after expand" }
$tree = $sln.Directory.FullName
Write-Output "Solution tree: $tree"

powershell -ExecutionPolicy Bypass -File "$tree\scripts\Build-And-Deploy.ps1"
if ($LASTEXITCODE -ne 0) { throw "Build-And-Deploy failed: $LASTEXITCODE" }

# Smoke local HTTP
try {
  $r1 = Invoke-WebRequest -UseBasicParsing "http://localhost/web/" -TimeoutSec 30
  Write-Output "GET /web -> $($r1.StatusCode)"
} catch { Write-Output "GET /web FAILED: $_" }
try {
  $r2 = Invoke-WebRequest -UseBasicParsing "http://localhost/tracking/api/tracking/demo" -TimeoutSec 30
  Write-Output "GET /tracking -> $($r2.StatusCode)"
} catch { Write-Output "GET /tracking (may 200/404/500): $_" }

Set-Content -Path "C:\lab-phase2.done" -Value ((Get-Date).ToString("o"))
Write-Output "Phase 2 bootstrap complete"
Stop-Transcript
