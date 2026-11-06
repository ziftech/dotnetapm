$ErrorActionPreference = 'Continue'
# Probe Agent.IsConfigured inside w3wp via a tiny one-shot curl to an added diagnostic is hard.
# Instead inspect loaded assemblies from a throwaway AppDomain isn't possible cross-process.
# Log what Global.asax will see by compiling a tiny console with same dlls.

$bin = 'C:\lab\app\TrackingApi\bin'
$cs = @'
using System;
using Elastic.Apm;
class P {
  static void Main() {
    Console.WriteLine("IsConfigured=" + Agent.IsConfigured);
    Console.WriteLine("TracerNull=" + (Agent.Tracer == null));
    try {
      Console.WriteLine("ConfigEnabled=" + Agent.Config.Enabled);
    } catch (Exception ex) { Console.WriteLine("ConfigErr=" + ex.Message); }
    Console.WriteLine("ApmAsm=" + typeof(Agent).Assembly.FullName);
    Console.WriteLine("ApmLoc=" + typeof(Agent).Assembly.Location);
  }
}
'@
$tmp = 'C:\lab\tmp-agentcheck'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
Set-Content -Path "$tmp\P.cs" -Value $cs -Encoding ASCII
$refs = @(
  "$bin\Elastic.Apm.dll",
  "$bin\netstandard.dll"
) | Where-Object { Test-Path $_ }
# Prefer framework csc
$csc = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
& $csc /nologo /out:"$tmp\P.exe" /r:"$bin\Elastic.Apm.dll" "$tmp\P.cs"
Copy-Item "$bin\Elastic.Apm.dll" $tmp -Force
# copy deps commonly needed
Get-ChildItem $bin -Filter 'System.*.dll' | Copy-Item -Destination $tmp -Force -ErrorAction SilentlyContinue
Get-ChildItem $bin -Filter 'Elastic.*.dll' | Copy-Item -Destination $tmp -Force -ErrorAction SilentlyContinue
Push-Location $tmp
.\P.exe
Pop-Location
Write-Output 'NOTE: console without profiler will show IsConfigured=false; IIS w3wp with profiler is the real check.'
Write-Output 'Check shipments-web / tracking logs after restart for AGENT_IS_CONFIGURED lines.'
