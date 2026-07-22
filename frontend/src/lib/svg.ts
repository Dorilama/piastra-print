// SVG generator, ported from the standalone node script (tmp/sample.ts).
//
// The drawing logic below is a faithful port; only the node-only workflow
// (node:fs, writeFileSync, main) is dropped — the app writes the file via the
// native bridge instead. This module is the single drawing seam: the UI edits
// the params, the preview renders the output live, and the download writes it.

export interface Params {
  /** Number of cell rows. */
  row: number;
  /** Number of cell columns. */
  column: number;
  /** Circle diameter, in mm. */
  diameter: number;
  /** Distance between adjacent cell centers, in mm. */
  distance: number;
  /** Ruler tick step, in mm. */
  ruler: number;
  /** SVG width, in mm. */
  width: number;
  /** SVG height, in mm. */
  height: number;
  /** X of the first (top-left) cell center, in mm. */
  left: number;
  /** Y of the first (top-left) cell center, in mm. */
  top: number;
}

export const defaultParams: Params = {
  row: 4,
  column: 6,
  diameter: 16.5,
  distance: 19.3,
  ruler: 0.5,
  width: 127.51,
  height: 85.34,
  left: 15.49,
  top: 13.71,
};

const STROKE_GRID = 0.2;
const STROKE_RULER = 0.1;

const round = (n: number): string => (Math.round(n * 1000) / 1000).toString();

const circle = (cx: number, cy: number, r: number): string =>
  `<circle cx="${round(cx)}" cy="${round(cy)}" r="${round(r)}"/>`;

const line = (x1: number, y1: number, x2: number, y2: number): string =>
  `<line x1="${round(x1)}" y1="${round(y1)}" x2="${round(x2)}" y2="${round(y2)}"/>`;

const rect = (x: number, y: number, w: number, h: number): string =>
  `<rect x="${round(x)}" y="${round(y)}" width="${round(w)}" height="${round(h)}"/>`;

function buildCell(
  cx: number,
  cy: number,
  r: number,
  rulerStep: number,
): { grid: string[]; ruler: string[] } {
  const grid: string[] = [];
  const ruler: string[] = [];

  grid.push(circle(cx, cy, r));
  grid.push(line(cx - r, cy, cx + r, cy));
  grid.push(line(cx, cy - r, cx, cy + r));

  const majorLen = 0.6;
  const minorLen = 0.3;
  let i = 1;
  for (let x = rulerStep; x <= r + 1e-9; x += rulerStep, i++) {
    const len = i % 2 === 0 ? majorLen : minorLen;
    ruler.push(line(cx + x, cy - len, cx + x, cy + len));
    ruler.push(line(cx - x, cy - len, cx - x, cy + len));
  }

  return { grid, ruler };
}

// Coerce live UI values (which can be "" or NaN while a field is being typed)
// to finite numbers so the preview/download never emit NaN attributes.
function normalize(input: Params): Params {
  const out = {} as Params;
  (Object.keys(input) as (keyof Params)[]).forEach((key) => {
    const v = Number(input[key]);
    out[key] = Number.isFinite(v) ? v : 0;
  });
  return out;
}

export function buildSvg(input: Params): string {
  const p = normalize(input);
  const r = p.diameter / 2;
  const firstX = p.left;
  const firstY = p.top;

  const gridEls: string[] = [];
  const rulerEls: string[] = [];
  for (let row = 0; row < p.row; row++) {
    for (let col = 0; col < p.column; col++) {
      const cx = firstX + col * p.distance;
      const cy = firstY + row * p.distance;
      const cell = buildCell(cx, cy, r, p.ruler);
      gridEls.push(...cell.grid);
      rulerEls.push(...cell.ruler);
    }
  }

  const half = STROKE_GRID / 2;
  const border = rect(half, half, p.width - STROKE_GRID, p.height - STROKE_GRID);
  gridEls.unshift(border);

  const indent = "    ";
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg"
     width="${round(p.width)}mm" height="${round(p.height)}mm"
     viewBox="0 0 ${round(p.width)} ${round(p.height)}">
  <g fill="none" stroke="black" stroke-width="${round(STROKE_GRID)}">
${gridEls.map((el) => indent + el).join("\n")}
  </g>
  <g fill="none" stroke="black" stroke-width="${round(STROKE_RULER)}">
${rulerEls.map((el) => indent + el).join("\n")}
  </g>
</svg>
`;
}
