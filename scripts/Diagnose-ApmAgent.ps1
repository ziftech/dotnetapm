$ErrorActionPreference = "Stop"
$code = @'
using System;
using System.Reflection;
using Elastic.Apm;
class D {
  static void Main() {
    Get-Env();
    AgentComponents c = new AgentComponents();
    object cfg = c.ConfigurationReader;
    Dump("ConfigurationReader", cfg);
    Console.WriteLine("PayloadSender null=" + (c.PayloadSender==null) + " Tracer null=" + (c.Tracer==null));
    // Try constructing with explicit components via Activator if needed
    try {
      Type psType = Type.GetType("Elastic.Apm.Report.PayloadSenderV2, Elastic.Apm");
      Console.WriteLine("PayloadSenderV2 type=" + (psType==null?"null":psType.FullName));
    } catch (Exception ex) { Console.WriteLine(ex); }
    // Inspect ctor exception by creating via reflection step by step
    Type act = typeof(AgentComponents);
    foreach (var ctor in act.GetConstructors()) {
      Console.WriteLine("ctor " + ctor);
    }
    try {
      Agent.Setup(c);
    } catch (Exception ex) { Console.WriteLine("Setup " + ex); }
    Console.WriteLine("after Tracer null=" + (Agent.Tracer==null));
  }
  static void Get-Env() {
    Console.WriteLine("URL=" + Environment.GetEnvironmentVariable("ELASTIC_APM_SERVER_URL"));
    Console.WriteLine("KEY_SET=" + (!string.IsNullOrEmpty(Environment.GetEnvironmentVariable("ELASTIC_APM_API_KEY"))));
    Console.WriteLine("ENABLED=" + Environment.GetEnvironmentVariable("ELASTIC_APM_ENABLED"));
    Console.WriteLine("SERVICE=" + Environment.GetEnvironmentVariable("ELASTIC_APM_SERVICE_NAME"));
  }
  static void Dump(string label, object o) {
    Console.WriteLine("== " + label + " ==");
    if (o == null) { Console.WriteLine("null"); return; }
    Type t = o.GetType();
    Console.WriteLine("type=" + t.FullName);
    foreach (PropertyInfo p in t.GetProperties(BindingFlags.Public|BindingFlags.Instance)) {
      try {
        object v = p.GetValue(o, null);
        string s = v == null ? "null" : v.ToString();
        if (s.Length > 200) s = s.Substring(0,200)+"...";
        Console.WriteLine("  " + p.Name + " = " + s);
      } catch (Exception ex) { Console.WriteLine("  " + p.Name + " ERR " + ex.GetBaseException().Message); }
    }
    // also interfaces
    foreach (Type i in t.GetInterfaces()) {
      foreach (PropertyInfo p in i.GetProperties()) {
        try {
          object v = p.GetValue(o, null);
          string s = v == null ? "null" : v.ToString();
          if (s.Length > 200) s = s.Substring(0,200)+"...";
          Console.WriteLine("  I:" + i.Name + "." + p.Name + " = " + s);
        } catch {}
      }
    }
  }
}
'@
# Fix invalid method name for C#
$code = $code -replace 'Get-Env\(\)','ShowEnv()' -replace 'Get-Env;','ShowEnv();'
$dir = 'C:\lab\apm-diag'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Set-Content "$dir\D.cs" $code
$apm = 'C:\lab\src\packages\Elastic.Apm.1.34.7\lib\net462\Elastic.Apm.dll'
Copy-Item $apm $dir -Force
Copy-Item 'C:\lab\app\ShipmentsWorker\*.dll' $dir -Force
Get-Content C:\lab\logs\start-worker.bat | ForEach-Object {
  if ($_ -match '^set ([^=]+)=(.*)$') { Set-Item -Path "Env:$($Matches[1])" -Value $Matches[2] }
}
$csc = "${env:WINDIR}\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
& $csc /nologo /r:"$dir\Elastic.Apm.dll" /out:$dir\D.exe $dir\D.cs
if ($LASTEXITCODE -ne 0) { throw "csc failed" }
Push-Location $dir
& .\D.exe
Pop-Location
