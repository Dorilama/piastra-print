<script setup lang="ts">
import { reactive, computed } from "vue";
import { buildSvg, defaultParams, type Params } from "./lib/svg.js";

const params = reactive<Params>({ ...defaultParams });

// Full SVG document (with the <?xml?> prolog) for download fidelity.
const svgDoc = computed(() => buildSvg(params));
// For the preview, drop the prolog: under v-html it parses as a bogus comment.
const previewSvg = computed(() => svgDoc.value.replace(/<\?xml[\s\S]*?\?>\s*/, ""));

const cellCount = computed(
  () => `${Math.max(0, Math.round(params.row))} × ${Math.max(0, Math.round(params.column))} cells`,
);

interface Field {
  key: keyof Params;
  label: string;
  step: number;
  min?: number;
  unit?: string;
}

const fields: Field[] = [
  { key: "row", label: "Rows", step: 1, min: 0 },
  { key: "column", label: "Columns", step: 1, min: 0 },
  { key: "diameter", label: "Diameter", step: 0.1, min: 0, unit: "mm" },
  { key: "distance", label: "Distance", step: 0.1, min: 0, unit: "mm" },
  { key: "ruler", label: "Ruler step", step: 0.1, min: 0, unit: "mm" },
  { key: "width", label: "Width", step: 0.1, min: 0, unit: "mm" },
  { key: "height", label: "Height", step: 0.1, min: 0, unit: "mm" },
  { key: "left", label: "Left", step: 0.1, unit: "mm" },
  { key: "top", label: "Top", step: 0.1, unit: "mm" },
];

// Native Save-As in the shell (window.zero present), Blob fallback in a plain
// browser so the UI is testable without the native shell.
async function download() {
  const out = svgDoc.value;
  const zero = window.zero;
  if (zero) {
    const path = await zero.invoke("native-sdk.dialog.saveFile", {
      title: "Save SVG",
      defaultName: "grid.svg",
    });
    if (path) {
      await zero.invoke("app.writeSvg", { path, content: out });
    }
  } else {
    const url = URL.createObjectURL(new Blob([out], { type: "image/svg+xml" }));
    const a = document.createElement("a");
    a.href = url;
    a.download = "grid.svg";
    a.click();
    URL.revokeObjectURL(url);
  }
}

function reset() {
  Object.assign(params, defaultParams);
}
</script>

<template>
  <main class="min-h-screen w-full bg-base-200 p-6 flex justify-center items-start">
    <div class="card bg-base-100 shadow-xl w-full max-w-3xl">
      <div class="card-body gap-6">
        <div class="flex items-start justify-between gap-4">
          <div>
            <h1 class="text-2xl font-bold">Piastra Print</h1>
            <p class="text-base-content/60">Grid generator — edit the parameters and preview the output.</p>
          </div>
          <button class="btn btn-ghost btn-sm" @click="reset">Reset</button>
        </div>

        <div class="grid grid-cols-2 sm:grid-cols-3 gap-4">
          <label v-for="f in fields" :key="f.key" class="form-control">
            <span class="label label-text justify-between mb-1">
              <span>{{ f.label }}</span>
              <span v-if="f.unit" class="text-xs opacity-50">{{ f.unit }}</span>
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

        <div>
          <div class="flex items-center justify-between mb-2">
            <span class="text-sm font-semibold">Live preview</span>
            <span class="text-xs text-base-content/50">{{ cellCount }}</span>
          </div>
          <div
            class="preview border border-base-300 rounded-box flex items-center justify-center overflow-hidden p-3"
            style="background: #fff; height: 320px"
            v-html="previewSvg"
          ></div>
          <p class="text-xs text-base-content/40 mt-1">
            Preview scales to fit; the downloaded file keeps the real mm dimensions.
          </p>
        </div>

        <div class="card-actions justify-end">
          <button class="btn btn-primary" @click="download">Download SVG</button>
        </div>
      </div>
    </div>
  </main>
</template>
