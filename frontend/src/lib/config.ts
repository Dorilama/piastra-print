// Configuration persistence: save/restore across relaunches via localStorage,
// plus deep-merge so partial or older configs never drop a field. Import/export
// use plain browser APIs (Blob + FileReader), which also work inside WebView2.

import { defaultParams, type Params } from "./svg.js";

const STORAGE_KEY = "piastra-print.config.v1";

function validNum(v: unknown): number | undefined {
  const n = typeof v === "number" ? v : typeof v === "string" ? Number(v) : NaN;
  return Number.isFinite(n) ? n : undefined;
}

// Merge an unknown (parsed JSON from storage or an import file) over the
// defaults, coercing each field by type. Unknown/partial/older shapes degrade
// gracefully to the default rather than producing a broken Params.
export function mergeConfig(input: unknown): Params {
  // Deep clone of the defaults (no structuredClone dependency).
  const out = JSON.parse(JSON.stringify(defaultParams)) as Params;
  if (typeof input !== "object" || input === null) return out;
  const src = input as Record<string, unknown>;

  const scalars = [
    "row", "column", "diameter", "distance", "rulerStep",
    "width", "height", "left", "top",
  ] as const;
  for (const key of scalars) {
    const n = validNum(src[key]);
    if (n !== undefined) out[key] = n;
  }
  // Backward-compat: the original shape stored the ruler step under `ruler`.
  if (typeof src.ruler === "number") out.rulerStep = src.ruler;

  for (const g of ["border", "circles", "center", "ruler"] as const) {
    const sg = src[g];
    if (typeof sg !== "object" || sg === null) continue;
    const srcG = sg as Record<string, unknown>;
    const dstG = out[g] as Record<string, unknown>;
    for (const fieldKey of Object.keys(dstG)) {
      const current = dstG[fieldKey];
      const value = srcG[fieldKey];
      if (typeof current === "number") {
        const n = validNum(value);
        if (n !== undefined) dstG[fieldKey] = n;
      } else if (typeof current === "boolean") {
        if (typeof value === "boolean") dstG[fieldKey] = value;
      } else if (typeof current === "string" && typeof value === "string") {
        dstG[fieldKey] = value;
      }
    }
  }
  return out;
}

export function loadConfig(): Params {
  const fallback = JSON.parse(JSON.stringify(defaultParams)) as Params;
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? mergeConfig(JSON.parse(raw)) : fallback;
  } catch {
    return fallback;
  }
}

export function saveConfig(params: Params): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(params));
  } catch {
    // Storage unavailable (private mode / quota) — persistence is best-effort.
  }
}
