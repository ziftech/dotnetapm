import "./fonts.css";
import "@fontsource/ibm-plex-mono/latin-400.css";
import "./style.css";
import "./visuals.css";
import { scenes } from "./scenes";
import { renderVisual } from "./visuals";
import logoUrl from "./assets/elastic-logo.svg?url";
import type { Scene } from "./types";
import { topic } from "./topic";

const app = document.querySelector<HTMLDivElement>("#app")!;
const params = new URLSearchParams(location.search);
const printMode = params.has("print");
const staticMode = params.get("render") === "static" || printMode;
const reducedMotion = matchMedia("(prefers-reduced-motion: reduce)");
const esc = (s: string) =>
  s.replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ]!,
  );
const clamp = (v: number, min: number, max: number) =>
  Math.max(min, Math.min(max, v));
const readDensity = () => {
  try {
    return Number(localStorage.getItem(topic.storageKey)) || 3;
  } catch {
    return 3;
  }
};
const readSceneIndex = () => {
  const value = Number(location.hash.slice(1));
  return clamp(
    Number.isFinite(value) ? Math.trunc(value) : 0,
    0,
    scenes.length - 1,
  );
};
let index = readSceneIndex();
let density = clamp(Number(params.get("density")) || readDensity(), 1, 5);
let step = startingStep(index);
let notesOpen = false;
let filmstripOpen = false;
let laserOn = false;
let drawOn = false;
let startTime = Date.now();
let pausedAt = 0;
let timerInterval: ReturnType<typeof setInterval> | undefined;
let animationTimeout: ReturnType<typeof setTimeout> | undefined;
let animationGeneration = 0;
let currentPath: SVGPathElement | null = null;
let points = "";
let swipeStart: { x: number; y: number } | null = null;
const thumbData = JSON.parse(
  document.querySelector("#thumbnail-data")?.textContent || "[]",
) as string[];
const fileMode = location.protocol === "file:";
const downloadBase =
  fileMode || document.documentElement.hasAttribute("data-offline")
    ? "./"
    : "./downloads/";
const icon = (path: string) =>
  `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="${path}"/></svg>`;
const icons = {
  overview: icon("M3 3h7v7H3z M14 3h7v7h-7z M3 14h7v7H3z M14 14h7v7h-7z"),
  film: icon("M3 4h18v16H3z M3 9h18 M3 15h18 M8 4v16 M16 4v16"),
  notes: icon("M5 3h14v18H5z M8 7h8 M8 11h8 M8 15h5"),
  full: icon("M3 9V3h6 M15 3h6v6 M21 15v6h-6 M9 21H3v-6"),
  laser: icon("M12 3v5 M12 16v5 M3 12h5 M16 12h5 M9 9h6v6H9z"),
  pen: icon("M4 20l1-6L16 3l5 5L10 19z M13 6l5 5"),
  replay: icon("M5 8a8 8 0 1 1-1 8 M5 3v6h6"),
  down: icon("M12 3v12 M7 10l5 5 5-5 M4 17v4h16v-4"),
};

function startingStep(sceneIndex: number) {
  return staticMode || reducedMotion.matches
    ? (scenes[sceneIndex].steps?.length || 1) - 1
    : 0;
}

function animationProgress(scene: Scene) {
  return scene.steps
    ? `${scene.steps.map((s, n) => `<span class="step-dot ${n === step ? "current" : n < step ? "done" : ""}" title="${esc(s.label)}"></span>`).join("")}<span>${esc(scene.steps[step]?.label || "")} <small>${step + 1}/${scene.steps.length}</small></span>`
    : "";
}

function stopAnimation() {
  if (animationTimeout !== undefined) clearTimeout(animationTimeout);
  animationTimeout = undefined;
  animationGeneration++;
}

function scheduleAnimation() {
  stopAnimation();
  const count = scenes[index].steps?.length || 1;
  if (
    staticMode ||
    reducedMotion.matches ||
    count < 2 ||
    document.hidden ||
    document.querySelector("dialog[open]") ||
    drawOn
  )
    return;
  const generation = animationGeneration;
  const sceneIndex = index;
  const delay = step === count - 1 ? 4800 : 3200;
  animationTimeout = setTimeout(() => {
    if (generation !== animationGeneration || index !== sceneIndex) return;
    step = (step + 1) % count;
    const visual = document.querySelector(".visual-stage")!;
    visual.innerHTML = renderVisual(scenes[index], {
      step,
      settled: false,
      density,
    });
    visual.querySelector(".presentation-visual")?.classList.add("auto-frame");
    document.querySelector(".step-strip")!.innerHTML = animationProgress(
      scenes[index],
    );
    document.querySelector<HTMLElement>(".slide")!.dataset.step = String(step);
    signalReady();
    scheduleAnimation();
  }, delay);
}

