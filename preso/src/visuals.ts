import type { Scene, VisualOptions } from "./types";
import {
  C,
  arrow,
  circle,
  esc,
  group,
  line,
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
    group(pill(40, 28, "CONTOSO · .NET FRAMEWORK 4.8", C.blue, C.blueLight, 250), 0) +
    group(
      txt(40, 100, "Host agent", 28, C.ink, "v-bold") +
        txt(40, 140, "+ build-time aspects", 28, C.blue, "v-bold") +
        mono(40, 175, "No CaptureTransaction on every method", 14),
      80,
    ) +
    (step >= 1
      ? group(
          card(40, 220, 200, 110, "A · Agent", "HTTP · SQL · map", C.blueLight, C.blue) +
            card(260, 220, 200, 110, "B · Aspects", "C# + VB weave", C.tealLight, C.teal) +
            card(480, 220, 200, 110, "C · Values", "labels optional", C.pinkLight, C.pink),
          160,
        )
      : "") +
    (step >= 2
      ? group(mono(40, 360, "Same Contoso.Observability library → APM or EDOT", 12, C.muted), 280)
      : ""),

  objection: ({ step }) =>
    group(node(40, 40, "layers", "15 class libraries", "VB + C# · Framework 4.8", C.pink, 220), 0) +
    group(node(300, 40, "document", "Web.config only", "Often no Global.asax", C.amber, 200), 80) +
    group(node(540, 40, "clock", "500–1000 methods", "Manual wraps fail", C.pink, 150, 74), 160) +
    (step >= 1
      ? group(
          rect(40, 160, 640, 160, C.gray, "none", 12) +
            txt(60, 200, "What they reject", 16, C.ink, "v-bold") +
            mono(60, 230, "× CaptureTransaction in every function", 13, C.pink) +
            mono(60, 255, "× Wrapper / proxy that changes call sites", 13, C.pink) +
            mono(60, 280, "× Re-implementing via inheritance", 13, C.pink) +
            (step >= 2
              ? mono(60, 305, "✓ Assembly-level Trace weave on business DLLs", 13, C.teal)
              : ""),
          200,
        )
      : ""),

  layers: ({ step }) => {
    const rows = [
      { y: 40, title: "A · Host agent", detail: "Profiler COR_* or EDOT OTEL_* on IIS pool", c: C.blue },
      { y: 140, title: "B · Business DLL aspects", detail: "Fody TraceAttribute · *Service filters", c: C.teal },
      { y: 240, title: "C · Optional values", detail: "SetLabel / Activity tags at choke points", c: C.pink },
    ];
    return rows
      .map((r, i) =>
        step >= i
          ? group(
              rect(60, r.y, 600, 80, "white", C.line, 12) +
                circle(100, r.y + 40, 18, r.c, "none") +
                txt(94, r.y + 46, String.fromCharCode(65 + i), 16, "white", "v-bold") +
                txt(140, r.y + 36, r.title, 18, C.ink, "v-bold") +
                mono(140, r.y + 58, r.detail, 12),
              i * 120,
            )
          : "",
      )
      .join("");
  },

  "lab-map": ({ step }) =>
    group(
      card(40, 50, 280, 120, "ShipmentsWeb", "SharedPool · profiler", C.blueLight, C.blue) +
        card(400, 50, 280, 120, "TrackingApi-EDOT", "TrackingEdotPool · OTLP", C.tealLight, C.teal),
      0,
    ) +
    (step >= 1
      ? group(
          arrow(320, 110, 400, 110, C.ink) +
            mono(300, 95, "HTTP", 11, C.muted) +
            card(180, 220, 360, 100, "Contoso.Observability", "TraceAttribute · TraceBackends", "white", C.pink),
          120,
        )
      : "") +
    (step >= 2
      ? group(
          mono(40, 350, "C# Contoso.Shipments.Business", 11, C.blue) +
            mono(400, 350, "VB Contoso.Shipments.LegacyVb", 11, C.teal),
          240,
        )
      : ""),

  profiler: ({ step }) =>
    group(
      node(60, 40, "host", "IIS SharedPool", "COR_ENABLE_PROFILING=1", C.blue, 240) +
        arrow(310, 75, 390, 75) +
        node(400, 40, "network", "APM Server", "traces-apm*", C.teal, 220),
      0,
    ) +
    (step >= 1
      ? group(
          pill(60, 160, "ASP.NET MVC", C.blue, C.blueLight) +
            pill(220, 160, "SqlClient", C.blue, C.blueLight) +
            pill(360, 160, "HttpClient", C.blue, C.blueLight) +
            pill(520, 160, "Errors", C.pink, C.pinkLight),
          120,
        )
      : "") +
    (step >= 2
      ? group(
          rect(60, 220, 600, 100, C.gray, "none", 10) +
            txt(80, 260, "Still missing", 15, C.ink, "v-bold") +
            mono(80, 290, "Named business methods → need Layer B aspects", 13, C.muted),
          220,
        )
      : ""),

  edot: ({ step }) =>
    group(
      node(40, 40, "host", "TrackingEdotPool", "OTEL_EXPORTER_OTLP_*", C.teal, 250) +
        arrow(300, 75, 380, 75, C.teal) +
        node(390, 40, "cloud", "OTLP ingest", "generic.otel", C.blue, 240),
      0,
    ) +
    (step >= 1
      ? group(
          card(40, 160, 300, 120, "ActivitySourceTraceBackend", "Contoso.Observability source", C.tealLight, C.teal) +
            card(380, 160, 300, 120, "WithElasticDefaults()", "AspNet + SqlClient + AddSource", C.blueLight, C.blue),
          120,
        )
      : "") +
    (step >= 2
      ? group(mono(40, 320, "Same Fody aspects — backend selected at host start", 13, C.muted), 240)
      : ""),

  weave: ({ step }) =>
    group(
      card(40, 40, 200, 90, "Source DLL", "clean method bodies", C.gray, C.muted) +
        arrow(250, 85, 310, 85) +
        card(320, 40, 200, 90, "Fody weave", "MBA 3.6.0", C.blueLight, C.blue) +
        arrow(530, 85, 590, 85) +
        card(600, 40, 100, 90, "IL", "OnEntry", C.tealLight, C.teal),
      0,
    ) +
    (step >= 1
      ? group(
          rect(40, 170, 640, 140, "white", C.line, 12) +
            mono(60, 205, "OnEntry  → TraceBackends.Current.StartSpanOrTransaction", 13, C.blue) +
            mono(60, 235, "OnExit   → complete span (sync or after Task)", 13, C.teal) +
            mono(60, 265, "OnException → CaptureException + end", 13, C.pink) +
            (step >= 2 ? mono(60, 295, "Filters: Namespace · TypeName (*Service) · Public", 12, C.muted) : ""),
          140,
        )
      : ""),

  csharp: ({ step }) =>
    group(
      rect(40, 30, 640, 150, "#0f1720", "none", 12) +
        mono(60, 60, "// Contoso.Shipments.Business / AssemblyInfo.cs", 12, "#7dd3c7") +
        mono(60, 90, '[assembly: Trace(', 13, "#e2e8f0") +
        mono(60, 115, '  TypeNameFilter = @"Service$",', 13, "#93c5fd") +
        mono(60, 140, "  AttributeTargetMemberAttributes = Public)]", 13, "#e2e8f0"),
      0,
    ) +
    (step >= 1
      ? group(
          card(40, 210, 300, 110, "ShipmentService.cs", "CreateQuoteAsync — no APM calls", C.blueLight, C.blue) +
            (step >= 2
              ? card(380, 210, 300, 110, "Waterfall", "ShipmentService.CreateQuoteAsync", C.tealLight, C.teal)
              : ""),
          140,
        )
      : ""),

  vb: ({ step }) =>
    group(
      rect(40, 30, 640, 150, "#0f1720", "none", 12) +
        mono(60, 60, "' Contoso.Shipments.LegacyVb / AssemblyInfo.vb", 12, "#7dd3c7") +
        mono(60, 90, "<Assembly: Trace(", 13, "#e2e8f0") +
        mono(60, 115, '  TypeNameFilter:="Service$",', 13, "#f9a8d4") +
        mono(60, 140, "  AttributeTargetMemberAttributes:=Public)>", 13, "#e2e8f0"),
      0,
    ) +
    (step >= 1
      ? group(
          card(40, 210, 300, 110, "LegacyShipmentService.vb", "EnrichQuoteNote — clean body", C.pinkLight, C.pink) +
            (step >= 2
              ? card(380, 210, 300, 110, "Checkout page", "VB enrich: VB:…:STANDARD:5kg", C.tealLight, C.teal)
              : ""),
          140,
        )
      : ""),

  backends: ({ step }) =>
    group(
      card(260, 30, 200, 70, "TraceAttribute", "Fody aspect", C.gray, C.ink),
      0,
    ) +
    (step >= 1
      ? group(
          path("M360 100 L360 140 L160 140 L160 170", C.line, 1.6) +
            path("M360 100 L360 140 L560 140 L560 170", C.line, 1.6) +
            card(40, 170, 240, 120, "ElasticApmTraceBackend", "Agent.Tracer spans", C.blueLight, C.blue) +
            card(440, 170, 240, 120, "ActivitySourceTraceBackend", "ActivitySource export", C.tealLight, C.teal),
          100,
        )
      : "") +
    (step >= 2
      ? group(
          mono(60, 330, "ShipmentsWeb default", 12, C.blue) +
            mono(480, 330, "TrackingApi when OTLP set", 12, C.teal),
          220,
        )
      : ""),

  waterfall: ({ step }) => {
    const rows = [
      { label: "POST Checkout/Index", w: 620, c: C.blue },
      { label: "LegacyShipmentService.EnrichQuoteNote", w: 520, c: C.pink },
      { label: "  NormalizeTrackingId / ClassifyLane", w: 420, c: C.pink },
      { label: "ShipmentService.CreateQuoteAsync", w: 500, c: C.teal },
      { label: "mssql · WAITFOR / upsert", w: 360, c: C.amber },
      { label: "GET TrackingApi", w: 300, c: C.blue },
    ];
    return (
      group(mono(40, 28, "Illustrative waterfall · Contoso lab", 11, C.muted), 0) +
      rows
        .map((r, i) =>
          step >= Math.min(i, 2)
            ? group(
                rect(40, 50 + i * 48, r.w, 36, r.c === C.amber ? "#FFF7E8" : "white", C.line, 8) +
                  `<rect x="40" y="${50 + i * 48}" width="8" height="36" fill="${r.c}"/>` +
                  mono(60, 73 + i * 48, r.label, 12, C.ink),
                i * 60,
              )
            : "",
        )
        .join("")
    );
  },

  labels: ({ step }) =>
    group(
      card(40, 40, 280, 100, "Checkout choke point", "ApmBusiness.SetCheckoutLabels", C.blueLight, C.blue),
      0,
    ) +
    (step >= 1
      ? group(
          ["tracking_id", "lane", "weight_kg", "quote_price"]
            .map((f, i) => pill(360, 40 + i * 40, f, C.teal, C.tealLight, 200))
            .join(""),
          100,
        )
      : "") +
    (step >= 2
      ? group(mono(40, 200, "Aspects ≠ labels. Spans are free with weave; values stay optional.", 13, C.muted), 220)
      : ""),

  logs: ({ step }) =>
    group(
      rect(40, 40, 640, 90, "#0f1720", "none", 10) +
        mono(60, 75, "Checkout done … trace.id=a1b2… transaction.id=c3d4…", 13, "#7dd3c7") +
        mono(60, 105, "service.name=ShipmentsWeb  (Fleet processor)", 12, "#93c5fd"),
      0,
    ) +
    (step >= 1
      ? group(
          card(40, 170, 300, 120, "Emit", "log4net / NLog layouts", C.blueLight, C.blue) +
            card(380, 170, 300, 120, "Correlate", "APM Logs · Discover", C.tealLight, C.teal),
          120,
        )
      : "") +
    (step >= 2
      ? group(mono(40, 330, "Works for profiler Agent.Tracer and EDOT Activity.Current", 12, C.muted), 240)
      : ""),

  demo: ({ step }) => {
    const items = [
      "1  Objection → Layers A/B/C",
      "2  Untouched VB + C# bodies",
      "3  Assembly Trace filters",
      "4  POST /web/Checkout",
      "5  Waterfall · labels · logs",
      "6  EDOT contrast · ask for 1 DLL",
    ];
    return items
      .map((label, i) =>
        step >= Math.floor(i / 2)
          ? group(
              rect(40, 30 + i * 52, 640, 42, i % 2 ? C.gray : "white", C.line, 8) +
                mono(60, 57 + i * 52, label, 14, C.ink),
              i * 50,
            )
          : "",
      )
      .join("");
  },

  closing: ({ step }) =>
    group(
      txt(40, 90, "Install the agent on the host.", 24, C.ink, "v-bold") +
        txt(40, 130, "Weave business DLLs once.", 24, C.blue, "v-bold") +
        txt(40, 170, "Keep method bodies clean.", 24, C.teal, "v-bold"),
      0,
    ) +
    (step >= 1
      ? group(
          pill(40, 220, "C# + VB", C.blue, C.blueLight) +
            pill(160, 220, "Profiler today", C.teal, C.tealLight) +
            pill(340, 220, "EDOT next", C.pink, C.pinkLight),
          140,
        )
      : "") +
    (step >= 2
      ? group(mono(40, 300, "Ask: one real class library to tailor filters together.", 14, C.muted), 260)
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
