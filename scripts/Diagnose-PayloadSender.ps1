$ErrorActionPreference = "Stop"
$code = @'
using System;
using System.Diagnostics;
using System.Reflection;
using Elastic.Apm;
using Elastic.Apm.Logging;
class D {
  static void Main() {
    Trace.Listeners.Add(new ConsoleTraceListener());
    Environment.SetEnvironmentVariable("ELASTIC_APM_LOG_LEVEL", "Trace");
    try {
      Type t = typeof(AgentComponents);
      // call parameterless via Activator
      object c = Activator.CreateInstance(t);
      DumpComponents("Activator.CreateInstance", c);
    } catch (Exception ex) { Console.WriteLine("Activator fail: " + ex); }

    try {
      // Force PayloadSenderV2 construction
      Type ps = Type.GetType("Elastic.Apm.Report.PayloadSenderV2, Elastic.Apm");
      Console.WriteLine("PS type " + ps);
      foreach (var ctor in ps.GetConstructors(BindingFlags.Public|BindingFlags.NonPublic|BindingFlags.Instance)) {
        Console.WriteLine("PS ctor: " + ctor);
        var psparams = ctor.GetParameters();
        foreach (var p in psparams) Console.WriteLine("  param " + p.ParameterType.Name + " " + p.Name);
      }
    } catch (Exception ex) { Console.WriteLine("PS inspect " + ex); }

    // Read AgentComponents .cctor / instance ctor via method body not available; instead hook logger
    try {
      var loggerType = Type.GetType("Elastic.Apm.Logging.ConsoleLogger, Elastic.Apm");
      object logger = null;
      if (loggerType != null) {
        var inst = loggerType.GetProperty("Instance", BindingFlags.Public|BindingFlags.Static);
        if (inst != null) logger = inst.GetValue(null, null);
        Console.WriteLine("ConsoleLogger=" + logger);
      }
      var c2 = new AgentComponents((IApmLogger)logger, null, null);
      DumpComponents("with ConsoleLogger", c2);
      if (c2.Tracer != null) {
        Agent.Setup(c2);
        Agent.Tracer.CaptureTransaction("diag-tx", "request", () => { Console.WriteLine("inside tx"); });
        System.Threading.Thread.Sleep(3000);
        Console.WriteLine("capture ok");
      }
    } catch (Exception ex) { Console.WriteLine("logger path " + ex); }
  }
  static void DumpComponents(string label, object c) {
    Console.WriteLine("== " + label + " ==");
    var t = c.GetType();
    foreach (var f in t.GetFields(BindingFlags.Instance|BindingFlags.NonPublic|BindingFlags.Public)) {
      var v = f.GetValue(c);
      Console.WriteLine("F " + f.Name + " => " + (v==null?"null":v.GetType().Name));
    }
    foreach (var p in t.GetProperties()) {
      try {
        var v = p.GetValue(c, null);
        Console.WriteLine("P " + p.Name + " => " + (v==null?"null":v.ToString()));
      } catch (Exception ex) { Console.WriteLine("P " + p.Name + " ERR " + ex.Message); }
    }
  }
}
'@
$dir='C:\lab\apm-diag'
Set-Content "$dir\PS.cs" $code
Get-Content C:\lab\logs\start-worker.bat | ForEach-Object {
  if ($_ -match '^set ([^=]+)=(.*)$') { Set-Item -Path "Env:$($Matches[1])" -Value $Matches[2] }
}
Copy-Item C:\lab\src\packages\Elastic.Apm.1.34.7\lib\net462\Elastic.Apm.dll $dir -Force
Copy-Item C:\lab\app\ShipmentsWorker\*.dll $dir -Force
$csc = "${env:WINDIR}\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
& $csc /nologo /r:"$dir\Elastic.Apm.dll" /out:$dir\PS.exe $dir\PS.cs
if ($LASTEXITCODE -ne 0) { throw "csc failed" }
Push-Location $dir
& .\PS.exe
Pop-Location