function slideMarkup(
  scene: Scene,
  i: number,
  sceneStep: number,
  settled: boolean,
) {
  const longest = Math.max(scene.headline.length, scene.emphasis.length);
  return `<article class="slide ${scene.layout} ${longest > 38 ? "long-title" : ""} ${longest > 52 ? "very-long-title" : ""} ${settled ? "settled" : ""}" data-scene="${i}" data-scene-id="${esc(scene.id)}" data-density="${density}" data-step="${sceneStep}" aria-label="Slide ${i + 1}: ${esc(scene.headline + " " + scene.emphasis)}">
    <header class="scene-eyebrow reveal" style="--delay:0ms"><span class="tiny-square"></span>${esc(scene.eyebrow)}<span class="scene-marker">${scene.illustrative ? "ILLUSTRATIVE SCENARIO" : "ELASTIC SEARCH"}</span></header>
    <div class="scene-copy"><h1 class="reveal" style="--delay:60ms">${esc(scene.headline)}<em>${esc(scene.emphasis)}</em></h1><p class="lead reveal" style="--delay:130ms">${esc(scene.lead)}</p></div>
    <div class="visual-stage">${renderVisual(scene, { step: sceneStep, settled, density })}</div>
    ${scene.steps ? `<div class="step-strip" aria-label="Animation progress">${scene.steps.map((s, n) => `<span class="step-dot ${n === sceneStep ? "current" : n < sceneStep ? "done" : ""}" title="${esc(s.label)}"></span>`).join("")}<span>${esc(scene.steps[sceneStep]?.label || "")} <small>${sceneStep + 1}/${scene.steps.length}</small></span></div>` : ""}
    <p class="density-extra reveal" style="--delay:380ms">${esc(scene.densityExtra)}<span class="density-deep"><b>REQUIREMENTS</b>${esc(scene.qualification)}</span></p>
    <div class="takeaways">${scene.takeaways.map((t, n) => `<div class="takeaway reveal" style="--delay:${400 + n * 90}ms"><span class="takeaway-label">${esc(t.label)}</span><h2>${esc(t.value)}</h2><p>${esc(t.detail)}</p></div>`).join("")}</div>
    <p class="qualification">${esc(scene.qualification)}</p>
    <div class="source-strip"><span>SOURCES</span>${scene.sources.map((s) => `<a href="${esc(s.url)}" target="_blank" rel="noopener noreferrer">${esc(s.label)} ↗</a>`).join("")}</div>
    <footer class="scene-footer"><img src="${logoUrl}" width="93" height="34" alt="Elastic" /><span>ELASTIC SEARCH · ${esc(scene.chapter)}<b>${String(i + 1).padStart(2, "0")}</b></span></footer>
  </article>`;
}

