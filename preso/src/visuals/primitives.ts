import type { VisualOptions } from "../types";

// Original SVG primitives, reused from our original presentation engine.
export const C = {
  ink: "#111820",
  muted: "#677586",
  line: "#C9D3DE",
  blue: "#0B64DD",
  blueLight: "#EAF3FF",
  teal: "#02BCB7",
  tealLight: "#E3FAF6",
  pink: "#F04E98",
  pinkLight: "#FDEBF4",
  gray: "#F4F7FA",
  amber: "#B0740B",
};
export const esc = (s: string) =>
  s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
export const txt = (
  x: number,
  y: number,
  value: string,
  size = 14,
  color = C.ink,
  cls = "",
  anchor = "start",
) =>
  `<text x="${x}" y="${y}" font-size="${size}" fill="${color}" text-anchor="${anchor}" class="${cls}">${esc(value)}</text>`;
export const mono = (
  x: number,
  y: number,
  value: string,
  size = 12,
  color = C.muted,
  anchor = "start",
) => txt(x, y, value, size, color, "v-mono", anchor);
export const rect = (
  x: number,
  y: number,
  w: number,
  h: number,
  fill = "white",
  stroke = C.line,
  r = 8,
  cls = "",
) =>
  `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${r}" fill="${fill}" stroke="${stroke}" class="${cls}"/>`;
export const line = (
  x1: number,
  y1: number,
  x2: number,
  y2: number,
  color = C.line,
  width = 1.4,
  cls = "",
) =>
  `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${color}" stroke-width="${width}" class="${cls}"/>`;
export const path = (
  d: string,
  stroke = C.line,
  width = 1.4,
  fill = "none",
  cls = "",
) =>
  `<path d="${d}" fill="${fill}" stroke="${stroke}" stroke-width="${width}" stroke-linecap="round" stroke-linejoin="round" class="${cls}"/>`;
export const circle = (
  x: number,
  y: number,
  r: number,
  fill = "white",
  stroke = C.line,
  cls = "",
) =>
  `<circle cx="${x}" cy="${y}" r="${r}" fill="${fill}" stroke="${stroke}" class="${cls}"/>`;
export const group = (body: string, delay = 0, cls = "") =>
  `<g class="reveal ${cls}" style="--delay:${delay}ms">${body}</g>`;
export const pill = (
  x: number,
  y: number,
  label: string,
  color = C.blue,
  fill = C.blueLight,
  width?: number,
) => {
  const w = width || label.length * 7.1 + 24;
  return (
    rect(x, y, w, 24, fill, "none", 12) + mono(x + 12, y + 16, label, 11, color)
  );
};
export const arrow = (
  x1: number,
  y1: number,
  x2: number,
  y2: number,
  color = C.blue,
  cls = "",
) => {
  const a = Math.atan2(y2 - y1, x2 - x1);
  const b = 7;
  return (
    line(x1, y1, x2, y2, color, 1.6, cls) +
    `<path d="M${x2 - b * Math.cos(a - 0.45)},${y2 - b * Math.sin(a - 0.45)} L${x2},${y2} L${x2 - b * Math.cos(a + 0.45)},${y2 - b * Math.sin(a + 0.45)}" fill="none" stroke="${color}" stroke-width="1.6" stroke-linecap="round"/>`
  );
};
export const dotLine = (
  x1: number,
  y1: number,
  x2: number,
  y2: number,
  color = C.line,
) =>
  `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${color}" stroke-width="1.4" stroke-dasharray="3 5"/>`;

export type IconKind =
  | "search"
  | "database"
  | "shield"
  | "host"
  | "user"
  | "cloud"
  | "link"
  | "spark"
  | "check"
  | "workflow"
  | "clock"
  | "document"
  | "layers"
  | "lock"
  | "network"
  | "terminal";
export function icon(
  kind: IconKind,
  x: number,
  y: number,
  color = C.blue,
  scale = 1,
): string {
  const ds: Record<IconKind, string> = {
    search: "M17 17L23 23 M19 11A8 8 0 1 1 3 11A8 8 0 1 1 19 11",
    database:
      "M3 5C3 0 23 0 23 5C23 10 3 10 3 5Z M3 5V20C3 25 23 25 23 20V5 M3 12C3 17 23 17 23 12",
    shield:
      "M13 2L23 6V13C23 19 18 24 13 26C8 24 3 19 3 13V6Z M8 13L12 17L19 10",
    host: "M3 3H24V18H3Z M8 24H20 M14 18V24",
    user: "M19 7A6 6 0 1 1 7 7A6 6 0 1 1 19 7 M3 25V21C3 12 23 12 23 21V25",
    cloud: "M6 22C-1 22-1 11 6 11C6 0 23 0 23 11C31 11 31 22 23 22Z",
    link: "M11 17L17 11 M9 19L6 22C1 27-4 20 1 16L8 9C11 6 15 7 16 10 M17 7L20 4C25-1 31 6 26 10L19 17C16 20 12 19 11 16",
    spark: "M13 1L16 10L25 13L16 16L13 25L10 16L1 13L10 10Z",
    check: "M4 14L10 20L23 6",
    workflow:
      "M2 2H10V10H2Z M18 18H26V26H18Z M2 18H10V26H2Z M6 10V18 M10 6H22V18",
    clock: "M25 13A12 12 0 1 1 1 13A12 12 0 1 1 25 13 M13 5V13L19 17",
    document: "M4 1H17L24 8V26H4Z M17 1V8H24 M9 13H19 M9 18H19 M9 23H16",
    layers: "M1 8L13 1L25 8L13 15Z M1 14L13 21L25 14 M1 20L13 27L25 20",
    lock: "M6 12V8C6-1 22-1 22 8V12 M3 12H25V27H3Z M14 17V22",
    network:
      "M10 1H18V9H10Z M1 19H9V27H1Z M19 19H27V27H19Z M14 9V14 M5 19V14H23V19",
    terminal: "M1 2H27V26H1Z M6 9L11 14L6 19 M14 19H22",
  };
  return `<g transform="translate(${x} ${y}) scale(${scale})" fill="none" stroke="${color}" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="${ds[kind]}"/></g>`;
}
export const node = (
  x: number,
  y: number,
  kind: IconKind,
  label: string,
  sub = "",
  color = C.blue,
  w = 150,
  h = 74,
) =>
  rect(x, y, w, h, "white", C.line, 9) +
  icon(kind, x + 14, y + 15, color, 0.85) +
  txt(x + 48, y + 32, label, 14, C.ink, "v-bold") +
  (sub ? mono(x + 48, y + 52, sub, 10.5) : "");
