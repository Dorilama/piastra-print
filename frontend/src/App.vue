<script setup lang="ts">
import { reactive, watch, computed, ref, onMounted } from "vue";
import { buildSvg, defaultParams, type Params } from "./lib/svg.js";
import { loadConfig, saveConfig, mergeConfig } from "./lib/config.js";
import StrokeControls from "./components/StrokeControls.vue";
import ToastHost from "./components/ToastHost.vue";
import { setTheme, type Theme } from "./lib/theme.js";
import { toast, dismiss } from "./lib/toast.js";
import { checkAndApplyUpdate } from "./lib/updater.js";

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
    `${Math.max(0, Math.round(params.row))} × ${Math.max(0, Math.round(params.column))} cells`,
);

const importInput = ref<HTMLInputElement | null>(null);
const settingsDialog = ref<HTMLDialogElement | null>(null);
const updateRunning = ref(false);
const theme = ref<Theme>(
  document.documentElement.dataset.theme === "dark" ? "dark" : "light",
);

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

// Self-update: silent check on launch; manual from the Settings modal. Outcomes
// surface as toasts (fixed, no layout shift) instead of an inline alert.
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
  <main class="min-h-screen w-full bg-base-200 p-4 sm:p-6">
    <div class="max-w-5xl mx-auto grid lg:grid-cols-2 gap-6 items-start">
      <!-- Controls -->
      <div class="space-y-5">
        <header class="flex items-start justify-between gap-4">
          <div>
            <h1 class="text-2xl font-bold">Piastra Print</h1>
            <p class="text-base-content/60 text-sm">
              Grid generator — geometry and stroke styles, fully editable.
            </p>
          </div>
          <div class="flex gap-1">
            <button
              class="btn btn-ghost btn-sm btn-circle"
              @click="toggleTheme"
              :title="
                theme === 'dark'
                  ? 'Switch to light mode'
                  : 'Switch to dark mode'
              "
              aria-label="Toggle color theme"
            >
              <svg
                v-if="theme === 'dark'"
                xmlns="http://www.w3.org/2000/svg"
                class="w-5 h-5"
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
                class="w-5 h-5"
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
              class="btn btn-ghost btn-sm btn-circle"
              @click="settingsDialog?.showModal()"
              title="Settings"
              aria-label="Settings"
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                <circle cx="12" cy="5" r="1.6" />
                <circle cx="12" cy="12" r="1.6" />
                <circle cx="12" cy="19" r="1.6" />
              </svg>
            </button>
          </div>
          <input
            ref="importInput"
            type="file"
            accept="application/json,.json"
            class="hidden"
            @change="onImportFile"
          />
        </header>

        <!-- Geometry -->
        <section class="bg-base-100 rounded-box shadow p-4 space-y-4">
          <div class="flex items-center justify-between">
            <h2 class="text-sm font-semibold">Geometry</h2>
            <button class="btn btn-ghost btn-xs" @click="resetGeometry">Reset</button>
          </div>
          <div v-for="g in geometryGroups" :key="g.title">
            <h3
              class="text-xs font-semibold uppercase tracking-wide text-base-content/50 mb-2"
            >
              {{ g.title }}
            </h3>
            <div class="grid grid-cols-2 sm:grid-cols-3 gap-3">
              <label v-for="f in g.fields" :key="f.key" class="form-control">
                <span class="label-text text-xs mb-1 flex justify-between">
                  <span>{{ f.label }}</span>
                  <span v-if="f.unit" class="opacity-50">{{ f.unit }}</span>
                </span>
                <input
                  v-model.number="params[f.key]"
                  type="number"
                  :step="f.step"
                  :min="f.min"
                  class="input input-bordered input-sm w-full"
                />
              </label>
            </div>
          </div>
        </section>

        <!-- Stroke styles (accordion) -->
        <section class="bg-base-100 rounded-box shadow p-4 space-y-2">
          <div class="flex items-center justify-between mb-1">
            <h2 class="text-sm font-semibold">Stroke styles</h2>
            <button class="btn btn-ghost btn-xs" @click="resetStyles">Reset</button>
          </div>

          <div
            class="collapse collapse-arrow bg-base-200 border border-base-300 rounded-lg"
          >
            <input type="checkbox" checked />
            <div class="collapse-title font-medium flex items-center gap-2">
              <span
                class="inline-block w-3 h-3 rounded-full ring-1 ring-base-content/20"
                :style="{ backgroundColor: params.border.color }"
              ></span>
              <span>Border</span>
            </div>
            <div class="collapse-content">
              <StrokeControls v-model="params.border" />
            </div>
          </div>

          <div
            class="collapse collapse-arrow bg-base-200 border border-base-300 rounded-lg"
          >
            <input type="checkbox" />
            <div class="collapse-title font-medium flex items-center gap-2">
              <span
                class="inline-block w-3 h-3 rounded-full ring-1 ring-base-content/20"
                :style="{ backgroundColor: params.circles.color }"
              ></span>
              <span>Circles</span>
            </div>
            <div class="collapse-content space-y-3">
              <StrokeControls v-model="params.circles" />
              <label class="label cursor-pointer justify-start gap-3 py-1">
                <input
                  type="checkbox"
                  class="toggle toggle-sm"
                  v-model="params.circles.alternate"
                />
                <span class="label-text"
                  >Alternate two colors (checkerboard)</span
                >
              </label>
              <div v-if="params.circles.alternate" class="pl-1">
                <span class="label-text text-xs block mb-1">Second color</span>
                <div class="flex gap-1 items-center">
                  <input
                    type="color"
                    v-model="params.circles.colorAlt"
                    class="w-9 h-8 shrink-0 rounded cursor-pointer border border-base-300 bg-base-100"
                  />
                  <input
                    type="text"
                    v-model="params.circles.colorAlt"
                    class="input input-bordered input-sm w-24 font-mono text-xs uppercase"
                  />
                </div>
              </div>
            </div>
          </div>

          <div
            class="collapse collapse-arrow bg-base-200 border border-base-300 rounded-lg"
          >
            <input type="checkbox" />
            <div class="collapse-title font-medium flex items-center gap-2">
              <span
                class="inline-block w-3 h-3 rounded-full ring-1 ring-base-content/20"
                :style="{ backgroundColor: params.center.color }"
              ></span>
              <span
                >Center
                <span class="opacity-50 font-normal">(crosshair)</span></span
              >
            </div>
            <div class="collapse-content">
              <StrokeControls v-model="params.center" />
            </div>
          </div>

          <div
            class="collapse collapse-arrow bg-base-200 border border-base-300 rounded-lg"
          >
            <input type="checkbox" />
            <div class="collapse-title font-medium flex items-center gap-2">
              <span
                class="inline-block w-3 h-3 rounded-full ring-1 ring-base-content/20"
                :style="{ backgroundColor: params.ruler.color }"
              ></span>
              <span>Ruler</span>
            </div>
            <div class="collapse-content space-y-3">
              <StrokeControls v-model="params.ruler" />
              <label class="label cursor-pointer justify-start gap-3 py-1">
                <input
                  type="checkbox"
                  class="toggle toggle-sm"
                  v-model="params.ruler.twoColor"
                />
                <span class="label-text">Two colors (left / right)</span>
              </label>
              <div v-if="params.ruler.twoColor" class="pl-1">
                <span class="label-text text-xs block mb-1"
                  >Right-side color</span
                >
                <div class="flex gap-1 items-center">
                  <input
                    type="color"
                    v-model="params.ruler.colorRight"
                    class="w-9 h-8 shrink-0 rounded cursor-pointer border border-base-300 bg-base-100"
                  />
                  <input
                    type="text"
                    v-model="params.ruler.colorRight"
                    class="input input-bordered input-sm w-24 font-mono text-xs uppercase"
                  />
                </div>
              </div>
            </div>
          </div>
        </section>
      </div>

      <!-- Preview -->
      <div class="space-y-3 lg:sticky lg:top-6">
        <section class="bg-base-100 rounded-box shadow p-4">
          <div class="flex items-center justify-between mb-2">
            <h2 class="text-sm font-semibold">Live preview</h2>
            <span class="text-xs text-base-content/50">{{ cellCount }}</span>
          </div>
          <div
            class="preview border border-base-300 rounded-box flex items-center justify-center overflow-hidden p-3"
            style="background: #fff; height: 360px"
            v-html="previewSvg"
          ></div>
          <p class="text-xs text-base-content/40 mt-1">
            Preview scales to fit; the downloaded file keeps the real mm
            dimensions.
          </p>
        </section>
        <button class="btn btn-primary w-full" @click="download">
          Download SVG
        </button>
      </div>
    </div>

    <!-- Settings -->
    <dialog ref="settingsDialog" class="modal">
      <div class="modal-box">
        <h3 class="text-lg font-bold mb-3">Settings</h3>
        <div class="space-y-1">
          <button
            class="btn btn-ghost w-full justify-start"
            :disabled="updateRunning"
            @click="checkUpdates"
          >
            Check updates
          </button>
          <button
            class="btn btn-ghost w-full justify-start"
            @click="triggerImport"
          >
            Import Parameters
          </button>
          <button
            class="btn btn-ghost w-full justify-start"
            @click="exportConfig"
          >
            Export Parameters
          </button>
        </div>
        <div class="modal-action">
          <form method="dialog"><button class="btn btn-sm">Close</button></form>
        </div>
      </div>
      <form method="dialog" class="modal-backdrop"><button>close</button></form>
    </dialog>

    <!-- Notifications (fixed; no layout shift) -->
    <ToastHost />
  </main>
</template>
