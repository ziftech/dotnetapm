# Download Elastic APM .NET profiler 1.34.7 (customer-matching version)
param(
  [string]$Version = "1.34.7"
)
$ErrorActionPreference = "Stop"
$dest = "C:\elastic\apm-agent-dotnet"
New-Item -ItemType Directory -Force -Path $dest, "C:\lab\apm" | Out-Null
$zip = "C:\lab\apm\elastic_apm_profiler_$Version-win-x64.zip"
$url = "https://github.com/elastic/apm-agent-dotnet/releases/download/v$Version/elastic_apm_profiler_$Version-win-x64.zip"
Write-Output "Downloading $url"
Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
# Also fetch full agent zip (NuGet-compatible assemblies for reference installs)
$agentZip = "C:\lab\apm\ElasticApmAgent_$Version.zip"
$agentUrl = "https://github.com/elastic/apm-agent-dotnet/releases/download/v$Version/ElasticApmAgent_$Version.zip"
Write-Output "Downloading $agentUrl"
Invoke-WebRequest -Uri $agentUrl -OutFile $agentZip -UseBasicParsing
$agentDest = "C:\elastic\apm-agent-dotnet-full"
New-Item -ItemType Directory -Force -Path $agentDest | Out-Null
Expand-Archive -Path $agentZip -DestinationPath $agentDest -Force
Write-Output "Full agent extracted to $agentDest"
if (Test-Path $dest) { Remove-Item "$dest\*" -Recurse -Force -ErrorAction SilentlyContinue }
Expand-Archive -Path $zip -DestinationPath $dest -Force
# Unblock DLLs on Windows
Get-ChildItem $dest -Recurse -Include *.dll | Unblock-File -ErrorAction SilentlyContinue
Write-Output "Profiler extracted to $dest"
Get-ChildItem $dest | Select-Object Name | Format-Table | Out-String | Write-Output
Set-Content "C:\lab-apm-profiler-$Version.done" ((Get-Date).ToString('o'))
