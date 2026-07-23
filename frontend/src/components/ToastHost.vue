<script setup lang="ts">
import { toasts, dismiss, pause, resume } from "../lib/toast.js";
import type { ToastType } from "../lib/toast.js";

const alertClass: Record<ToastType, string> = {
  info: "alert-info",
  success: "alert-success",
  warning: "alert-warning",
  error: "alert-error",
};
</script>

<template>
  <!-- daisyUI `toast` is position: fixed, so it overlays without shifting layout. -->
  <div class="toast toast-top toast-center z-[100]">
    <div
      v-for="t in toasts"
      :key="t.id"
      class="alert py-2 pr-2 shadow-lg"
      :class="alertClass[t.type]"
      @mouseenter="pause(t.id)"
      @mouseleave="resume(t.id)"
    >
      <span class="text-sm">{{ t.message }}</span>
      <button class="btn btn-ghost btn-xs btn-circle" aria-label="Dismiss notification" @click="dismiss(t.id)">
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    </div>
  </div>
</template>
