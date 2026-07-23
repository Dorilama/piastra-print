<script setup lang="ts">
import { reactive, watch, computed, ref } from "vue";
import { buildSvg, defaultParams, type Params } from "./lib/svg.js";
import { loadConfig, saveConfig, mergeConfig } from "./lib/config.js";
import { setTheme, type Theme } from "./lib/theme.js";
import { toast } from "./lib/toast.js";
import { APP_VERSION } from "./lib/version.js";
import StrokeControls from "./components/StrokeControls.vue";
import ToastHost from "./components/ToastHost.vue";

// Restore the last-used configuration across relaunches (localStorage).
const params = reactive<Params>(loadConfig());
watch(params, () => saveConfig(params), { deep: true });

const svgDoc = computed(() => buildSvg(params));
// Drop the <?xml?> prolog for the preview (it parses as a bogus comment).
const previewSvg = computed(() => svgDoc.value.replace(/<\?xml[\s\S]*?\?>\s*/, ""));
const cellCount = computed(
  () => `${Math.max(0, Math.round(params.row))} × ${Math.max(0, Math.round(params.column))} cells`,
);

const importInput = ref<HTMLInputElement | null>(null);
const settingsDialog = ref<HTMLDialogElement | null>(null);
const theme = ref<Theme>(document.documentElement.dataset.theme === "dark" ? "dark" : "light");

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