function mount() {
  if (printMode) {
    document.body.classList.add("print-view");
    app.innerHTML = scenes
      .map(
        (s, i) =>
          `<div class="print-page">${slideMarkup(s, i, (s.steps?.length || 1) - 1, true)}</div>`,
      )
      .join("");
    signalReady();
    return;
  }
  if (staticMode) {
    document.body.classList.add("capture-view");
    app.innerHTML = `<div class="stage-wrap"><div id="stage-mount"></div></div>`;
    render();
    return;
  }
  app.innerHTML = `<div class="presentation-shell">
    <header class="topbar"><div class="brand">Elastic <strong>Search</strong></div>
      <div class="nav-controls"><button id="prev" class="arrow" aria-label="Previous slide" title="Previous slide · ←">‹</button><span id="counter" class="counter"></span><button id="next" class="arrow" aria-label="Next slide" title="Next slide · →">›</button></div>
      <div class="main-tools"><button id="overview-toggle" title="Overview · G">${icons.overview}<span>Overview</span></button><button id="filmstrip-toggle" title="Filmstrip · T">${icons.film}<span>Filmstrip</span></button><div class="density-control" aria-label="Content density"><span>Density</span>${[1, 2, 3, 4, 5].map((n) => `<button data-density="${n}" aria-label="Density ${n}" aria-pressed="${n === density}">${n}</button>`).join("")}</div><button id="notes-toggle" title="Speaker notes · N">${icons.notes}<span>Notes</span></button><button id="fullscreen" title="Fullscreen · F">${icons.full}<span>Present</span></button><button id="help-toggle" class="help-button" aria-label="Presentation help and downloads">?</button></div>
    </header>
    <main class="presentation-main"><div class="stage-wrap" id="stage-wrap"><div id="stage-mount"></div><svg id="ink" viewBox="0 0 1280 720" aria-label="Presentation annotations"></svg><div id="laser-dot" aria-hidden="true"></div></div><aside class="notes-panel" id="notes-panel" aria-label="Speaker notes" hidden></aside></main>
    <nav id="filmstrip" class="filmstrip" aria-label="Slide filmstrip" hidden></nav>
    <footer class="player-footer"><span id="chapter-label"></span><div id="progress" class="progress" aria-label="Slide progress"></div><div class="footer-tools"><button id="timer" title="Pause or resume presenter timer" aria-label="Pause presenter timer">00:00</button><button id="replay" title="Replay · R" aria-label="Replay current slide">${icons.replay}</button><button id="laser-toggle" title="Laser · L" aria-label="Toggle laser pointer">${icons.laser}</button><button id="draw-toggle" title="Draw · D" aria-label="Toggle drawing">${icons.pen}</button><button id="clear-ink" title="Clear drawing · C" aria-label="Clear drawing">Clear</button></div></footer>
    <dialog id="overview-dialog" aria-label="Slide overview"></dialog><dialog id="help-dialog" aria-label="Presentation help"></dialog><dialog id="appendix-dialog" aria-label="EDOT outlook appendix"></dialog>
  </div><div id="toast" role="status"></div>`;
  bindControls();
  render();
  timerInterval = setInterval(updateTimer, 1000);
}

function render() {
  stopAnimation();
  const s = scenes[index];
  if (staticMode || reducedMotion.matches) step = (s.steps?.length || 1) - 1;
  if (!staticMode)
    history.replaceState(
      { presentation: topic.historyId, index },
      "",
      `#${index}`,
    );
  document.querySelector("#stage-mount")!.innerHTML = slideMarkup(
    s,
    index,
    step,
    staticMode || reducedMotion.matches,
  );
  document.title = `${topic.title} · ${index + 1}/${scenes.length} · ${s.headline} ${s.emphasis}`;
  if (!staticMode) {
    document.querySelector("#counter")!.innerHTML =
      `<strong>${String(index + 1).padStart(2, "0")}</strong><span>/ ${scenes.length}</span>`;
    document.querySelector("#chapter-label")!.textContent = s.chapter;
    document.querySelector<HTMLButtonElement>("#prev")!.disabled = index === 0;
    document.querySelector<HTMLButtonElement>("#next")!.disabled =
      index === scenes.length - 1;
    document.querySelector("#progress")!.innerHTML = scenes
      .map(
        (x, n) =>
          `<button data-goto="${n}" class="${n === index ? "active" : n < index ? "past" : ""}" aria-label="Go to slide ${n + 1}: ${esc(x.headline)}" aria-current="${n === index ? "step" : "false"}"></button>`,
      )
      .join("");
    document
      .querySelectorAll<HTMLButtonElement>("[data-density]")
      .forEach((b) => {
        if (b.tagName === "BUTTON")
          b.setAttribute(
            "aria-pressed",
            String(Number(b.dataset.density) === density),
          );
      });
    renderNotes();
    if (filmstripOpen) renderFilmstrip();
    clearInk();
    resize();
  } else resize();
  signalReady();
  scheduleAnimation();
}

function signalReady() {
  document.documentElement.dataset.ready = "true";
  document.documentElement.dataset.slide = String(index);
  document.documentElement.dataset.step = String(step);
  document.documentElement.dataset.density = String(density);
  (window as Window & { __PRESENTATION__?: unknown }).__PRESENTATION__ = {
    count: scenes.length,
    index,
    step,
    density,
    scenes: scenes.map((s, i) => ({
      index: i,
      id: s.id,
      visual: s.visual,
      title: `${s.headline} ${s.emphasis}`,
      chapter: s.chapter,
      notes: s.notes,
      qualification: s.qualification,
      sources: s.sources,
      steps: s.steps,
    })),
  };
}

