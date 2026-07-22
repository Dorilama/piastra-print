<script setup>
import { ref, computed } from "vue";
import { generateSvg } from "./lib/svg.js";

const width = ref(400);
const height = ref(300);

const svg = computed(() => generateSvg(width.value, height.value));

const dimensions = computed(() => ({
  w: Math.max(1, Math.round(width.value)),
  h: Math.max(1, Math.round(height.value)),
}));

// Native Save-As in the shell (window.zero present), Blob fallback in a plain
// browser so the UI is testable without the native shell.
async function download() {
  const out = generateSvg(width.value, height.value);
  const zero = window.zero;
  if (zero) {
    const path = await zero.invoke("native-sdk.dialog.saveFile", {
      title: "Save SVG",
      defaultName: "piastra-print.svg",
    });
    if (path) {
      await zero.invoke("app.writeSvg", { path, content: out });
    }
  } else {
    const url = URL.createObjectURL(new Blob([out], { type: "image/svg+xml" }));
    const a = document.createElement("a");
    a.href = url;
    a.download = "piastra-print.svg";
    a.click();
    URL.revokeObjectURL(url);
  }
}
</script>

<template>
  <main class="min-h-screen w-full bg-base-200 p-6 flex justify-center items-start">
    <div class="card bg-base-100 shadow-xl w-full max-w-3xl">
      <div class="card-body gap-6">
        <div>
          <h1 class="text-2xl font-bold">Piastra Print</h1>
          <p class="text-base-content/60">Set dimensions and preview the generated SVG.</p>
        </div>

        <div class="grid grid-cols-2 gap-4">
          <label class="form-control">
            <span class="label label-text mb-1">Width</span>
            <input
              v-model.number="width"
              type="number"
              min="1"
              class="input input-bordered w-full"
            />
          </label>
          <label class="form-control">
            <span class="label label-text mb-1">Height</span>
            <input
              v-model.number="height"
              type="number"
              min="1"
              class="input input-bordered w-full"
            />
          </label>
        </div>

        <div>
          <div class="flex items-center justify-between mb-2">
            <span class="text-sm font-semibold">Live preview</span>
            <span class="text-xs text-base-content/50">
              {{ dimensions.w }} × {{ dimensions.h }}
            </span>
          </div>
          <div
            class="preview border border-base-300 rounded-box bg-base-100 flex items-center justify-center overflow-hidden"
            style="height: 280px"
            v-html="svg"
          ></div>
          <p class="text-xs text-base-content/40 mt-1">
            Preview scales to fit; the downloaded file keeps the real dimensions.
          </p>
        </div>

        <div class="card-actions justify-end">
          <button class="btn btn-primary" @click="download">Download SVG</button>
        </div>
      </div>
    </div>
  </main>
</template>
