<script setup lang="ts">
import { reactive, watch, computed, ref, onMounted } from "vue";
import { buildSvg, defaultParams, type Params } from "./lib/svg.js";
import { loadConfig, saveConfig, mergeConfig } from "./lib/config.js";
import StrokeControls from "./components/StrokeControls.vue";
import ToastHost from "./components/ToastHost.vue";
import { setTheme, type Theme } from "./lib/theme.js";
import { toast, dismiss } from "./lib/toast.js";
import { checkAndApplyUpdate } from "./lib/updater.js";
// Version baked into the build by vite (frontend/package.json).
declare const __APP_VERSION__: string;

// Restore the last-used configuration across relaunches (localStorage).
const params = reactive<Params>(loadConfig());
watch(params, () => saveConfig(params), { deep: true });

const svgDoc = computed(() => buildSvg(params));
// Drop the <?xml?> prolog for the preview (it parses as a bogus comment).
const previewSvg = computed(() =>
  svgDoc.value.replace(/<\?xml[\s\S]*?\?>\s*/, ""),
);
const cellCount = computed(
  () =>
    `${Math.max(0, Math.round(params.row))} × ${Math.max(0, Math.round(params.column))}`,
);

const importInput = ref<HTMLInputElement | null>(null);
const settingsDialog = ref<HTMLDialogElement | null>(null);
const updateRunning = ref(false);
const theme = ref<Theme>(
  document.documentElement.dataset.theme === "dark" ? "dark" : "light",
);

// Hinge compartments: border open by default, the rest folded.
const styleOpen = reactive<Record<string, boolean>>({
  border: true,
  circles: false,
  center: false,
  ruler: false,
});
function toggleStyle(key: string): void {
  styleOpen[key] = !styleOpen[key];
}

interface LayoutField {
  key: keyof Params;
  label: string;
  step: number;
  min?: number;
  unit?: string;
}
interface GeometryGroup {
  title: string;
  fields: LayoutField[];
}
const geometryGroups: GeometryGroup[] = [
  {
    title: "Layout",
    fields: [
      { key: "column", label: "Columns", step: 1, min: 0 },
      { key: "row", label: "Rows", step: 1, min: 0 },
    ],
  },
  {
    title: "Circle",
    fields: [
      { key: "diameter", label: "Diameter", step: 0.1, min: 0, unit: "mm" },
      { key: "distance", label: "Distance", step: 0.1, min: 0, unit: "mm" },
      { key: "rulerStep", label: "Ruler step", step: 0.1, min: 0, unit: "mm" },
      { key: "top", label: "Top", step: 0.1, unit: "mm" },
      { key: "left", label: "Left", step: 0.1, unit: "mm" },
    ],
  },
  {
    title: "Border",
    fields: [
      { key: "width", label: "Width", step: 0.1, min: 0, unit: "mm" },
      { key: "height", label: "Height", step: 0.1, min: 0, unit: "mm" },
    ],
  },
];

interface ZeroApi {
  invoke(command: string, payload?: Record<string, unknown>): Promise<unknown>;
}

// Native Save-As in the shell (window.zero present), Blob fallback in a plain
// browser so the UI is testable without the native shell.
async function download() {
  const out = svgDoc.value;
  const w = window as Window & { zero?: ZeroApi };
  try {
    if (w.zero) {
      const path = await w.zero.invoke("native-sdk.dialog.saveFile", {
        title: "Save SVG",
        defaultName: "grid.svg",
      });
      if (typeof path === "string") {
        await w.zero.invoke("app.writeSvg", { path, content: out });
        toast("Saved grid.svg", "success");
      }
      return;
    }
    const url = URL.createObjectURL(new Blob([out], { type: "image/svg+xml" }));
    const a = document.createElement("a");
    a.href = url;
    a.download = "grid.svg";
    a.click();
    URL.revokeObjectURL(url);
    toast("Saved grid.svg", "success");
  } catch {
    toast("Download failed", "error");
  }
}

