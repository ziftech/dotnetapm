import type { Scene, VisualOptions } from "./types";
import {
  C,
  arrow,
  circle,
  esc,
  group,
  mono,
  node,
  path,
  pill,
  rect,
  txt,
} from "./visuals/primitives";

type Render = (o: VisualOptions) => string;

const card = (
  x: number,
  y: number,
  w: number,
  h: number,
  title: string,
  sub: string,
  fill = "white",
  accent = C.blue,
) =>
  rect(x, y, w, h, fill, C.line, 10) +
  `<rect x="${x}" y="${y}" width="6" height="${h}" rx="3" fill="${accent}"/>` +
  txt(x + 20, y + 28, title, 15, C.ink, "v-bold") +
  mono(x + 20, y + 50, sub, 11);

const visuals: Record<string, Render> = {
  hero: ({ step }) =>
    group(pill(40, 28, "CONTOSO · .NET FRAMEWORK", C.blue, C.blueLight, 230), 0) +
    group(
      txt(40, 110, "Host agent", 30, C.ink, "v-bold") +
        txt(40, 155, "+ build-time aspects", 30, C.blue, "v-bold"),
      60,
    ) +
    (step >= 1
      ? group(mono(40, 210, "Named business spans · C# and VB · no per-method APM code", 14), 140)
      : "") +
    (step >= 2
      ? group(
          card(40, 260, 200, 90, "A · Agent", "HTTP · SQL · map", C.blueLight, C.blue) +
            card(260, 260, 200, 90, "B · Aspects", "DLL weave", C.tealLight, C.teal) +
            card(480, 260, 200, 90, "C · Optional", "Labels", C.pinkLight, C.pink),
          220,
        )
      : ""),

  layers: ({ step }) => {
    const rows = [
      { title: "A · Host agent", detail: "Profiler or EDOT on the IIS pool", c: C.blue },
      { title: "B · Business DLL aspects", detail: "Assembly Trace filter · *Service methods", c: C.teal },
      { title: "C · Optional values", detail: "SetLabel at a few choke points", c: C.pink },
    ];
    return rows
      .map((r, i) =>
        step >= i
          ? group(
              rect(60, 40 + i * 110, 600, 90, "white", C.line, 12) +
                circle(105, 85 + i * 110, 20, r.c, "none") +
                txt(99, 92 + i * 110, String.fromCharCode(65 + i), 16, "white", "v-bold") +
                txt(145, 75 + i * 110, r.title, 18, C.ink, "v-bold") +
                mono(145, 100 + i * 110, r.detail, 13),
              i * 100,
            )
          : "",
      )
      .join("");
  },

  agent: ({ step }) =>
    group(
      node(50, 50, "host", "IIS host", "Profiler or EDOT", C.blue, 220) +
        arrow(280, 85, 360, 85) +
        node(370, 50, "cloud", "Elastic", "APM / OTLP", C.teal, 220),
      0,
    ) +
    (step >= 1
      ? group(
          pill(50, 180, "HTTP", C.blue, C.blueLight) +
            pill(160, 180, "SQL", C.blue, C.blueLight) +
            pill(270, 180, "Outbound", C.blue, C.blueLight) +
            pill(420, 180, "Errors", C.pink, C.pinkLight),
          120,
        )
      : "") +
    (step >= 2
      ? group(
          rect(50, 250, 620, 80, C.gray, "none", 10) +
            mono(70, 295, "Still missing: named business methods → Layer B", 14, C.muted),
          220,
        )
      : ""),

  aspects: ({ step }) =>
    group(
      card(40, 40, 180, 90, "Source DLL", "clean method bodies", C.gray, C.muted) +
        arrow(230, 85, 290, 85) +
        card(300, 40, 180, 90, "Fody weave", "assembly Trace", C.blueLight, C.blue) +
        arrow(490, 85, 550, 85) +
        card(560, 40, 120, 90, "IL", "OnEntry", C.tealLight, C.teal),
      0,
    ) +
    (step >= 1
      ? group(
          card(40, 180, 300, 120, "C# business DLL", "ShipmentService.*", C.blueLight, C.blue) +
            card(380, 180, 300, 120, "VB business DLL", "LegacyShipmentService.*", C.pinkLight, C.pink),
          140,
        )
      : "") +
    (step >= 2
      ? group(mono(40, 340, "Not wrappers · not inheritance · call sites unchanged", 13, C.muted), 240)
      : ""),

  backends: ({ step }) =>
    group(card(260, 30, 200, 70, "TraceAttribute", "shared aspect", C.gray, C.ink), 0) +
    (step >= 1
      ? group(
          path("M360 100 L360 140 L160 140 L160 170", C.line, 1.6) +
            path("M360 100 L360 140 L560 140 L560 170", C.line, 1.6) +
            card(40, 170, 240, 120, "Elastic APM", "Profiler / Agent API", C.blueLight, C.blue) +
            card(440, 170, 240, 120, "EDOT", "ActivitySource / OTLP", C.tealLight, C.teal),
          100,
        )
      : "") +
    (step >= 2
      ? group(mono(40, 330, "Same weave · host chooses the exporter", 13, C.muted), 220)
      : ""),

  proof: ({ step }) => {
    const rows = [
      { label: "POST Checkout/Index", w: 620, c: C.blue },
      { label: "LegacyShipmentService.EnrichQuoteNote  (VB)", w: 520, c: C.pink },
      { label: "ShipmentService.CreateQuoteAsync  (C#)", w: 500, c: C.teal },
      { label: "mssql · outbound HTTP", w: 360, c: C.amber },
    ];
    return (
      group(mono(40, 28, "ShipmentsWeb · illustrative waterfall", 12, C.muted), 0) +
      rows
        .map((r, i) =>
          step >= Math.min(i, 2)
            ? group(
                rect(40, 55 + i * 70, r.w, 50, "white", C.line, 8) +
                  `<rect x="40" y="${55 + i * 70}" width="8" height="50" fill="${r.c}"/>` +
                  mono(60, 85 + i * 70, r.label, 13, C.ink),
                i * 70,
              )
            : "",
        )
        .join("")
    );
  },

  closing: ({ step }) =>
    group(
      txt(40, 100, "Install the agent on the host.", 26, C.ink, "v-bold") +
        txt(40, 150, "Weave the business DLLs once.", 26, C.blue, "v-bold") +
        txt(40, 200, "Keep method bodies clean.", 26, C.teal, "v-bold"),
      0,
    ) +
    (step >= 1
      ? group(
          pill(40, 260, "C# + VB", C.blue, C.blueLight) +
            pill(160, 260, "Profiler today", C.teal, C.tealLight) +
            pill(340, 260, "EDOT optional", C.pink, C.pinkLight),
          140,
        )
      : "") +
    (step >= 2
      ? group(mono(40, 330, "github.com/ziftech/dotnetapm", 14, C.muted), 240)
      : ""),
};

export function renderVisual(scene: Scene, options: VisualOptions): string {
  const render = visuals[scene.visual];
  if (!render) throw new Error(`Missing diagram: ${scene.visual}`);
  let body = render(options);
  if (options.settled) {
    body = body
      .replace(/<g class="motion-particles">[\s\S]*?<\/g>/g, "")
      .replace(/<animateMotion[^>]*\/>/g, "");
  }
  return `<div class="presentation-visual${options.settled ? " settled" : ""}" data-visual="${scene.visual}" data-step="${options.step}"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 720 390" role="img" aria-label="${esc(scene.headline + " " + scene.emphasis)}"><title>${esc(scene.headline + " " + scene.emphasis)}</title>${body}</svg></div>`;
}