function exportConfig() {
  settingsDialog.value?.close();
  const json = JSON.stringify(params, null, 2);
  const url = URL.createObjectURL(new Blob([json], { type: "application/json" }));
  const a = document.createElement("a");
  a.href = url;
  a.download = "piastra-print-config.json";
  a.click();
  URL.revokeObjectURL(url);
  toast("Exported config", "info");
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

// No update source is configured yet: report the installed version as current.
function checkUpdates() {
  settingsDialog.value?.close();
  toast(`Piastra Print v${APP_VERSION} is up to date`, "success");
}

function reset() {
  Object.assign(params, defaultParams);
  toast("Reset to defaults", "info");
}

function toggleTheme() {
  const next: Theme = theme.value === "dark" ? "light" : "dark";
  theme.value = next;
  setTheme(next);
}
</script>

<template>
  <main class="min-h-screen w-full bg-base-200 p-4 sm:p-6">
    <div class="max-w-5xl mx-auto grid lg:grid-cols-2 gap-6 items-start">
      <!-- Controls -->
      <div class="space-y-5">
        <header class="flex items-start justify-between gap-4">
          <div>
            <h1 class="text-2xl font-bold">Piastra Print</h1>
            <p class="text-base-content/60 text-sm">Grid generator — geometry and stroke styles, fully editable.</p>
          </div>
          <div class="flex gap-1">
            <button class="btn btn-ghost btn-sm btn-circle" @click="toggleTheme" :title="theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'" aria-label="Toggle color theme">
              <svg v-if="theme === 'dark'" xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.36-6.36l-.7.7M6.34 17.66l-.7.7m12.72 0l-.7-.7M6.34 6.34l-.7-.7M16 12a4 4 0 11-8 0 4 4 0 018 0z" /></svg>
              <svg v-else xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M21 12.79A9 9 0 1111.21 3 7 7 0 0021 12.79z" /></svg>
            </button>
            <button class="btn btn-ghost btn-sm btn-circle" @click="settingsDialog?.showModal()" title="Settings" aria-label="Settings">
              <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 8a4 4 0 100 8 4 4 0 000-8z" /><path stroke-linecap="round" stroke-linejoin="round" d="M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 11-2.83 2.83l-.06-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51V21a2 2 0 11-4 0v-.09A1.65 1.65 0 009 19.4a1.65 1.65 0 00-1.82.33l-.06.06a2 2 0 11-2.83-2.83l.06-.06a1.65 1.65 0 00.33-1.82 1.65 1.65 0 00-1.51-1H3a2 2 0 110-4h.09A1.65 1.65 0 004.6 9a1.65 1.65 0 00-.33-1.82l-.06-.06a2 2 0 112.83-2.83l.06.06a1.65 1.65 0 001.82.33H9a1.65 1.65 0 001-1.51V3a2 2 0 114 0v.09a1.65 1.65 0 001 1.51 1.65 1.65 0 001.82-.33l.06-.06a2 2 0 112.83 2.83l-.06.06a1.65 1.65 0 00-.33 1.82V9a1.65 1.65 0 001.51 1H21a2 2 0 110 4h-.09a1.65 1.65 0 00-1.51 1z" /></svg>
            </button>
          </div>
          <input ref="importInput" type="file" accept="application/json,.json" class="hidden" @change="onImportFile" />
        </header>

        <!-- Geometry -->
        <section class="bg-base-100 rounded-box shadow p-4 space-y-4">
          <div class="flex items-center justify-between">
            <h2 class="text-sm font-semibold">Geometry</h2>
            <button class="btn btn-ghost btn-xs" @click="reset">Reset</button>
          </div>
          <div v-for="g in geometryGroups" :key="g.title">
            <h3 class="text-xs font-semibold uppercase tracking-wide text-base-content/50 mb-2">{{ g.title }}</h3>
            <div class="grid grid-cols-2 sm:grid-cols-3 gap-3">
              <label v-for="f in g.fields" :key="f.key" class="form-control">
                <span class="label-text text-xs mb-1 flex justify-between">
                  <span>{{ f.label }}</span>
                  <span v-if="f.unit" class="opacity-50">{{ f.unit }}</span>
                </span>
                <input v-model.number="params[f.key]" type="number" :step="f.step" :min="f.min" class="input input-bordered input-sm w-full" />
              </label>
            </div>
          </div>
        </section>

        <!-- Stroke styles (accordion) -->
        <section class="bg-base-100 rounded-box shadow p-4 space-y-2">
          <h2 class="text-sm font-semibold mb-1">Stroke styles</h2>

          <div class="collapse collapse-arrow bg-base-200 border border-base-300 rounded-lg">
            <input type="checkbox" checked />
            <div class="collapse-title font-medium flex items-center gap-2">
              <span class="inline-block w-3 h-3 rounded-full ring-1 ring-base-content/20" :style="{ backgroundColor: params.border.color }"></span>
              <span>Border</span>
            </div>
            <div class="collapse-content"><StrokeControls v-model="params.border" /></div>
          </div>

          <div class="collapse collapse-arrow bg-base-200 border border-base-300 rounded-lg">
            <input type="checkbox" />
            <div class="collapse-title font-medium flex items-center gap-2">
              <span class="inline-block w-3 h-3 rounded-full ring-1 ring-base-content/20" :style="{ backgroundColor: params.circles.color }"></span>
              <span>Circles</span>
            </div>
            <div class="collapse-content space-y-3">
              <StrokeControls v-model="params.circles" />
              <label class="label cursor-pointer justify-start gap-3 py-1">
                <input type="checkbox" class="toggle toggle-sm" v-model="params.circles.alternate" />
                <span class="label-text">Alternate two colors (checkerboard)</span>
              </label>
              <div v-if="params.circles.alternate" class="pl-1">
                <span class="label-text text-xs block mb-1">Second color</span>
                <div class="flex gap-1 items-center">
                  <input type="color" v-model="params.circles.colorAlt" class="w-9 h-8 shrink-0 rounded cursor-pointer border border-base-300 bg-base-100" />
                  <input type="text" v-model="params.circles.colorAlt" class="input input-bordered input-sm w-24 font-mono text-xs uppercase" />
                </div>
              </div>
            </div>
          </div>

          <div class="collapse collapse-arrow bg-base-200 border border-base-300 rounded-lg">
            <input type="checkbox" />
            <div class="collapse-title font-medium flex items-center gap-2">
              <span class="inline-block w-3 h-3 rounded-full ring-1 ring-base-content/20" :style="{ backgroundColor: params.center.color }"></span>
              <span>Center <span class="opacity-50 font-normal">(crosshair)</span></span>
            </div>
            <div class="collapse-content"><StrokeControls v-model="params.center" /></div>
          </div>

          <div class="collapse collapse-arrow bg-base-200 border border-base-300 rounded-lg">
            <input type="checkbox" />
            <div class="collapse-title font-medium flex items-center gap-2">
              <span class="inline-block w-3 h-3 rounded-full ring-1 ring-base-content/20" :style="{ backgroundColor: params.ruler.color }"></span>
              <span>Ruler</span>
            </div>
            <div class="collapse-content space-y-3">
              <StrokeControls v-model="params.ruler" />
              <label class="label cursor-pointer justify-start gap-3 py-1">
                <input type="checkbox" class="toggle toggle-sm" v-model="params.ruler.twoColor" />
                <span class="label-text">Two colors (left / right)</span>
              </label>
              <div v-if="params.ruler.twoColor" class="pl-1">
                <span class="label-text text-xs block mb-1">Right-side color</span>
                <div class="flex gap-1 items-center">
                  <input type="color" v-model="params.ruler.colorRight" class="w-9 h-8 shrink-0 rounded cursor-pointer border border-base-300 bg-base-100" />
                  <input type="text" v-model="params.ruler.colorRight" class="input input-bordered input-sm w-24 font-mono text-xs uppercase" />
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
            Preview scales to fit; the downloaded file keeps the real mm dimensions.
          </p>
        </section>
        <button class="btn btn-primary w-full" @click="download">Download SVG</button>
      </div>
    </div>

    <!-- Settings -->
    <dialog ref="settingsDialog" class="modal">
      <div class="modal-box">
        <h3 class="text-lg font-bold mb-3">Settings</h3>
        <div class="space-y-1">
          <button class="btn btn-ghost w-full justify-start" @click="checkUpdates">Update</button>
          <button class="btn btn-ghost w-full justify-start" @click="triggerImport">Import</button>
          <button class="btn btn-ghost w-full justify-start" @click="exportConfig">Export</button>
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
