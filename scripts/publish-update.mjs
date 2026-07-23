#!/usr/bin/env node
// Publish a frontend self-update to Cloudflare Pages.
//
// What it does: builds the frontend (vite, which bakes __APP_VERSION__ in),
// writes a versioned manifest.json + a CORS _headers file into dist/, then
// deploys the whole folder with `wrangler pages deploy`. The running app
// fetches `<baseUrl>manifest.json` and the listed files to self-update.
//
// ----------------------------------------------------------------------------
// ONE-TIME SETUP (run once, not per publish):
//   npm i -g wrangler                         # or: npx wrangler ...
//   wrangler login                            # or set CLOUDFLARE_API_TOKEN
//   wrangler pages project create piastra-print
//
// Then ship the update URL into the app. A packaged app (double-clicked) does
// NOT see env vars, so create this file next to the .exe (in the package's
// bin/ folder) containing one line — the Pages URL:
//
//     piastra-print.conf
//     -------------------
//     https://piastra-print.pages.dev/
//
// For dev/test you can instead launch the app with the env var set:
//     PIASTRA_UPDATE_URL=https://piastra-print.pages.dev/ zig build run
//
// ----------------------------------------------------------------------------
// PER PUBLISH:
//   node scripts/publish-update.mjs
//
// Env knobs:
//   PAGES_PROJECT   Cloudflare Pages project name (default: piastra-print)
// ----------------------------------------------------------------------------

import { execSync } from "node:child_process";
import { readFileSync, writeFileSync, readdirSync, statSync } from "node:fs";
import { join, relative, sep, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..");
const frontend = join(root, "frontend");
const dist = join(frontend, "dist");
const project = process.env.PAGES_PROJECT || "piastra-print";

function run(cmd) {
  console.log(`$ ${cmd}`);
  execSync(cmd, { stdio: "inherit", cwd: root });
}

// 1. Build the frontend -> dist/ (with the current version baked into __APP_VERSION__).
run("npm run build --prefix frontend");

const version = JSON.parse(readFileSync(join(frontend, "package.json"), "utf-8")).version;
console.log(`\nPublishing version ${version} -> project "${project}"`);

// 2. Collect dist files (relative, forward-slash paths), excluding generated bits.
const EXCLUDE = new Set(["manifest.json", "_headers"]);
function walk(dir, acc = []) {
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    const rel = relative(dist, full).split(sep).join("/");
    if (statSync(full).isDirectory()) {
      walk(full, acc);
    } else if (!EXCLUDE.has(rel)) {
      acc.push(rel);
    }
  }
  return acc;
}
const files = walk(dist).sort();

// 3. manifest.json + _headers (CORS-open for the WebView fetch; manifest not
//    over-cached so a freshly published version is seen promptly).
writeFileSync(
  join(dist, "manifest.json"),
  JSON.stringify({ version, files: files.map((path) => ({ path })) }, null, 2) + "\n",
);
writeFileSync(
  join(dist, "_headers"),
  ["/manifest.json", "  Cache-Control: public, max-age=0, must-revalidate", "/*", "  Access-Control-Allow-Origin: *", ""].join("\n"),
);

console.log(`Files in manifest: ${files.length + 1} (${files.join(", ") || "none"}, manifest.json)`);

// 4. Deploy the folder to Cloudflare Pages.
run(`wrangler pages deploy "${dist}" --project-name ${project} --branch main`);

const baseUrl = `https://${project}.pages.dev/`;
console.log("");
console.log("Done. The app resolves its update URL from, in order:");
console.log("  1. PIASTRA_UPDATE_URL env var");
console.log(`  2. a piastra-print.conf next to the exe containing: ${baseUrl}`);
console.log(`Bump frontend/package.json "version" before each publish (current: ${version}).`);
