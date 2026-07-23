<script setup lang="ts">
import { toasts, dismiss, pause, resume } from "../lib/toast.js";
</script>

<template>
  <!-- Fixed LED status stack — overlays without shifting layout. -->
  <div class="fp-toasts" role="status" aria-live="polite">
    <div
      v-for="t in toasts"
      :key="t.id"
      class="fp-toast"
      :data-type="t.type"
      @mouseenter="pause(t.id)"
      @mouseleave="resume(t.id)"
    >
      <span class="fp-toast-led" aria-hidden="true"></span>
      <span class="fp-toast-msg">{{ t.message }}</span>
      <button
        class="fp-toast-close"
        aria-label="Dismiss notification"
        @click="dismiss(t.id)"
      >
        <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    </div>
  </div>
</template>