async function exportConfig() {
  settingsDialog.value?.close();
  const json = JSON.stringify(params, null, 2);
  const w = window as Window & { zero?: ZeroApi };
  try {
    if (w.zero) {
      const path = await w.zero.invoke("native-sdk.dialog.saveFile", {
        title: "Export parameters",
        defaultName: "piastra-print-config.json",
      });
      if (typeof path === "string") {
        await w.zero.invoke("app.writeSvg", { path, content: json });
        toast("Exported parameters", "success");
      }
      return;
    }
    const url = URL.createObjectURL(new Blob([json], { type: "application/json" }));
    const a = document.createElement("a");
    a.href = url;
    a.download = "piastra-print-config.json";
    a.click();
    URL.revokeObjectURL(url);
    toast("Exported parameters", "info");
  } catch {
    toast("Export failed", "error");
  }
}

function triggerImport() {
  settingsDialog.value?.close();
  importInput.value?.click();
}

function onImportFile(e: Event) {
  const input = e.target as HTMLInputElement;
  const file = input.files?.[0];
  if (!file) return;
  file
    .text()
    .then((text) => {
      Object.assign(params, mergeConfig(JSON.parse(text)));
      toast("Imported config", "success");
    })
    .catch(() => {
      toast("Could not read that config file", "error");
    });
  input.value = "";
}

// Self-update: silent check on launch; manual from the Settings door. Outcomes
// surface as LED toasts (fixed, no layout shift) instead of inline alerts.
async function runUpdate(manual: boolean) {
  if (updateRunning.value) return;
  updateRunning.value = true;
  const checkingId = manual
    ? toast("Checking for updates…", "info")
    : undefined;
  const outcome = await checkAndApplyUpdate();
  if (checkingId !== undefined) dismiss(checkingId);
  updateRunning.value = false;
  switch (outcome.status) {
    case "not-configured":
      if (manual) toast("No update server configured", "error");
      break;
    case "up-to-date":
      if (manual) toast(`Up to date (v${outcome.version})`, "success");
      break;
    case "applied":
      toast(
        outcome.action === "reload"
          ? `Updated to v${outcome.version} — reloading…`
          : `Updated to v${outcome.version} — restart to finish`,
        "success",
      );
      break;
    case "error":
      if (manual) toast(outcome.message, "error");
      break;
  }
}

function checkUpdates() {
  settingsDialog.value?.close();
  runUpdate(true);
}

// Close the settings door when the backdrop (the dialog element itself, not
// the door panel) is clicked.
function onDialogClick() {
  settingsDialog.value?.close();
}

const geometryKeys = [
  "row", "column", "diameter", "distance", "rulerStep",
  "width", "height", "left", "top",
] as const;

function resetGeometry() {
  for (const key of geometryKeys) params[key] = defaultParams[key];
  toast("Reset geometry", "info");
}

function resetStyles() {
  params.border = { ...defaultParams.border };
  params.circles = { ...defaultParams.circles };
  params.center = { ...defaultParams.center };
  params.ruler = { ...defaultParams.ruler };
  toast("Reset styles", "info");
}

function toggleTheme() {
  const next: Theme = theme.value === "dark" ? "light" : "dark";
  theme.value = next;
  setTheme(next);
}

onMounted(() => {
  runUpdate(false);
});
</script>

