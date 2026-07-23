// Frontend-driven self-update.
//
// The native shell owns a writable "overlay" directory under %LOCALAPPDATA%
// that source() prefers over the bundled assets once it exists. This module
// fetches a versioned manifest + asset files from a CORS-open Cloudflare Pages
// URL (configured via the PIASTRA_UPDATE_URL env var), streams each whole file
// to the native `app.update*` bridge commands, then asks native to swap the
// overlay in. The version baked into the loaded build (__APP_VERSION__) is the
// baseline; the manifest's version is the candidate.

declare const __APP_VERSION__: string;

interface ZeroApi {
  invoke(command: string, payload?: Record<string, unknown>): Promise<unknown>;
}
interface UpdateInfo {
  baseUrl: string;
  serving: "overlay" | "bundled";
}
interface Manifest {
  version: string;
  files: { path: string }[];
}

function zero(): ZeroApi | undefined {
  return (window as Window & { zero?: ZeroApi }).zero;
}

// Negative when a < b, zero when equal, positive when a > b. Non-numeric
// components fall back to 0, so "0.2.0" > "0.1.0" and "1.0.0" > "0.9.9".
function compareVersions(a: string, b: string): number {
  const pa = a.split(".").map((n) => Number.parseInt(n, 10) || 0);
  const pb = b.split(".").map((n) => Number.parseInt(n, 10) || 0);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const da = pa[i] ?? 0;
    const db = pb[i] ?? 0;
    if (da !== db) return da - db;
  }
  return 0;
}

const CURRENT_VERSION: string = typeof __APP_VERSION__ !== "undefined" ? __APP_VERSION__ : "0.0.0";

export type UpdateOutcome =
  | { status: "not-configured" }
  | { status: "up-to-date"; version: string }
  | { status: "applied"; version: string; action: "reload" | "restart-required" }
  | { status: "error"; message: string };

/**
 * Check the configured update server for a newer build and, if found, download
 * and install it into the overlay. `onProgress` receives human-readable status
 * for UI feedback. Safe to call on launch (silent) or from a manual button.
 */
export async function checkAndApplyUpdate(onProgress?: (msg: string) => void): Promise<UpdateOutcome> {
  const z = zero();
  if (!z) return { status: "error", message: "Native bridge unavailable." };

  let info: UpdateInfo;
  try {
    info = (await z.invoke("app.getUpdateInfo")) as UpdateInfo;
  } catch (e) {
    return { status: "error", message: `Update check failed: ${(e as Error).message}` };
  }
  if (!info.baseUrl) return { status: "not-configured" };

  const base = info.baseUrl.endsWith("/") ? info.baseUrl : info.baseUrl + "/";
  // Cache-bust so a freshly published manifest is seen immediately.
  const bust = () => `?t=${Date.now()}`;

  onProgress?.("Checking for updates…");
  let manifest: Manifest;
  try {
    const res = await fetch(base + "manifest.json" + bust());
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    manifest = (await res.json()) as Manifest;
  } catch (e) {
    return { status: "error", message: `Couldn't reach update server: ${(e as Error).message}` };
  }

  if (compareVersions(manifest.version, CURRENT_VERSION) <= 0) {
    return { status: "up-to-date", version: CURRENT_VERSION };
  }

  try {
    await z.invoke("app.updateBegin", {});
    for (const file of manifest.files) {
      onProgress?.(`Downloading ${file.path}…`);
      const res = await fetch(base + file.path + bust());
      if (!res.ok) throw new Error(`HTTP ${res.status} for ${file.path}`);
      // Whole file per call — the bridge accepts up to 1 MiB, far above these
      // assets. Sent as a JSON string; native decodes escapes on the other side.
      const data = await res.text();
      await z.invoke("app.updateWrite", { path: file.path, data });
    }
    onProgress?.("Installing…");
    const result = (await z.invoke("app.updateCommit", {})) as { serving: string };

    const action: "reload" | "restart-required" =
      result.serving === "overlay" ? "reload" : "restart-required";
    if (action === "reload") {
      // Give the success UI a beat, then reload index.html with a version
      // query so the new (cache-busted) asset graph is served from the overlay.
      const v = encodeURIComponent(manifest.version);
      setTimeout(() => location.replace(`index.html?v=${v}`), 500);
    }
    return { status: "applied", version: manifest.version, action };
  } catch (e) {
    return { status: "error", message: `Update failed: ${(e as Error).message}` };
  }
}
