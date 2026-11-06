# Fix port-80 binding, ensure Contoso IIS apps, wire OpenSSH authorized_keys from GCE metadata.
$ErrorActionPreference = "Continue"
Start-Transcript -Path "C:\lab-fix-iis.log" -Append
Import-Module WebAdministration -ErrorAction Stop

# Free port 80 from Default Web Site if present
if (Get-Website -Name "Default Web Site" -ErrorAction SilentlyContinue) {
  try { Stop-Website -Name "Default Web Site" -ErrorAction SilentlyContinue } catch {}
  try {
    Get-WebBinding -Name "Default Web Site" | ForEach-Object {
      Remove-WebBinding -Name "Default Web Site" -BindingInformation $_.bindingInformation -Protocol $_.protocol -ErrorAction SilentlyContinue
    }
  } catch {}
}

$siteName = "Shipments"
$poolName = "SharedPool"
$sitePath = "C:\lab\app\site-root"
$webPath = "C:\lab\app\ShipmentsWeb"
$apiPath = "C:\lab\app\TrackingApi"
New-Item -ItemType Directory -Force -Path $sitePath, $webPath, $apiPath, "C:\lab\logs" | Out-Null
Set-Content -Path "$sitePath\index.html" -Value "<html><body>Contoso Shipments root OK</body></html>" -Force

if (-not (Test-Path "IIS:\AppPools\$poolName")) { New-WebAppPool -Name $poolName | Out-Null }
Set-ItemProperty "IIS:\AppPools\$poolName" -Name managedRuntimeVersion -Value "v4.0"
Set-ItemProperty "IIS:\AppPools\$poolName" -Name enable32BitAppOnWin64 -Value $false

if (-not (Get-Website -Name $siteName -ErrorAction SilentlyContinue)) {
  New-Website -Name $siteName -Port 80 -PhysicalPath $sitePath -ApplicationPool $poolName | Out-Null
} else {
  Set-ItemProperty "IIS:\Sites\$siteName" -Name physicalPath -Value $sitePath
  Set-ItemProperty "IIS:\Sites\$siteName" -Name applicationPool -Value $poolName
  if (-not (Get-WebBinding -Name $siteName -ErrorAction SilentlyContinue)) {
    New-WebBinding -Name $siteName -Protocol http -Port 80 -IPAddress "*" | Out-Null
  }
}

function Ensure-App($vpath, $physical) {
  $name = $vpath.Trim('/')
  $full = "IIS:\Sites\$siteName\$name"
  if (-not (Test-Path $full)) {
    New-WebApplication -Site $siteName -Name $name -PhysicalPath $physical -ApplicationPool $poolName | Out-Null
  } else {
    Set-ItemProperty $full -Name physicalPath -Value $physical
    Set-ItemProperty $full -Name applicationPool -Value $poolName
  }
}
Ensure-App "web" $webPath
Ensure-App "tracking" $apiPath

# Confirm web bits exist
Write-Output "Web.dll present: $(Test-Path "$webPath\bin\ShipmentsWeb.dll")"
Write-Output "Api.dll present: $(Test-Path "$apiPath\bin\TrackingApi.dll")"
if (-not (Test-Path "$webPath\bin\ShipmentsWeb.dll") -or -not (Test-Path "$apiPath\bin\TrackingApi.dll")) {
  Write-Output "Republishing from C:\lab\src ..."
  $sln = Get-ChildItem -Path "C:\lab\src" -Filter "Contoso.Shipments.sln" -Recurse | Select-Object -First 1
  if ($sln) {
    & powershell -ExecutionPolicy Bypass -File "$($sln.Directory.FullName)\scripts\Build-And-Deploy.ps1"
  }
}

Start-Website -Name $siteName -ErrorAction SilentlyContinue
iisreset /noforce | Out-Null

try { $r = Invoke-WebRequest -UseBasicParsing http://127.0.0.1/ -TimeoutSec 20; Write-Output "GET / -> $($r.StatusCode)" } catch { Write-Output "GET / FAIL $($_.Exception.Message)" }
try { $r = Invoke-WebRequest -UseBasicParsing http://127.0.0.1/web/ -TimeoutSec 30; Write-Output "GET /web -> $($r.StatusCode) len=$($r.Content.Length)" } catch { Write-Output "GET /web FAIL $($_.Exception.Message)" }
try { $r = Invoke-WebRequest -UseBasicParsing http://127.0.0.1/tracking/api/tracking/CTR-DEMO01 -TimeoutSec 60; Write-Output "GET /tracking -> $($r.StatusCode)" } catch { Write-Output "GET /tracking NOTE $($_.Exception.Message)" }

# OpenSSH: place project ssh keys into administrators_authorized_keys for passwordless admin SSH
try {
  $meta = Invoke-RestMethod -Headers @{ "Metadata-Flavor" = "Google" } -Uri "http://metadata.google.internal/computeMetadata/v1/project/attributes/ssh-keys"
  $keys = @()
  foreach ($line in ($meta -split "`n")) {
    if ($line -match ':(ssh-\S+\s+\S+)') { $keys += $Matches[1] }
  }
  $sshDir = "$env:ProgramData\ssh"
  New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
  $auth = Join-Path $sshDir "administrators_authorized_keys"
  Set-Content -Path $auth -Value ($keys -join "`n") -Encoding ascii
  icacls $auth /inheritance:r | Out-Null
  icacls $auth /grant "SYSTEM:(F)" | Out-Null
  icacls $auth /grant "BUILTIN\Administrators:(F)" | Out-Null
  # Permit administrators group
  $sshdCfg = "$sshDir\sshd_config"
  if (Test-Path $sshdCfg) {
    (Get-Content $sshdCfg) | ForEach-Object {
      if ($_ -match '^\s*#?\s*PubkeyAuthentication') { 'PubkeyAuthentication yes' }
      elseif ($_ -match '^\s*#?\s*PasswordAuthentication') { 'PasswordAuthentication no' }
      else { $_ }
    } | Set-Content $sshdCfg
    if (-not (Select-String -Path $sshdCfg -Pattern 'Match Group administrators' -Quiet)) {
      Add-Content $sshdCfg "`nMatch Group administrators`n       AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys`n"
    }
  }
  Restart-Service sshd -Force -ErrorAction SilentlyContinue
  # Ensure yakov_keranchuk / darklord in Administrators
  foreach ($u in @('yakov_keranchuk','darklord')) {
    try { net localgroup Administrators $u /add | Out-Null } catch {}
  }
  Write-Output "OpenSSH admin keys configured: $($keys.Count) keys"
} catch { Write-Output "SSH key wiring note: $_" }

Set-Content -Path "C:\lab-phase2-iis-fixed.done" -Value ((Get-Date).ToString("o"))
Write-Output "Fix-Iis-And-Ssh complete"
Stop-Transcript
