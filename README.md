# Contoso Shipments — Contoso .NET APM lab (synthetic)

.NET Framework 4.8 estate with old-style `.csproj` + `packages.config`:

| Project | Role |
|---|---|
| `Contoso.Shipments.Business` | Custom DLL (pricing CPU, WAITFOR DELAY, deep call chain, swallowed exception) |
| `ShipmentsWeb` | ASP.NET MVC 5 + log4net; calls TrackingApi via HttpClient and HttpWebRequest |
| `TrackingApi` | ASP.NET Web API 2 + NLog; 4xx + occasional 500 |
| `ShipmentsWorker` | Console timer — non-HTTP entry point |

## IIS layout

- Site `Shipments` on port 80
- Applications `/web` and `/tracking`
- Shared pool `SharedPool`

## Build on the VM

```powershell
cd C:\lab\src
powershell -ExecutionPolicy Bypass -File .\scripts\Build-And-Deploy.ps1
```

Secrets stay in Mac `~/dev/dotnetapm/.env` only — never in this tree.
