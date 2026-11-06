$ErrorActionPreference = 'Stop'
function Set-AppSetting([string]$p, [string]$k, [string]$v) {
  [xml]$x = Get-Content $p
  $a = $x.SelectSingleNode('/configuration/appSettings')
  $n = $a.SelectSingleNode("add[@key='$k']")
  if (-not $n) {
    $n = $x.CreateElement('add')
    $n.SetAttribute('key', $k)
    [void]$a.AppendChild($n)
  }
  $n.SetAttribute('value', $v)
  $x.Save($p)
}
Set-AppSetting 'C:\lab\app\ShipmentsWeb\Web.config' 'ElasticApm:ServiceName' 'ShipmentsWeb'
Set-AppSetting 'C:\lab\app\TrackingApi\Web.config' 'ElasticApm:ServiceName' 'TrackingApi'
Select-String -Path 'C:\lab\app\ShipmentsWeb\Web.config','C:\lab\app\TrackingApi\Web.config' -Pattern 'ElasticApm:ServiceName'
Import-Module WebAdministration
Restart-WebAppPool SharedPool
Start-Sleep 6
$tid = 'XSVC-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$code = cmd /c "curl -sS -o NUL -w %{http_code} -X POST --data-urlencode trackingId=$tid --data-urlencode lane=DXB-AMM --data-urlencode weightKg=5 http://127.0.0.1/web/Checkout"
Write-Output "checkout=$code tid=$tid"
if ($code -ne '200') { throw "checkout failed $code" }
