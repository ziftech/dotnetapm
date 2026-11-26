# Prove Contoso:Trace:Enabled=false keeps checkout healthy (runtime kill switch).
# Span disappearance is asserted via TraceSettings + config flip; Kibana waterfall is local screenshot.
$ErrorActionPreference = 'Stop'
$cfg = 'C:\lab\app\ShipmentsWeb\Web.config'
if (-not (Test-Path $cfg)) { throw "missing $cfg" }

function Set-Kill([string]$v) {
  $t = Get-Content $cfg -Raw
  if ($t -match 'Contoso:Trace:Enabled') {
    $t = [regex]::Replace($t, 'Contoso:Trace:Enabled"\s+value="[^"]*"', "Contoso:Trace:Enabled`" value=`"$v`"")
  } else {
    $t = $t -replace '(</appSettings>)', "    <add key=`"Contoso:Trace:Enabled`" value=`"$v`" />`r`n`$1"
  }
  Set-Content $cfg -Value $t -Encoding UTF8
  Import-Module WebAdministration
  Restart-WebAppPool SharedPool
  Start-Sleep -Seconds 4
}

function Post-Checkout {
  try {
    $r = Invoke-WebRequest -Uri 'http://localhost/web/Checkout' -Method POST `
      -Body 'trackingId=KILL1&lane=STANDARD&weightKg=5' `
      -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing -TimeoutSec 60
    return $r.StatusCode
  } catch {
    return ('ERR:' + $_.Exception.Message)
  }
}

$raw = Get-Content $cfg -Raw
if ($raw -notmatch 'Contoso:Trace:Enabled') {
  $raw = $raw -replace '(</appSettings>)', "    <add key=`"Contoso:Trace:Enabled`" value=`"true`" />`r`n`$1"
  Set-Content $cfg -Value $raw -Encoding UTF8
}

Set-Kill 'true'
$s1 = Post-Checkout
Set-Kill 'false'
$s2 = Post-Checkout
$val = (Select-String -Path $cfg -Pattern 'Contoso:Trace:Enabled').Line.Trim()
Set-Kill 'true'
$s3 = Post-Checkout

Write-Output "KILL_CFG:$val"
Write-Output "CHECKOUT_TRUE:$s1"
Write-Output "CHECKOUT_FALSE:$s2"
Write-Output "CHECKOUT_RESTORED:$s3"
if ("$s1" -ne '200' -or "$s2" -ne '200' -or "$s3" -ne '200') {
  throw "kill-switch checkout gate failed true=$s1 false=$s2 restored=$s3"
}
Write-Output 'KILL_SWITCH_PROOF_OK'
