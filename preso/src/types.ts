export type VisualKind =
  | "hero"
  | "objection"
  | "layers"
  | "lab-map"
  | "profiler"
  | "edot"
  | "weave"
  | "csharp"
  | "vb"
  | "backends"
  | "waterfall"
  | "labels"
  | "logs"
  | "demo"
  | "closing";

export interface Source {
  label: string;
  url: string;
}
export interface Takeaway {
  label: string;
  value: string;
  detail: string;
}
export interface Step {
  label: string;
  detail: string;
}
export interface Notes {
  opening: string;
  body: string;
  transition: string;
  seconds: number;
  prompt?: string;
}
export interface Scene {
  id: string;
  chapter: string;
  eyebrow: string;
  headline: string;
  emphasis: string;
  lead: string;
  visual: VisualKind;
  layout: "split" | "wide" | "hero";
  takeaways: [Takeaway, Takeaway, Takeaway];
  densityExtra: string;
  qualification: string;
  sources: Source[];
  notes: Notes;
  steps?: Step[];
  illustrative?: boolean;
}

export interface VisualOptions {
  step: number;
  settled: boolean;
  density: number;
}
