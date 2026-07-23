import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";
import tailwindcss from "@tailwindcss/vite";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const projectDir = dirname(fileURLToPath(import.meta.url));

// Bake the app version (from app.zon) into the bundle so the UI can show it
// without reading the manifest at runtime. Falls back if app.zon is absent.
let appVersion = "0.0.0";
try {
  const manifest = readFileSync(resolve(projectDir, "..", "app.zon"), "utf8");
  const match = manifest.match(/\.version\s*=\s*"([^"]+)"/);
  if (match) appVersion = match[1];
} catch {
  // app.zon not found — keep the 0.0.0 fallback.
}

export default defineConfig({
  plugins: [vue(), tailwindcss()],
  define: {
    __APP_VERSION__: JSON.stringify(appVersion),
  },
});