function gotoScene(n: number) {
  n = clamp(n, 0, scenes.length - 1);
  if (n === index) {
    step = startingStep(n);
    render();
    return;
  }
  index = n;
  step = startingStep(n);
  history.pushState({ presentation: topic.historyId, index }, "", `#${index}`);
  render();
}

function move(dir: number) {
  if ((dir < 0 && index === 0) || (dir > 0 && index === scenes.length - 1))
    return;
  gotoScene(index + dir);
}

function setDensity(n: number) {
  density = clamp(n, 1, 5);
  try {
    localStorage.setItem(topic.storageKey, String(density));
  } catch {
    /* Offline privacy settings can disable storage. */
  }
  render();
}

function renderNotes() {
  const s = scenes[index];
  const panel = document.querySelector<HTMLElement>("#notes-panel")!;
  panel.hidden = !notesOpen;
  panel.innerHTML = `<div class="notes-heading"><span>SPEAKER NOTES</span><button id="close-notes" aria-label="Close speaker notes">×</button></div><div class="notes-meta">SCENE ${index + 1} · ${Math.round(s.notes.seconds)} SECONDS</div><h2>${esc(s.headline)} ${esc(s.emphasis)}</h2><h3>Open</h3><p>${esc(s.notes.opening)}</p><h3>Explain</h3><p>${esc(s.notes.body)}</p>${s.notes.prompt ? `<h3>Ask</h3><p class="note-prompt">${esc(s.notes.prompt)}</p>` : ""}<h3>Transition</h3><p>${esc(s.notes.transition)}</p><h3>Qualification</h3><p class="note-qualification">${esc(s.qualification)}</p><h3>Public evidence</h3><ul>${s.sources.map((x) => `<li><a href="${esc(x.url)}" target="_blank" rel="noopener noreferrer">${esc(x.label)} ↗</a></li>`).join("")}</ul><p class="notes-warning">Hide notes before sharing this window.</p>`;
  panel.querySelector("#close-notes")!.addEventListener("click", toggleNotes);
  document
    .querySelector("#notes-toggle")!
    .classList.toggle("active", notesOpen);
}

function toggleNotes() {
  notesOpen = !notesOpen;
  renderNotes();
  resize();
}
function thumbSrc(i: number) {
  return thumbData[i] || `./thumbnails/${String(i + 1).padStart(2, "0")}.png`;
}
function thumbButton(s: Scene, i: number, mode: string) {
  return `<button class="thumb ${i === index ? "selected" : ""}" data-goto="${i}" aria-label="Go to slide ${i + 1}: ${esc(s.headline + " " + s.emphasis)}"><span class="thumb-image"><img src="${thumbSrc(i)}" alt="Slide ${i + 1} preview" loading="lazy" /><span class="thumb-fallback">${esc(s.headline)}<em>${esc(s.emphasis)}</em></span></span><span class="thumb-title"><b>${String(i + 1).padStart(2, "0")}</b>${esc(mode === "overview" ? s.headline + " " + s.emphasis : s.headline)}</span></button>`;
}

function renderFilmstrip() {
  const el = document.querySelector<HTMLElement>("#filmstrip")!;
  el.hidden = !filmstripOpen;
  el.innerHTML = scenes.map((s, i) => thumbButton(s, i, "film")).join("");
  el.querySelector<HTMLElement>(".selected")?.scrollIntoView({
    block: "nearest",
    inline: "center",
  });
  el.querySelectorAll<HTMLImageElement>("img").forEach((img) =>
    img.addEventListener("error", () => img.classList.add("missing")),
  );
}

function showOverview() {
  const d = document.querySelector<HTMLDialogElement>("#overview-dialog")!;
  d.innerHTML = `<div class="dialog-header"><div><span class="mono">THE WHOLE STORY</span><h2>34 scenes. One connected argument.</h2></div><button data-close aria-label="Close overview">×</button></div><div class="overview-grid">${scenes.map((s, i) => thumbButton(s, i, "overview")).join("")}</div>`;
  d.showModal();
  scheduleAnimation();
  d.querySelectorAll<HTMLImageElement>("img").forEach((img) =>
    img.addEventListener("error", () => img.classList.add("missing")),
  );
}

