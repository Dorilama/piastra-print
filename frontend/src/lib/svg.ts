// SVG grid generator. The drawing seam: the UI edits the params, the preview
// renders the output live, and the download writes it. Ported from the original
// node script, now with per-group stroke thickness + color, circle color
// alternation, and ruler left/right two-color support.

export interface StrokeStyle {
  /** Stroke width, in mm. */
  thickness: number;
  /** Stroke color, hex (#rrggbb). */
  color: string;
}

export interface CirclesStyle extends StrokeStyle {
  /** Alternate between two colors in a checkerboard pattern. */
  alternate: boolean;
  /** Second color when alternating. */
  colorAlt: string;
}

export interface RulerStyle extends StrokeStyle {
  /** Use a different color for left vs right ticks. */
  twoColor: boolean;
  /** Right-side tick color when twoColor is on (left uses `color`). */
  colorRight: string;
}

export interface Params {
  // Geometry / layout
  row: number;
  column: number;
  diameter: number;
  distance: number;
  /** Ruler tick step, in mm. */
  rulerStep: number;
  width: number;
  height: number;
  left: number;
  top: number;

  // Stroke styles, grouped
  border: StrokeStyle;
  circles: CirclesStyle;
  /** Crosshair lines through each circle center. */
  center: StrokeStyle;
  ruler: RulerStyle;
}

export const defaultParams: Params = {
  row: 4,
  column: 6,
  diameter: 16.5,
  distance: 19.3,
  rulerStep: 0.5,
  width: 127.51,
  height: 85.34,
  left: 15.49,
  top: 13.71,
  border: { thickness: 0.2, color: "#000000" },
  circles: { thickness: 0.2, color: "#000000", alternate: false, colorAlt: "#6b7280" },
  center: { thickness: 0.2, color: "#000000" },
  ruler: { thickness: 0.2, color: "#000000", twoColor: false, colorRight: "#6b7280" },
};

const round = (n: number): string => (Math.round(n * 1000) / 1000).toString();

const circle = (cx: number, cy: number, r: number): string =>
  `<circle cx="${round(cx)}" cy="${round(cy)}" r="${round(r)}"/>`;

const line = (x1: number, y1: number, x2: number, y2: number): string =>
  `<line x1="${round(x1)}" y1="${round(y1)}" x2="${round(x2)}" y2="${round(y2)}"/>`;

const rect = (x: number, y: number, w: number, h: number): string =>
  `<rect x="${round(x)}" y="${round(y)}" width="${round(w)}" height="${round(h)}"/>`;

// One <g> for a (color, thickness) pair. Empty buckets emit nothing.
function group(color: string, thickness: number, els: string[]): string {
  if (els.length === 0) return "";
  const inner = els.map((el) => "    " + el).join("\n");
  return `  <g fill="none" stroke="${color}" stroke-width="${round(thickness)}">\n${inner}\n  </g>`;
}

const num = (v: unknown, d = 0): number => {
  const n = typeof v === "number" ? v : typeof v === "string" ? Number(v) : NaN;
  return Number.isFinite(n) ? n : d;
};
const colorStr = (v: unknown, d = "#000000"): string =>
  typeof v === "string" && /^#[0-9a-fA-F]{6}$/.test(v) ? v : d;
const boolVal = (v: unknown): boolean => v === true;

// Coerce live UI values (which can be "" / NaN while typing, or partial on
// import) to a complete, valid Params. Numbers default to 0, colors to black,
// the second colors to a neutral gray, booleans to false.
function normalize(input: unknown): Params {
  const o: Record<string, unknown> =
    typeof input === "object" && input !== null ? (input as Record<string, unknown>) : {};
  const grp = (key: string): Record<string, unknown> => {
    const v = o[key];
    return typeof v === "object" && v !== null ? (v as Record<string, unknown>) : {};
  };

  // Backward-compat: the original shape used `ruler` as the numeric step.
  const step =
    o.rulerStep !== undefined ? o.rulerStep : typeof o.ruler === "number" ? o.ruler : 0.5;

  const b = grp("border");
  const c = grp("circles");
  const ce = grp("center");
  const ru = grp("ruler");

  return {
    row: num(o.row),
    column: num(o.column),
    diameter: num(o.diameter),
    distance: num(o.distance),
    rulerStep: num(step),
    width: num(o.width),
    height: num(o.height),
    left: num(o.left),
    top: num(o.top),
    border: { thickness: num(b.thickness), color: colorStr(b.color) },
    circles: {
      thickness: num(c.thickness),
      color: colorStr(c.color),
      alternate: boolVal(c.alternate),
      colorAlt: colorStr(c.colorAlt, "#6b7280"),
    },
    center: { thickness: num(ce.thickness), color: colorStr(ce.color) },
    ruler: {
      thickness: num(ru.thickness),
      color: colorStr(ru.color),
      twoColor: boolVal(ru.twoColor),
      colorRight: colorStr(ru.colorRight, "#6b7280"),
    },
  };
}

export function buildSvg(input: unknown): string {
  const p = normalize(input);
  const r = p.diameter / 2;

  const borderEls: string[] = [];
  const circlesA: string[] = [];
  const circlesB: string[] = [];
  const centerEls: string[] = [];
  const rulerLeft: string[] = [];
  const rulerRight: string[] = [];

  for (let row = 0; row < p.row; row++) {
    for (let col = 0; col < p.column; col++) {
      const cx = p.left + col * p.distance;
      const cy = p.top + row * p.distance;

      // Circle — alternate by checkerboard parity when enabled.
      const circleEl = circle(cx, cy, r);
      if (p.circles.alternate && (row + col) % 2 === 1) circlesB.push(circleEl);
      else circlesA.push(circleEl);

      // Center crosshair.
      centerEls.push(line(cx - r, cy, cx + r, cy));
      centerEls.push(line(cx, cy - r, cx, cy + r));

      // Ruler ticks, split into left/right so two-color can differ.
      const majorLen = 0.6;
      const minorLen = 0.3;
      let i = 1;
      for (let x = p.rulerStep; x <= r + 1e-9; x += p.rulerStep, i++) {
        const len = i % 2 === 0 ? majorLen : minorLen;
        rulerRight.push(line(cx + x, cy - len, cx + x, cy + len));
        rulerLeft.push(line(cx - x, cy - len, cx - x, cy + len));
      }
    }
  }

  // Border: inset by half its own thickness so the stroke stays fully inside
  // the document's geometric bounds [0,width] x [0,height].
  const bt = Math.min(p.border.thickness, p.width, p.height);
  const half = bt / 2;
  borderEls.push(rect(half, half, Math.max(0, p.width - bt), Math.max(0, p.height - bt)));

  const groups: string[] = [];
  groups.push(group(p.border.color, p.border.thickness, borderEls));
  groups.push(group(p.circles.color, p.circles.thickness, circlesA));
  if (p.circles.alternate) {
    groups.push(group(p.circles.colorAlt, p.circles.thickness, circlesB));
  }
  groups.push(group(p.center.color, p.center.thickness, centerEls));
  if (p.ruler.twoColor) {
    groups.push(group(p.ruler.color, p.ruler.thickness, rulerLeft));
    groups.push(group(p.ruler.colorRight, p.ruler.thickness, rulerRight));
  } else {
    groups.push(group(p.ruler.color, p.ruler.thickness, rulerLeft.concat(rulerRight)));
  }

  const body = groups.filter(Boolean).join("\n");
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg"
     width="${round(p.width)}mm" height="${round(p.height)}mm"
     viewBox="0 0 ${round(p.width)} ${round(p.height)}">
${body}
</svg>
`;
}
