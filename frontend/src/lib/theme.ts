// Light/dark theme: a persisted choice defaulting to the OS preference.
// The daisyUI theme is driven by the `data-theme` attribute on <html>.

export type Theme = "light" | "dark";

const STORAGE_KEY = "piastra-print.theme";

function resolveTheme(): Theme {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored === "light" || stored === "dark") return stored;
  } catch {
    // Storage unavailable — fall through to the system preference.
  }
  return window.matchMedia?.("(prefers-color-scheme: dark)")?.matches ? "dark" : "light";
}

// Apply the saved/system theme to <html> before first paint; returns it so the
// caller can seed its reactive state.
export function initTheme(): Theme {
  const theme = resolveTheme();
  document.documentElement.dataset.theme = theme;
  return theme;
}

// Apply a theme and persist it.
export function setTheme(theme: Theme): void {
  document.documentElement.dataset.theme = theme;
  try {
    localStorage.setItem(STORAGE_KEY, theme);
  } catch {
    // Best-effort persistence.
  }
}
