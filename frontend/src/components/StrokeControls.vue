<script setup lang="ts">
import type { StrokeStyle } from "../lib/svg.js";

// Two-way bound to a StrokeStyle group on the parent (params.border, etc.).
// Editing mutates the shared reactive object directly.
const model = defineModel<StrokeStyle>({ required: true });
</script>

<template>
  <div class="grid grid-cols-2 gap-3">
    <label class="fp-field">
      <span class="fp-field-label">
        <span>Thickness</span>
        <em>mm</em>
      </span>
      <input
        type="number"
        step="0.01"
        min="0"
        v-model.number="model.thickness"
        class="fp-readout"
      />
    </label>
    <label class="fp-field">
      <span class="fp-field-label"><span>Color</span></span>
      <div class="fp-slot">
        <input
          type="color"
          v-model="model.color"
          class="fp-swatch"
          aria-label="Stroke color"
        />
        <input
          type="text"
          v-model="model.color"
          class="fp-readout"
          aria-label="Stroke color hex"
        />
      </div>
    </label>
  </div>
</template>
