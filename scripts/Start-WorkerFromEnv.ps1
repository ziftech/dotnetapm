$ErrorActionPreference = "Stop"
$map=@{}
Get-Content "$env:USERPROFILE\worker-apm.env" | ForEach-Object {
  if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
  $i=$_.IndexOf('='); $map[$_.Substring(0,$i).Trim()] = $_.Substring($i+1).Trim()
}
Get-Process ShipmentsWorker -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
$dir='C:\lab\app\ShipmentsWorker'
$exe=Join-Path $dir 'ShipmentsWorker.exe'
# deps
Copy-Item C:\lab\src\packages\Elastic.Apm.1.34.7\lib\net462\Elastic.Apm.dll $dir -Force
Copy-Item C:\lab\src\src\Contoso.Observability\bin\Release\*.dll $dir -Force
Copy-Item C:\lab\src\src\Contoso.Shipments.Business\bin\Release\*.dll $dir -Force
Copy-Item C:\lab\src\packages\System.Diagnostics.DiagnosticSource.8.0.1\lib\net462\System.Diagnostics.DiagnosticSource.dll $dir -Force -EA SilentlyContinue
Copy-Item C:\lab\src\packages\System.Runtime.CompilerServices.Unsafe.6.0.0\lib\net461\System.Runtime.CompilerServices.Unsafe.dll $dir -Force -EA SilentlyContinue
Copy-Item C:\lab\src\packages\System.Memory.4.5.5\lib\net461\System.Memory.dll $dir -Force -EA SilentlyContinue
Copy-Item C:\lab\src\packages\System.Buffers.4.5.1\lib\net461\System.Buffers.dll $dir -Force -EA SilentlyContinue
Copy-Item C:\lab\src\packages\System.Threading.Tasks.Extensions.4.5.4\lib\net461\System.Threading.Tasks.Extensions.dll $dir -Force -EA SilentlyContinue
Copy-Item C:\lab\src\packages\MethodBoundaryAspect.Fody.3.6.0\lib\net462\MethodBoundaryAspect.dll $dir -Force -EA SilentlyContinue
Copy-Item C:\lab\System.Threading.Tasks.Dataflow.dll $dir -Force -EA SilentlyContinue
Copy-Item C:\lab\app\ShipmentsWorker\System.Threading.Tasks.Dataflow.dll $dir -Force -EA SilentlyContinue

# interval
[xml]$xml = Get-Content (Join-Path $dir 'ShipmentsWorker.exe.config')
$n=$xml.SelectSingleNode("//appSettings/add[@key='IntervalSeconds']"); if($n){$n.SetAttribute('value','5'); $xml.Save((Join-Path $dir 'ShipmentsWorker.exe.config'))}

New-Item -ItemType Directory -Force -Path C:\lab\logs | Out-Null
$out='C:\lab\logs\worker-out.txt'; $err='C:\lab\logs\worker-err.txt'
Remove-Item $out,$err -Force -EA SilentlyContinue

# Persist APM env for the worker process via a wrapper bat (Start-Process env inheritance is limited)
$bat = @'
@echo off
set ELASTIC_APM_SERVER_URL={0}
set ELASTIC_APM_API_KEY={1}
set ELASTIC_APM_SERVICE_NAME=ShipmentsWorker
set ELASTIC_APM_ENVIRONMENT=lab
set ELASTIC_APM_APPLICATION_NAMESPACES=Contoso.
set ELASTIC_APM_ENABLED=true
set ELASTIC_APM_LOG_LEVEL=Info
cd /d "{2}"
"{3}" >> "{4}" 2>> "{5}"
'@ -f $map['ELASTIC_APM_SERVER_URL'], $map['ELASTIC_APM_API_KEY'], $dir, $exe, $out, $err
$batPath = 'C:\lab\logs\start-worker.bat'
Set-Content -Path $batPath -Value $bat -Encoding ASCII

$p = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', $batPath -WindowStyle Hidden -PassThru
Start-Sleep 8
$w = Get-Process ShipmentsWorker -ErrorAction SilentlyContinue
if ($w) {
  Write-Output "worker RUNNING pid=$($w.Id) launcher=$($p.Id)"
} else {
  Write-Output "worker NOT RUNNING after start"
  if (Test-Path $out) { Write-Output '--- out ---'; Get-Content $out -Tail 50 }
  if (Test-Path $err) { Write-Output '--- err ---'; Get-Content $err -Tail 50 }
}
Remove-Item "$env:USERPROFILE\worker-apm.env" -Force -EA SilentlyContinue
