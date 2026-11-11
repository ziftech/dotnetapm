import type { Notes, Scene, Source, Step, Takeaway } from "./types";
import { lab } from "./scenario";

const t = (label: string, value: string, detail: string): Takeaway => ({
  label,
  value,
  detail,
});
const n = (
  opening: string,
  body: string,
  transition: string,
  seconds: number,
  prompt?: string,
): Notes => ({
  opening,
  body,
  transition,
  seconds,
  ...(prompt ? { prompt } : {}),
});
const phases = (...items: [string, string][]): Step[] =>
  items.map(([label, detail]) => ({ label, detail }));
const source = (label: string, url: string): Source => ({ label, url });

const S = {
  profiler: source(
    "Profiler zero-code",
    "https://www.elastic.co/docs/reference/apm/agents/dotnet/setup-auto-instrumentation",
  ),
  edot: source(
    "EDOT .NET",
    "https://www.elastic.co/docs/reference/opentelemetry/edot-sdks/dotnet",
  ),
  mba: source(
    "MethodBoundaryAspect.Fody",
    "https://github.com/vescon/MethodBoundaryAspect.Fody",
  ),
};

const qual =
  "Illustrative Contoso .NET Framework lab. Availability depends on Elastic deployment and agent/EDOT version.";

export const scenes: Scene[] = [
  {
    id: "hero",
    chapter: "Open",
    eyebrow: "Contoso .NET Framework",
    headline: "Business visibility.",
    emphasis: "Without editing every method.",
    lead: "Legacy IIS estates need named business methods in the waterfall. Wrapping hundreds of functions does not scale. Elastic uses a host agent plus build-time aspects.",
    visual: "hero",
    layout: "hero",
    takeaways: [
      t("Problem", "Per-method APM", "Does not scale across DLLs"),
      t("Answer", "Agent + aspects", "Host install · DLL weave"),
      t("Result", "Named spans", "C# and VB class libraries"),
    ],
    densityExtra: "Same pattern for traditional APM profiler and EDOT.",
    qualification: qual,
    sources: [S.profiler, S.mba],
    notes: n(
      "Start with the scaling problem.",
      "Teams reject CaptureTransaction on every method. Contoso shows the alternative: agent on the host, aspects on business DLLs.",
      "Show the three layers.",
      30,
    ),
    steps: phases(
      ["Problem", "Too many methods to touch"],
      ["Approach", "Agent + aspects"],
      ["Outcome", "Business spans in APM"],
    ),
  },
  {
    id: "layers",
    chapter: "Approach",
    eyebrow: "Three layers",
    headline: "A · B · C",
    emphasis: "Minimum change first.",
    lead: "Separate host onboarding, business weave, and optional business values. Most teams stop after A + B.",
    visual: "layers",
    layout: "wide",
    takeaways: [
      t("A", "Host agent", "HTTP · SQL · map · errors"),
      t("B", "DLL aspects", "Named *Service methods"),
      t("C", "Optional", "Labels / tags at choke points"),
    ],
    densityExtra: "Web.config / IIS for A. Build pipeline for B. A few lines for C.",
    qualification: qual,
    sources: [S.profiler, S.mba],
    notes: n(
      "This is the whole story on one slide.",
      "A needs no business-method edits. B is one assembly attribute per DLL. C is optional.",
      "Detail the agent layer.",
      35,
    ),
    steps: phases(
      ["A", "Install on host"],
      ["B", "Weave business DLLs"],
      ["C", "Add labels if needed"],
    ),
  },
  {
    id: "agent",
    chapter: "Layer A",
    eyebrow: "Host agent",
    headline: "Zero code",
    emphasis: "for HTTP and SQL.",
    lead: "Elastic .NET profiler on the IIS pool (or EDOT/OTLP) gives transactions, dependencies, and errors. Business method names still need Layer B.",
    visual: "agent",
    layout: "split",
    takeaways: [
      t("Traditional", "Profiler", `${lab.web} on IIS`),
      t("Direction", "EDOT", `${lab.tracking} via OTLP`),
      t("Config", "Pool / Web.config", "No per-method edits"),
    ],
    densityExtra: "Global.asax is not required for agent spans.",
    qualification: qual,
    sources: [S.profiler, S.edot],
    notes: n(
      "Answer Web.config-only hosts here.",
      "Agent covers the map. Named business methods come next.",
      "Explain aspects.",
      30,
    ),
    steps: phases(
      ["Install", "IIS pool or EDOT env"],
      ["Auto", "HTTP + SQL appear"],
      ["Gap", "Need business names"],
    ),
  },
  {
    id: "aspects",
    chapter: "Layer B",
    eyebrow: "Build-time weave",
    headline: "One attribute.",
    emphasis: "Many methods.",
    lead: "Fody MethodBoundaryAspect weaves entry/exit into matching methods. C# and VB class libraries keep clean bodies — only an assembly-level Trace filter.",
    visual: "aspects",
    layout: "wide",
    takeaways: [
      t("How", "IL weave", "OnEntry / OnExit / OnException"),
      t("Where", "Business DLLs", "C# and VB · *Service filters"),
      t("Not", "Wrappers", "Call sites and bodies unchanged"),
    ],
    densityExtra: `${lab.csSpan} and ${lab.vbSpan} appear under ${lab.checkout}.`,
    qualification: qual,
    sources: [S.mba],
    notes: n(
      "This replaces per-method CaptureTransaction.",
      "Show Contoso.Shipments.Business and Contoso.Shipments.LegacyVb as the same pattern.",
      "Show dual backends.",
      40,
    ),
    steps: phases(
      ["Filter", "Namespace / *Service / public"],
      ["Build", "Fody rewrites IL"],
      ["Runtime", "Spans under the HTTP transaction"],
    ),
  },
  {
    id: "backends",
    chapter: "Shared",
    eyebrow: "One weave",
    headline: "Two exporters.",
    emphasis: "Profiler or EDOT.",
    lead: "The aspect calls TraceBackends.Current. The host chooses Elastic APM Agent API or ActivitySource/OTLP. The business DLL investment stays.",
    visual: "backends",
    layout: "split",
    takeaways: [
      t("Today", "Elastic APM", "Profiler path"),
      t("Next", "EDOT", "OpenTelemetry path"),
      t("Stable", "Aspect library", "No re-weave to migrate"),
    ],
    densityExtra: "Contoso runs both side by side in the lab.",
    qualification: qual,
    sources: [S.profiler, S.edot],
    notes: n(
      "Reassure that OTel is optional, not a rewrite.",
      "Aspects survive the migration.",
      "Show what appears in APM.",
      30,
    ),
    steps: phases(
      ["Aspect", "Same TraceAttribute"],
      ["Host", "Selects backend"],
      ["Export", "APM or OTLP"],
    ),
  },
  {
    id: "proof",
    chapter: "Proof",
    eyebrow: "In Elastic APM",
    headline: "Checkout waterfall.",
    emphasis: "C# + VB spans.",
    lead: `Open service ${lab.web} → ${lab.checkout}. Business spans from woven DLLs sit under the HTTP transaction with SQL and outbound calls.`,
    visual: "proof",
    layout: "wide",
    takeaways: [
      t("Service", lab.web, "Not a separate VB service"),
      t("Spans", "LegacyShipmentService", "VB class library"),
      t("Spans", "ShipmentService", "C# class library"),
    ],
    densityExtra: "Optional Layer C: labels like tracking_id / lane on the same transaction.",
    qualification: qual,
    sources: [S.profiler],
    notes: n(
      "Money slide — leave it up.",
      "VB is not its own service name. It is spans inside ShipmentsWeb.",
      "Close.",
      40,
    ),
    steps: phases(
      ["Open", lab.web],
      ["Transaction", lab.checkout],
      ["Waterfall", "VB + C# business spans"],
    ),
    illustrative: true,
  },
  {
    id: "closing",
    chapter: "Close",
    eyebrow: "Takeaway",
    headline: "Agent on the host.",
    emphasis: "Aspects on the DLLs.",
    lead: "Install once on IIS. Add one shared aspect package to each business library build. Method bodies stay clean — C# and VB. Labels and OpenTelemetry are optional next steps.",
    visual: "closing",
    layout: "hero",
    takeaways: [
      t("A", "Host agent", "Web.config / IIS pool"),
      t("B", "DLL weave", "Assembly Trace filter"),
      t("Next", "Optional", "Labels · EDOT"),
    ],
    densityExtra: `Source: ${lab.repo}`,
    qualification: qual,
    sources: [S.profiler, S.edot, S.mba],
    notes: n(
      "Leave the one-liner on screen.",
      "Offer the repo and a sample class library to tailor filters.",
      "Stop.",
      20,
    ),
    steps: phases(
      ["Install", "Agent"],
      ["Weave", "Business DLLs"],
      ["Optional", "Labels / EDOT"],
    ),
  },
];
