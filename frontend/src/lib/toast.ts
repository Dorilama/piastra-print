// Toast notifications: a fixed-position stack (no layout shift). Each toast
// auto-dismisses after a short delay, pauses while the user hovers it (so they
// can keep reading), and can be closed manually.

import { reactive } from "vue";

export type ToastType = "info" | "success" | "warning" | "error";

export interface Toast {
  id: number;
  type: ToastType;
  message: string;
}

const DURATION_MS = 4000;

export const toasts = reactive<Toast[]>([]);

// Per-toast timer state. deadline = when it should auto-dismiss; handle = the
// active timeout id (0 while paused). Number keys, runtime insert/delete -> Map.
const timers = new Map<number, { deadline: number; handle: number }>();

export function dismiss(id: number): void {
  const entry = timers.get(id);
  if (entry) {
    clearTimeout(entry.handle);
    timers.delete(id);
  }
  const index = toasts.findIndex((t) => t.id === id);
  if (index >= 0) toasts.splice(index, 1);
}

function arm(id: number): void {
  timers.set(id, {
    deadline: Date.now() + DURATION_MS,
    handle: setTimeout(() => dismiss(id), DURATION_MS) as unknown as number,
  });
}

// Pause the auto-dismiss (e.g. on hover) — keeps the toast visible.
export function pause(id: number): void {
  const entry = timers.get(id);
  if (entry) {
    clearTimeout(entry.handle);
    entry.handle = 0;
  }
}

// Resume from where the timer left off.
export function resume(id: number): void {
  const entry = timers.get(id);
  if (!entry) return;
  const remaining = entry.deadline - Date.now();
  if (remaining <= 0) {
    dismiss(id);
  } else {
    entry.handle = setTimeout(() => dismiss(id), remaining) as unknown as number;
  }
}

let nextId = 1;
export function toast(message: string, type: ToastType = "info"): number {
  const id = nextId++;
  toasts.push({ id, type, message });
  arm(id);
  return id;
}
