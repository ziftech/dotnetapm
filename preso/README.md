# Contoso .NET APM — presentation

Animated customer deck (same player shell as [elastic-search-preso](https://ahmedzaky-creator.github.io/elastic-search-preso/#0)) for the Contoso lab story:

**Business spans without touching every method** — host agent (profiler or EDOT) + Fody aspects on C# and VB class libraries.

## Present

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

Static output lands in `preso/dist/` (base `./` for GitHub Pages or file open).

## Companion material

| File | Purpose |
|---|---|
| `public/downloads/presenter-notes.md` | Speaker outline |
| `public/downloads/demo-guide-instrumentation.md` | Copy of the lab instrumentation guide |
| `../docs/demo-guide-instrumentation.md` | Canonical guide in the repo |

## Content map (15 scenes)

1. Hero · 2 Objection · 3 Layers A/B/C · 4 Lab map · 5 Profiler · 6 EDOT · 7 Weave · 8 C# · 9 VB · 10 Backends · 11 Waterfall · 12 Labels · 13 Logs · 14 Demo script · 15 Close

Player chrome adapted from the public Elastic Search presentation engine; Contoso scenes, diagrams, and notes are original to this lab.
