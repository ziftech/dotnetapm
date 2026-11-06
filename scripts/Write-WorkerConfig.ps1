$ErrorActionPreference = "Stop"
$dir = 'C:\lab\app\ShipmentsWorker'
# Ensure Dataflow present
if (Test-Path C:\lab\System.Threading.Tasks.Dataflow.dll) {
  Copy-Item C:\lab\System.Threading.Tasks.Dataflow.dll $dir -Force
}
$cfg = @'
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
        <assemblyIdentity name="System.Threading.Tasks.Dataflow" publicKeyToken="b03f5f7f11d50a3a" culture="neutral" />
        <bindingRedirect oldVersion="0.0.0.0-99.0.0.0" newVersion="4.6.3.0" />
      </dependentAssembly>
      <dependentAssembly>
        <assemblyIdentity name="System.Diagnostics.DiagnosticSource" publicKeyToken="cc7b13ffcd2ddd51" culture="neutral" />
        <bindingRedirect oldVersion="0.0.0.0-99.0.0.0" newVersion="8.0.0.1" />
      </dependentAssembly>
      <dependentAssembly>
        <assemblyIdentity name="System.Runtime.CompilerServices.Unsafe" publicKeyToken="b03f5f7f11d50a3a" culture="neutral" />
        <bindingRedirect oldVersion="0.0.0.0-99.0.0.0" newVersion="6.0.0.0" />
      </dependentAssembly>
      <dependentAssembly>
        <assemblyIdentity name="System.Memory" publicKeyToken="cc7b13ffcd2ddd51" culture="neutral" />
        <bindingRedirect oldVersion="0.0.0.0-99.0.0.0" newVersion="4.0.1.2" />
      </dependentAssembly>
      <dependentAssembly>
        <assemblyIdentity name="System.Buffers" publicKeyToken="cc7b13ffcd2ddd51" culture="neutral" />
        <bindingRedirect oldVersion="0.0.0.0-99.0.0.0" newVersion="4.0.3.0" />
      </dependentAssembly>
      <dependentAssembly>
        <assemblyIdentity name="System.Threading.Tasks.Extensions" publicKeyToken="cc7b13ffcd2ddd51" culture="neutral" />
        <bindingRedirect oldVersion="0.0.0.0-99.0.0.0" newVersion="4.2.0.1" />
      </dependentAssembly>
    </assemblyBinding>
  </runtime>
</configuration>
'@
Set-Content -Path (Join-Path $dir 'ShipmentsWorker.exe.config') -Value $cfg -Encoding UTF8
Write-Output 'wrote clean config'

# Soften Program exception logging via rebuild already done - just restart
Get-Process ShipmentsWorker -EA SilentlyContinue | Stop-Process -Force
Remove-Item C:\lab\logs\worker-out.txt,C:\lab\logs\worker-err.txt -Force -EA SilentlyContinue
Start-Sleep 2
Start-ScheduledTask ContosoShipmentsWorker
Start-Sleep 12
Write-Output "worker=$((Get-Process ShipmentsWorker -EA SilentlyContinue).Id)"
if (Test-Path C:\lab\logs\worker-out.txt) { Get-Content C:\lab\logs\worker-out.txt -Tail 25 }
if (Test-Path C:\lab\logs\worker-err.txt) { Write-Output '---err---'; Get-Content C:\lab\logs\worker-err.txt -Tail 40 }
