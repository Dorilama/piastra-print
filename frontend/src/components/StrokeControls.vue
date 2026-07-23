<script setup lang="ts">
import type { StrokeStyle } from "../lib/svg.js";

// Two-way bound to a StrokeStyle group on the parent (params.border, etc.).
// Editing mutates the shared reactive object directly.
const model = defineModel<StrokeStyle>({ required: true });
</script>

<template>
  <div class="grid grid-cols-2 gap-3">
    <label class="form-control">
      <span class="label-text text-xs mb-1 block">
        Thickness <span class="opacity-50">mm</span>
      </span>
      <input
        type="number"
        step="0.01"
        min="0"
        v-model.number="model.thickness"
        class="input input-bordered input-sm w-full"
      />
    </label>
    <label class="form-control">
      <span class="label-text text-xs mb-1 block">Color</span>
      <div class="flex gap-1 items-center">
        <input
          type="color"
          v-model="model.color"
          class="w-9 h-8 shrink-0 rounded cursor-pointer border border-base-300 bg-base-100"
        />
        <input
          type="text"
          v-model="model.color"
          class="input input-bordered input-sm w-24 font-mono text-xs uppercase"
        />
      </div>
    </label>
  </div>
</template>