export const number = (x: number, y: number, n: string, color = C.blue) =>
  circle(x, y, 15, "white", color) + mono(x, y + 4, n, 11, color, "middle");

// A 2:1 isometric slab/cube, with a consistent upper-left light source.
export function slab(
  x: number,
  y: number,
  w: number,
  d: number,
  h: number,
  color = C.blue,
  label = "",
): string {
  const a = w / 2;
  const b = d / 2;
  return `<g class="v-iso"><polygon points="${x},${y} ${x + a},${y + a / 2} ${x + a - b},${y + (a + b) / 2} ${x - b},${y + b / 2}" fill="${color === C.blue ? "#F2F7FE" : color === C.teal ? "#ECFBF8" : "#FFF4F9"}" stroke="${C.ink}" stroke-width="1.05"/><polygon points="${x - b},${y + b / 2} ${x + a - b},${y + (a + b) / 2} ${x + a - b},${y + (a + b) / 2 + h} ${x - b},${y + b / 2 + h}" fill="${color}" stroke="${C.ink}" stroke-width="1.05" opacity=".88"/><polygon points="${x + a},${y + a / 2} ${x + a - b},${y + (a + b) / 2} ${x + a - b},${y + (a + b) / 2 + h} ${x + a},${y + a / 2 + h}" fill="${color}" stroke="${C.ink}" stroke-width="1.05" opacity=".58"/>${label ? txt(x + (a - b) / 2, y + (a + b) / 4 + 5, label, 14, C.ink, "v-bold", "middle") : ""}</g>`;
}
export function cube(
  x: number,
  y: number,
  size: number,
  color = C.blue,
  glyph?: IconKind,
): string {
  return (
    slab(x, y, size, size, size * 0.48, color) +
    (glyph ? icon(glyph, x - 11, y + size * 0.22 - 8, C.ink, 0.78) : "")
  );
}
export const rail = (
  items: { label: string; time: string; color?: string }[],
  y = 174,
  x = 55,
  gap = 151,
) =>
  line(x, y, x + (items.length - 1) * gap, y, C.line, 2) +
  items
    .map((v, i) =>
      group(
        circle(x + i * gap, y, 7, v.color || C.blue, "white") +
          mono(x + i * gap, y - 24, v.time, 11, C.muted, "middle") +
          txt(x + i * gap, y + 30, v.label, 13, C.ink, "", "middle"),
        i * 100,
      ),
    )
    .join("");
export const panelHeader = (
  x: number,
  y: number,
  w: number,
  title: string,
  tag = "",
) =>
  rect(x, y, w, 34, C.gray, C.line, 8) +
  rect(x, y + 22, w, 12, C.gray, "none", 0) +
  txt(x + 14, y + 22, title, 12, C.ink, "v-bold") +
  (tag ? mono(x + w - 14, y + 22, tag, 10, C.muted, "end") : "");
export const row = (
  x: number,
  y: number,
  w: number,
  key: string,
  value: string,
  color = C.ink,
) =>
  mono(x, y, key, 11) +
  txt(x + 126, y, value, 12, color) +
  line(x, y + 12, x + w, y + 12, "#E6ECF2", 1);
export const caption = (x: number, y: number, s: string, color = C.muted) =>
  mono(x, y, s, 11, color);

// Moving evidence follows an explicit path; static/reduced-motion exports retain its route.
export function flow(
  d: string,
  color = C.blue,
  seconds = 4,
  delay = 0,
): string {
  return (
    path(d, color, 1.4, "none", "v-flow") +
    `<g class="motion-particles"><circle r="3.5" fill="${color}"><animateMotion path="${d}" dur="${seconds}s" begin="-${delay}s" repeatCount="indefinite"/></circle><circle r="2" fill="${color}"><animateMotion path="${d}" dur="${seconds}s" begin="-${delay + seconds / 2}s" repeatCount="indefinite"/></circle></g>`
  );
}
export function phase(options: VisualOptions, count: number): number {
  return options.settled ? count - 1 : Math.min(options.step, count - 1);
}
export function title(
  x: number,
  y: number,
  value: string,
  color = C.ink,
): string {
  return txt(x, y, value, 17, color, "v-bold");
}
