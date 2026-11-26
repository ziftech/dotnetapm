# NuGet zero-code verification

Generated: 2026-11-26 16:14 Asia/Dubai (2026-11-26T12:14:40Z)

## Package install (lab)

- Contoso.Shipments.Business and Contoso.Shipments.LegacyVb consume Contoso.Observability 1.0.0 from ./artifacts.
- Hand-written assembly Trace attributes removed; package targets generate them (TypeFilter=Service$).

## Weave

See weave-csharp.json / weave-vb.json.

## Traffic smoke

- GET /web/Checkout: ok=20 fail=0 (20 tries)
- POST /web/Checkout: status=200

## Runtime kill switch

- Contoso:Trace:Enabled in Web.config disables spans without rebuild (TraceSettings).

## Screenshots

Local only (gitignored). Capture waterfall / service names / log correlation on the lab workstation.

## Overhead

Run scripts/Run-Overhead10m.ps1 for the 10-minute success-rate gate.