function showHelp() {
  const d = document.querySelector<HTMLDialogElement>("#help-dialog")!;
  d.innerHTML = `<div class="dialog-header"><div><span class="mono">CONTROLS</span><h2>Keyboard & companion files</h2></div><button data-close aria-label="Close help">×</button></div><div class="help-content"><div><h3>Keyboard</h3><dl class="shortcuts"><dt>← / → · Space · Page keys</dt><dd>Move directly between slides</dd><dt>Home / End</dt><dd>First / last scene</dd><dt>1–5</dt><dd>Content density · default 3</dd><dt>G / T / N / F</dt><dd>Overview / filmstrip / notes / fullscreen</dd><dt>R / L / D / C</dt><dd>Replay / laser / draw / clear ink</dd><dt>Esc</dt><dd>Close an overlay or leave pointer tools</dd></dl><p class="help-caption">Animations play and loop automatically while you stay on a slide. R restarts the current slide. Diagrams are illustrative. Sources appear on each scene and in the notes.</p></div><div><h3>Take it with you</h3><a class="download-link" href="${downloadBase}presenter-notes.md" download>${icons.down}Presenter notes</a><a class="download-link" href="${downloadBase}demo-guide-instrumentation.md" download>${icons.down}Instrumentation guide</a><button class="appendix-link" id="open-appendix">Outlook: EDOT migration ↗</button><p class="help-caption">Sample pattern for .NET Framework 4.8 (C# + VB). Feature availability depends on your Elastic deployment and agent/EDOT version.</p></div></div>`;
  d.showModal();
  scheduleAnimation();
  d.querySelector("#open-appendix")!.addEventListener("click", () => {
    d.close();
    showAppendix();
  });
}

function showAppendix() {
  const d = document.querySelector<HTMLDialogElement>("#appendix-dialog")!;
  d.innerHTML = `<div class="dialog-header"><div><span class="mono">OPTIONAL OUTLOOK · ${topic.evidenceDate.toUpperCase()}</span><h2>EDOT direction</h2></div><button data-close aria-label="Close appendix">×</button></div><div class="appendix-content"><span class="status-pill">OPENTELEMETRY · ELASTIC DISTRIBUTION</span><h3>Same aspects.<br/><em>OTLP export.</em></h3><p>Contoso keeps Fody TraceAttribute unchanged and swaps TraceBackends.Current to ActivitySourceTraceBackend when OTEL_EXPORTER_OTLP_ENDPOINT is present. TrackingApi demonstrates EDOT beside profiler-backed ShipmentsWeb.</p><div class="watch-row"><span>Profiler today</span><span>Shared aspects</span><span>EDOT host</span><span>OTLP ingest</span></div><a href="https://www.elastic.co/docs/reference/opentelemetry/edot-sdks/dotnet" target="_blank" rel="noopener noreferrer">EDOT .NET documentation ↗</a><p><b>Migration is optional.</b> Framework IIS teams can start with the Elastic .NET profiler plus aspects, then move hosts to EDOT without re-weaving business DLLs.</p><a href="https://www.elastic.co/docs/reference/opentelemetry/edot-sdks/dotnet/migration" target="_blank" rel="noopener noreferrer">Migrate from APM .NET agent ↗</a><p>No live OTLP session runs inside this deck — use a running Contoso sample host for side-by-side proof.</p></div>`;
  d.showModal();
  scheduleAnimation();
}