<template>
  <main class="fp-shell">
    <div class="fp-device">
      <div class="fp-deck-plate">
        <!-- Brand plate -->
        <header class="fp-brand">
          <div class="fp-brand-id">
            <span class="fp-led" aria-hidden="true"></span>
            <h1 class="fp-wordmark">Piastra Print</h1>
            <span class="fp-model hidden sm:inline">Precision Grid · mm</span>
          </div>
          <div class="fp-topswitches">
            <button
              class="fp-chrome fp-chrome--icon"
              @click="toggleTheme"
              :title="theme === 'dark' ? 'Switch to light' : 'Switch to dark'"
              aria-label="Toggle color theme"
            >
              <svg
                v-if="theme === 'dark'"
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.36-6.36l-.7.7M6.34 17.66l-.7.7m12.72 0l-.7-.7M6.34 6.34l-.7-.7M16 12a4 4 0 11-8 0 4 4 0 018 0z"
                />
              </svg>
              <svg
                v-else
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M21 12.79A9 9 0 1111.21 3 7 7 0 0021 12.79z"
                />
              </svg>
            </button>
            <button
              class="fp-chrome fp-chrome--icon"
              @click="settingsDialog?.showModal()"
              title="Settings"
              aria-label="Settings"
            >
              <svg xmlns="http://www.w3.org/2000/svg" fill="currentColor" viewBox="0 0 24 24">
                <circle cx="12" cy="5" r="1.7" />
                <circle cx="12" cy="12" r="1.7" />
                <circle cx="12" cy="19" r="1.7" />
              </svg>
            </button>
          </div>
        </header>
        <input
          ref="importInput"
          type="file"
          accept="application/json,.json"
          class="hidden"
          @change="onImportFile"
        />

        <!-- Body: control deck + display -->
        <div class="fp-body">
          <div class="fp-deck">
            <!-- Geometry -->
            <section class="fp-panel">
              <div class="fp-panel-head">
                <h2 class="fp-panel-label">Geometry</h2>
                <button class="fp-ghost" @click="resetGeometry">Reset</button>
              </div>
              <div v-for="g in geometryGroups" :key="g.title" class="mb-3 last:mb-0">
                <h3 class="fp-sub">{{ g.title }}</h3>
                <div class="fp-fields">
                  <label v-for="f in g.fields" :key="f.key" class="fp-field">
                    <span class="fp-field-label">
                      <span>{{ f.label }}</span>
                      <em v-if="f.unit">{{ f.unit }}</em>
                    </span>
                    <input
                      v-model.number="params[f.key]"
                      type="number"
                      :step="f.step"
                      :min="f.min"
                      class="fp-readout"
                    />
                  </label>
                </div>
              </div>
            </section>

            <!-- Stroke styles (hinged compartments) -->
            <section class="fp-panel">
              <div class="fp-panel-head">
                <h2 class="fp-panel-label">Stroke Styles</h2>
                <button class="fp-ghost" @click="resetStyles">Reset</button>
              </div>
              <div class="flex flex-col gap-2">
                <!-- Border -->
                <div class="fp-hinge" :data-open="styleOpen.border">
                  <button
                    class="fp-hinge-head"
                    :aria-expanded="styleOpen.border"
                    aria-controls="hinge-border"
                    @click="toggleStyle('border')"
                  >
                    <span class="fp-hinge-dot" :style="{ backgroundColor: params.border.color }"></span>
                    <span class="fp-hinge-name">Border</span>
                    <svg class="fp-hinge-chevron" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>
                  <div v-show="styleOpen.border" id="hinge-border" class="fp-hinge-body">
                    <StrokeControls v-model="params.border" />
                  </div>
                </div>

                <!-- Circles -->
                <div class="fp-hinge" :data-open="styleOpen.circles">
                  <button
                    class="fp-hinge-head"
                    :aria-expanded="styleOpen.circles"
                    aria-controls="hinge-circles"
                    @click="toggleStyle('circles')"
                  >
                    <span class="fp-hinge-dot" :style="{ backgroundColor: params.circles.color }"></span>
                    <span class="fp-hinge-name">Circles</span>
                    <svg class="fp-hinge-chevron" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>
                  <div v-show="styleOpen.circles" id="hinge-circles" class="fp-hinge-body space-y-3">
                    <StrokeControls v-model="params.circles" />
                    <div class="fp-toggle-row">
                      <button
                        class="fp-toggle"
                        role="switch"
                        :aria-checked="params.circles.alternate"
                        @click="params.circles.alternate = !params.circles.alternate"
                      >
                        <span class="fp-toggle-thumb"></span>
                      </button>
                      <span class="fp-toggle-text">Alternate two colors (checkerboard)</span>
                    </div>
                    <div v-if="params.circles.alternate">
                      <label class="fp-field">
                        <span class="fp-field-label"><span>Second color</span></span>
                        <div class="fp-slot">
                          <input type="color" v-model="params.circles.colorAlt" class="fp-swatch" aria-label="Second circle color" />
                          <input type="text" v-model="params.circles.colorAlt" class="fp-readout" aria-label="Second circle color hex" />
                        </div>
                      </label>
                    </div>
                  </div>
                </div>

                <!-- Center -->
                <div class="fp-hinge" :data-open="styleOpen.center">
                  <button
                    class="fp-hinge-head"
                    :aria-expanded="styleOpen.center"
                    aria-controls="hinge-center"
                    @click="toggleStyle('center')"
                  >
                    <span class="fp-hinge-dot" :style="{ backgroundColor: params.center.color }"></span>
                    <span class="fp-hinge-name">Center <small>crosshair</small></span>
                    <svg class="fp-hinge-chevron" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>
                  <div v-show="styleOpen.center" id="hinge-center" class="fp-hinge-body">
                    <StrokeControls v-model="params.center" />
                  </div>
                </div>

                <!-- Ruler -->
                <div class="fp-hinge" :data-open="styleOpen.ruler">
                  <button
                    class="fp-hinge-head"
                    :aria-expanded="styleOpen.ruler"
                    aria-controls="hinge-ruler"
                    @click="toggleStyle('ruler')"
                  >
                    <span class="fp-hinge-dot" :style="{ backgroundColor: params.ruler.color }"></span>
                    <span class="fp-hinge-name">Ruler</span>
                    <svg class="fp-hinge-chevron" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>
                  <div v-show="styleOpen.ruler" id="hinge-ruler" class="fp-hinge-body space-y-3">
                    <StrokeControls v-model="params.ruler" />
                    <div class="fp-toggle-row">
                      <button
                        class="fp-toggle"
                        role="switch"
                        :aria-checked="params.ruler.twoColor"
                        @click="params.ruler.twoColor = !params.ruler.twoColor"
                      >
                        <span class="fp-toggle-thumb"></span>
                      </button>
                      <span class="fp-toggle-text">Two colors (left / right)</span>
                    </div>
                    <div v-if="params.ruler.twoColor">
                      <label class="fp-field">
                        <span class="fp-field-label"><span>Right-side color</span></span>
                        <div class="fp-slot">
                          <input type="color" v-model="params.ruler.colorRight" class="fp-swatch" aria-label="Right-side ruler color" />
                          <input type="text" v-model="params.ruler.colorRight" class="fp-readout" aria-label="Right-side ruler color hex" />
                        </div>
                      </label>
                    </div>
                  </div>
                </div>
              </div>
            </section>
          </div>

          <!-- Display -->
          <div class="fp-stage">
            <div class="fp-display">
              <div class="fp-display-bar">
                <span class="fp-display-tag">
                  <span class="fp-rec" aria-hidden="true"></span>
                  Live Preview
                </span>
                <span class="fp-meter"><b class="fp-meter-readout">{{ cellCount }}</b> cells</span>
              </div>
              <div class="fp-display-face" v-html="previewSvg"></div>
              <p class="fp-caption">
                Preview scales to fit; the saved file keeps the real mm dimensions.
              </p>
            </div>
            <button class="fp-action" @click="download">
              <span class="fp-action-led" aria-hidden="true"></span>
              Download SVG
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Settings (cassette door) -->
    <dialog ref="settingsDialog" class="fp-modal" @click.self="onDialogClick">
      <div class="fp-door">
        <div class="fp-door-head">
          <span class="fp-door-title">Settings</span>
          <form method="dialog">
            <button class="fp-chrome fp-chrome--icon" aria-label="Close settings">
              <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </form>
        </div>
        <div class="fp-door-body">
          <button class="fp-door-row" :disabled="updateRunning" @click="checkUpdates">
            <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M4 4v6h6M20 20v-6h-6M20 9A8 8 0 006 5.3L4 8M4 15a8 8 0 0014 3.7l2-2.7" />
            </svg>
            <span>Check for updates</span>
            <small>{{ updateRunning ? "···" : `v${__APP_VERSION__}` }}</small>
          </button>
          <button class="fp-door-row" @click="triggerImport">
            <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M4 16v2a2 2 0 002 2h12a2 2 0 002-2v-2M12 3v12m0 0l-4-4m4 4l4-4" />
            </svg>
            <span>Import parameters</span>
            <small>JSON</small>
          </button>
          <button class="fp-door-row" @click="exportConfig">
            <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 15V3M8 7l4-4 4 4M4 14v5a1 1 0 001 1h14a1 1 0 001-1v-5" />
            </svg>
            <span>Export parameters</span>
            <small>JSON</small>
          </button>
        </div>
      </div>
    </dialog>

    <!-- Notifications (fixed; no layout shift) -->
    <ToastHost />
  </main>
</template>
