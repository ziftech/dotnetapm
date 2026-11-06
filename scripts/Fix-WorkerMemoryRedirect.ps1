$ErrorActionPreference = "Stop"
$dir = 'C:\lab\app\ShipmentsWorker'
Get-Process ShipmentsWorker -EA SilentlyContinue | Stop-Process -Force
Start-Sleep 3

# Report versions
foreach ($name in @('System.Memory','System.Buffers','System.Diagnostics.DiagnosticSource','System.Threading.Tasks.Dataflow','System.Runtime.CompilerServices.Unsafe','System.Threading.Tasks.Extensions','Elastic.Apm')) {
  $p = Join-Path $dir ($name + '.dll')
  if (Test-Path $p) {
    $an = [Reflection.AssemblyName]::GetAssemblyName($p)
    Write-Output "$name => $($an.Version)"
  } else { Write-Output "$name MISSING" }
}

# Rewrite config with exact versions present on disk
$mem = ([Reflection.AssemblyName]::GetAssemblyName((Join-Path $dir 'System.Memory.dll'))).Version.ToString()
$buf = ([Reflection.AssemblyName]::GetAssemblyName((Join-Path $dir 'System.Buffers.dll'))).Version.ToString()
$ds  = ([Reflection.AssemblyName]::GetAssemblyName((Join-Path $dir 'System.Diagnostics.DiagnosticSource.dll'))).Version.ToString()
$df  = ([Reflection.AssemblyName]::GetAssemblyName((Join-Path $dir 'System.Threading.Tasks.Dataflow.dll'))).Version.ToString()
$uns = ([Reflection.AssemblyName]::GetAssemblyName((Join-Path $dir 'System.Runtime.CompilerServices.Unsafe.dll'))).Version.ToString()
$te  = ([Reflection.AssemblyName]::GetAssemblyName((Join-Path $dir 'System.Threading.Tasks.Extensions.dll'))).Version.ToString()

$cfg = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <connectionStrings>
    <add name="ContosoShipments" connectionString="Server=.\SQLEXPRESS;Database=ContosoShipments;Integrated Security=True;Connection Timeout=5" providerName="System.Data.SqlClient" />
  </connectionStrings>
  <appSettings>
    <add key="IntervalSeconds" value="5" />
  </appSettings>
  <startup>
    <supportedRuntime version="v4.0" sku=".NETFramework,Version=v4.8" />
  </startup>
  <runtime>
    <assemblyBinding xmlns="urn:schemas-microsoft-com:asm.v1">
      <dependentAssembly>
        <assemblyIdentity name="System.Memory" publicKeyToken="cc7b13ffcd2ddd51" culture="neutral" />
        <bindingRedirect oldVersion="0.0.0.0-99.0.0.0" newVersion="$mem" />
      </dependentAssembly>
      <dependentAssembly>
        <assemblyIdentity name="System.Buffers" publicKeyToken="cc7b13ffcd2ddd51" culture="neutral" />
        <bindingRedirect oldVersion="0.0.0.0-99.0.0.0" newVersion="$buf" />
      </dependentAssembly>
      <dependentAssembly>
        <assemblyIdentity name="System.Diagnostics.DiagnosticSource" publicKeyToken="cc7b13ffcd2ddd51" culture="neutral" />
        <bindingRedirect oldVersion="0.0.0.0-99.0.0.0" newVersion="$ds" />
      </dependentAssembly>
      <dependentAssembly>
        <assemblyIdentity name="System.Threading.Tasks.Dataflow" publicKeyToken="b03f5f7f11d50a3a" culture="neutral" />
        <bindingRedirect oldVersion="0.0.0.0-99.0.0.0" newVersion="$df" />
      </dependentAssembly>
      <dependentAssembly>
        <assemblyIdentity name="System.Runtime.CompilerServices.Unsafe" publicKeyToken="b03f5f7f11d50a3a" culture="neutral" />
        <bindingRedirect oldVersion="0.0.0.0-99.0.0.0" newVersion="$uns" />
      </dependentAssembly>
      <dependentAssembly>
        <assemblyIdentity name="System.Threading.Tasks.Extensions" publicKeyToken="cc7b13ffcd2ddd51" culture="neutral" />
        <bindingRedirect oldVersion="0.0.0.0-99.0.0.0" newVersion="$te" />
      </dependentAssembly>
    </assemblyBinding>
  </runtime>
</configuration>
"@
# UTF8 no BOM
[System.IO.File]::WriteAllText((Join-Path $dir 'ShipmentsWorker.exe.config'), $cfg)
Write-Output 'config written'
Remove-Item C:\lab\logs\worker-out.txt,C:\lab\logs\worker-err.txt -Force -EA SilentlyContinue
Start-ScheduledTask ContosoShipmentsWorker
Start-Sleep 15
Write-Output "worker=$((Get-Process ShipmentsWorker -EA SilentlyContinue).Id)"
Get-Content C:\lab\logs\worker-out.txt -Tail 30 -ErrorAction SilentlyContinue
Write-Output '---err---'
Get-Content C:\lab\logs\worker-err.txt -Tail 20 -ErrorAction SilentlyContinue