function bindControls() {
  document
    .querySelectorAll("dialog")
    .forEach((dialog) => dialog.addEventListener("close", scheduleAnimation));
  document.querySelector("#prev")!.addEventListener("click", () => move(-1));
  document.querySelector("#next")!.addEventListener("click", () => move(1));
  document
    .querySelector("#overview-toggle")!
    .addEventListener("click", showOverview);
  document.querySelector("#filmstrip-toggle")!.addEventListener("click", () => {
    filmstripOpen = !filmstripOpen;
    renderFilmstrip();
    document
      .querySelector("#filmstrip-toggle")!
      .classList.toggle("active", filmstripOpen);
    resize();
  });
  document
    .querySelector("#notes-toggle")!
    .addEventListener("click", toggleNotes);
  document.querySelector("#fullscreen")!.addEventListener("click", fullscreen);
  document.querySelector("#help-toggle")!.addEventListener("click", showHelp);
  document.querySelector("#replay")!.addEventListener("click", () => {
    step = 0;
    render();
  });
  document
    .querySelector("#laser-toggle")!
    .addEventListener("click", toggleLaser);
  document.querySelector("#draw-toggle")!.addEventListener("click", toggleDraw);
  document.querySelector("#clear-ink")!.addEventListener("click", clearInk);
  document.querySelector("#timer")!.addEventListener("click", () => {
    if (pausedAt) {
      startTime += Date.now() - pausedAt;
      pausedAt = 0;
    } else pausedAt = Date.now();
    updateTimer();
  });
  document.addEventListener("click", (e) => {
    const target = (e.target as HTMLElement).closest<HTMLElement>(
      "[data-goto], [data-density], [data-close]",
    );
    if (!target) return;
    if (target.dataset.goto != null) {
      document
        .querySelectorAll<HTMLDialogElement>("dialog[open]")
        .forEach((x) => x.close());
      gotoScene(Number(target.dataset.goto));
    } else if (target.dataset.density != null && target.tagName === "BUTTON")
      setDensity(Number(target.dataset.density));
    else if (target.hasAttribute("data-close"))
      target.closest("dialog")?.close();
  });
  document.addEventListener("keydown", (e) => {
    if (
      e.ctrlKey ||
      e.metaKey ||
      e.altKey ||
      (e.target as HTMLElement).matches(
        "input, textarea, select, [contenteditable]",
      )
    )
      return;
    if (
      (e.target as HTMLElement).closest('button, a, [role="button"]') &&
      (e.key === " " || e.key === "Enter")
    )
      return;
    if (document.querySelector("dialog[open]")) return;
    const key = e.key.toLowerCase();
    const handlers: Record<string, () => void> = {
      arrowright: () => move(1),
      pagedown: () => move(1),
      " ": () => move(1),
      arrowleft: () => move(-1),
      pageup: () => move(-1),
      home: () => gotoScene(0),
      end: () => gotoScene(scenes.length - 1),
      g: showOverview,
      t: () =>
        document.querySelector<HTMLButtonElement>("#filmstrip-toggle")!.click(),
      n: toggleNotes,
      f: fullscreen,
      r: () => {
        step = 0;
        render();
      },
      l: toggleLaser,
      d: toggleDraw,
      c: clearInk,
      "?": showHelp,
      escape: () => {
        laserOn = false;
        drawOn = false;
        syncTools();
      },
    };
    if (/^[1-5]$/.test(key)) {
      e.preventDefault();
      setDensity(Number(key));
      return;
    }
    if (handlers[key]) {
      e.preventDefault();
      handlers[key]();
    }
  });
  const wrap = document.querySelector<HTMLElement>("#stage-wrap")!;
  wrap.addEventListener("pointermove", (e) => {
    const box = wrap.getBoundingClientRect();
    const x = ((e.clientX - box.left) * 1280) / box.width;
    const y = ((e.clientY - box.top) * 720) / box.height;
    if (laserOn) {
      const dot = document.querySelector<HTMLElement>("#laser-dot")!;
      dot.style.left = `${(x / 1280) * 100}%`;
      dot.style.top = `${(y / 720) * 100}%`;
      dot.classList.add("visible");
    }
    if (currentPath && drawOn) {
      points += ` L ${x.toFixed(1)} ${y.toFixed(1)}`;
      currentPath.setAttribute("d", points);
    }
  });
  wrap.addEventListener("pointerleave", () =>
    document.querySelector("#laser-dot")!.classList.remove("visible"),
  );
  wrap.addEventListener("pointerdown", (e) => {
    if (!drawOn) {
      if (e.pointerType === "touch")
        swipeStart = { x: e.clientX, y: e.clientY };
      return;
    }
    e.preventDefault();
    const b = wrap.getBoundingClientRect();
    const x = ((e.clientX - b.left) * 1280) / b.width,
      y = ((e.clientY - b.top) * 720) / b.height;
    currentPath = document.createElementNS(
      "http://www.w3.org/2000/svg",
      "path",
    );
    points = `M ${x.toFixed(1)} ${y.toFixed(1)}`;
    currentPath.setAttribute("d", points);
    document.querySelector("#ink")!.appendChild(currentPath);
    wrap.setPointerCapture(e.pointerId);
  });
  wrap.addEventListener("pointerup", (e) => {
    currentPath = null;
    if (swipeStart && !drawOn) {
      const dx = e.clientX - swipeStart.x,
        dy = e.clientY - swipeStart.y;
      if (Math.abs(dx) > 45 && Math.abs(dx) > Math.abs(dy) * 1.5)
        move(dx < 0 ? 1 : -1);
    }
    swipeStart = null;
  });
  wrap.addEventListener("pointercancel", () => {
    currentPath = null;
    swipeStart = null;
  });
}

