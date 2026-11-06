# Align profiler net462/net472 dependency DLLs with Elastic.Apm 1.34.7 NuGet dependency versions
# so app-bin references (Observability/Fody) do not break profiler AssemblyResolve.
$ErrorActionPreference = "Stop"
$nuget = "C:\lab\nuget.exe"
$pkgs = "C:\lab\src\packages"
$tmp = "C:\lab\apm-dep-restore"
New-Item -ItemType Directory -Force -Path $tmp, $pkgs | Out-Null

$needed = @(
  'System.Threading.Tasks.Dataflow:8.0.1',
  'System.Diagnostics.DiagnosticSource:8.0.1',
  'System.Runtime.CompilerServices.Unsafe:6.0.0',
  'System.Memory:4.5.5',
  'System.Buffers:4.5.1',
  'System.Threading.Tasks.Extensions:4.5.4',
  'System.Collections.Immutable:8.0.0',
  'System.Reflection.Metadata:8.0.1'
)
Set-Location $tmp
foreach ($n in $needed) {
  $id, $ver = $n.Split(':')
  Write-Output "nuget install $id $ver"
  & $nuget install $id -Version $ver -OutputDirectory $pkgs -NonInteractive | Out-Null
}

function Copy-Dep([string]$id, [string]$ver, [string]$rel) {
  $src = Join-Path $pkgs "$id.$ver\$rel"
  if (-not (Test-Path $src)) {
    $cand = Get-ChildItem (Join-Path $pkgs "$id.$ver\lib") -Recurse -Filter ($id + ".dll") -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cand) { $src = $cand.FullName }
  }
  if (-not (Test-Path $src)) { Write-Output "MISSING $id $ver"; return }
  foreach ($tfm in @('net462','net472')) {
    $destDir = "C:\elastic\apm-agent-dotnet\$tfm"
    if (-not (Test-Path $destDir)) { continue }
    Copy-Item $src (Join-Path $destDir (Split-Path $src -Leaf)) -Force
    Write-Output "Copied $(Split-Path $src -Leaf) -> $tfm"
  }
}

Copy-Dep 'System.Threading.Tasks.Dataflow' '8.0.1' 'lib\net462\System.Threading.Tasks.Dataflow.dll'
Copy-Dep 'System.Diagnostics.DiagnosticSource' '8.0.1' 'lib\net462\System.Diagnostics.DiagnosticSource.dll'
Copy-Dep 'System.Runtime.CompilerServices.Unsafe' '6.0.0' 'lib\net461\System.Runtime.CompilerServices.Unsafe.dll'
Copy-Dep 'System.Memory' '4.5.5' 'lib\net461\System.Memory.dll'
Copy-Dep 'System.Buffers' '4.5.1' 'lib\net461\System.Buffers.dll'
Copy-Dep 'System.Threading.Tasks.Extensions' '4.5.4' 'lib\net461\System.Threading.Tasks.Extensions.dll'
Copy-Dep 'System.Collections.Immutable' '8.0.0' 'lib\net462\System.Collections.Immutable.dll'
Copy-Dep 'System.Reflection.Metadata' '8.0.1' 'lib\net462\System.Reflection.Metadata.dll'

# Also ensure Elastic.Apm.dll in profiler home matches package
Copy-Item "$pkgs\Elastic.Apm.1.34.7\lib\net462\Elastic.Apm.dll" "C:\elastic\apm-agent-dotnet\net462\Elastic.Apm.dll" -Force -ErrorAction SilentlyContinue
Copy-Item "$pkgs\Elastic.Apm.1.34.7\lib\net472\Elastic.Apm.dll" "C:\elastic\apm-agent-dotnet\net472\Elastic.Apm.dll" -Force -ErrorAction SilentlyContinue

Import-Module WebAdministration
Stop-WebAppPool SharedPool
Start-Sleep 3
Get-Process w3wp -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep 2
Start-WebAppPool SharedPool
Start-Sleep 5
Write-Output "Profiler deps repaired; pool recycled"
try { Write-Output ("web=" + (Invoke-WebRequest http://127.0.0.1/web/ -UseBasicParsing -TimeoutSec 20).StatusCode) } catch { Write-Output $_.Exception.Message }
try { Write-Output ("api=" + (Invoke-WebRequest http://127.0.0.1/tracking/api/tracking/repaired1 -UseBasicParsing -TimeoutSec 20).StatusCode) } catch { Write-Output $_.Exception.Message }
