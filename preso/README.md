# Contoso .NET APM — presentation

Public animated deck for the Contoso lab story:

**Business spans without touching every method** — host agent (profiler or EDOT) + Fody aspects on C# and VB class libraries.

## Live

https://ziftech.github.io/dotnetapm/

Player shell follows the pattern of [elastic-search-preso](https://ahmedzaky-creator.github.io/elastic-search-preso/#0) (scenes, density, notes, filmstrip). Contoso content is original to this repo.

## Present locally

```sh
cd preso
npm ci
npm run dev -- --port 4175
```

Open http://127.0.0.1:4175/#0

- Arrows, Space, Page keys, swipes → change slides
- Animations loop on the current slide · `R` replay
- `G` overview · `T` filmstrip · `N` notes · `F` fullscreen · `1–5` density
- `L` laser · `D` draw · `C` clear · `?` help

## Build

```sh
npm run build
```

Pages is served from the `gh-pages` branch. Republish after deck changes:

```sh
./scripts/Publish-PresoPages.sh
```

An Actions workflow example lives at `preso/github-pages.workflow.yml.example` (needs a token with `workflow` scope to install under `.github/workflows/`).


## Companion material

| File | Purpose |
|---|---|
| `public/downloads/presenter-notes.md` | Speaker outline |
| `public/downloads/demo-guide-instrumentation.md` | Instrumentation guide |
| `../docs/demo-guide-instrumentation.md` | Canonical guide in the repo |

## Content map (7 scenes)

1. Hero · 2 Layers A/B/C · 3 Host agent · 4 Aspects (C#/VB) · 5 Profiler vs EDOT backends · 6 Checkout proof · 7 Close

High-level approach only — details live in `docs/demo-guide-instrumentation.md`.

See `THIRD_PARTY_NOTICES.md` for player-shell attribution.