function resize() {
  const wrap = document.querySelector<HTMLElement>(".stage-wrap");
  if (!wrap) return;
  if (staticMode) {
    const factor = Math.min(window.innerWidth / 1280, window.innerHeight / 720);
    wrap.style.width = `${1280 * factor}px`;
    wrap.style.height = `${720 * factor}px`;
    document.querySelector<HTMLElement>("#stage-mount")!.style.transform =
      `scale(${factor})`;
    return;
  }
  const main = document.querySelector<HTMLElement>(".presentation-main")!;
  const notesWidth = notesOpen && window.innerWidth > 700 ? 346 : 0;
  const style = getComputedStyle(main);
  const paddingX =
    parseFloat(style.paddingLeft) + parseFloat(style.paddingRight);
  const paddingY =
    parseFloat(style.paddingTop) + parseFloat(style.paddingBottom);
  const factor = Math.min(
    (main.clientWidth - notesWidth - paddingX) / 1280,
    (main.clientHeight - paddingY) / 720,
  );
  wrap.style.width = `${1280 * factor}px`;
  wrap.style.height = `${720 * factor}px`;
  document.querySelector<HTMLElement>("#stage-mount")!.style.transform =
    `scale(${factor})`;
}

async function fullscreen() {
  try {
    if (!document.fullscreenElement)
      await document.documentElement.requestFullscreen();
    else await document.exitFullscreen();
  } catch {
    toast(
      "Fullscreen is unavailable here. Use your browser’s fullscreen control.",
    );
  }
}
function toggleLaser() {
  laserOn = !laserOn;
  if (laserOn) drawOn = false;
  syncTools();
}
function toggleDraw() {
  drawOn = !drawOn;
  if (drawOn) laserOn = false;
  syncTools();
}
function syncTools() {
  document.querySelector("#laser-toggle")?.classList.toggle("active", laserOn);
  document.querySelector("#draw-toggle")?.classList.toggle("active", drawOn);
  document.querySelector("#stage-wrap")?.classList.toggle("drawing", drawOn);
  document.querySelector("#stage-wrap")?.classList.toggle("lasering", laserOn);
  if (!laserOn)
    document.querySelector("#laser-dot")?.classList.remove("visible");
  scheduleAnimation();
}
function clearInk() {
  const ink = document.querySelector("#ink");
  if (ink) ink.innerHTML = "";
  currentPath = null;
}
function updateTimer() {
  const seconds = Math.floor(((pausedAt || Date.now()) - startTime) / 1000);
  const button = document.querySelector<HTMLButtonElement>("#timer");
  if (button) {
    button.textContent = `${String(Math.floor(seconds / 60)).padStart(2, "0")}:${String(seconds % 60).padStart(2, "0")}`;
    button.classList.toggle("paused", Boolean(pausedAt));
    button.setAttribute(
      "aria-label",
      pausedAt ? "Resume presenter timer" : "Pause presenter timer",
    );
  }
}
function toast(message: string) {
  const el = document.querySelector<HTMLElement>("#toast")!;
  el.textContent = message;
  el.classList.add("visible");
  setTimeout(() => el.classList.remove("visible"), 3500);
}

function syncRoute() {
  if (printMode) return;
  const nextIndex = readSceneIndex();
  if (index === nextIndex) {
    if (!staticMode && location.hash !== `#${index}`)
      history.replaceState(
        { presentation: topic.historyId, index },
        "",
        `#${index}`,
      );
    return;
  }
  index = nextIndex;
  step = startingStep(index);
  render();
}
window.addEventListener("hashchange", syncRoute);
window.addEventListener("popstate", syncRoute);
window.addEventListener("pagehide", () => {
  stopAnimation();
  if (timerInterval) clearInterval(timerInterval);
  timerInterval = undefined;
});
window.addEventListener("pageshow", () => {
  if (!staticMode && timerInterval === undefined)
    timerInterval = setInterval(updateTimer, 1000);
  scheduleAnimation();
});
document.addEventListener("visibilitychange", scheduleAnimation);
reducedMotion.addEventListener("change", () => {
  if (printMode) return;
  step = startingStep(index);
  render();
});
window.addEventListener("resize", resize);
mount();
