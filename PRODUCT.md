# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

The app ships as a native desktop binary (Zig + Native SDK, cross-platform macOS/Linux/Windows), but the interface is authored in web technologies (Vue 3 / Tailwind / daisyUI) and rendered by the system WebView. Its design language is web, not mobile-native; treat it as a desktop web surface (system window chrome, keyboard/mouse, not touch-first).

## Users

A single primary user (personal tool) who needs a precise, printable paper guide: a sheet marked with a regular grid of circles, printed at exact 1:1 scale, laid on or under a workpiece as a physical alignment/drilling reference. The job is "I need an accurate grid on paper, now" — not documenting, not presenting, not modeling in 3D.

## Product Purpose

Generate a dimensionally-exact, ready-to-print SVG of a grid: a configurable number of rows and columns of circles, each with a crosshair through its center, ruler tick marks radiating from the center, and a bounding border — all measured in millimeters. The output is a single SVG file the user saves and prints at 100% scale to use as a physical guide. Success is a trustworthy, unscaled paper sheet in minutes.

## Positioning

Speed over CAD. The differentiator against Fusion/Inkscape/a spreadsheet is the time from intent to a print-ready file: open the app and a sensible grid is already there, tune a few numbers, save. No project setup, no document sizing, no export dialogues — the entire loop is seconds to a minute.

## Operating Context

- Run as a desktop window (720×480, resizable, restores state), opened on demand — typically for a one-off task, then closed.
- Units are millimeters throughout; the defaults (16.5 mm circle diameter, 19.3 mm pitch, ~127×85 mm border) reflect a typical small grid.
- Output is a single `.svg` file via the native Save-As dialog (`app.writeSvg` bridge), with a Blob-download fallback when run in a plain browser. The file is then printed by the user's OS print path at 100% scale.
- The last-used configuration is restored on relaunch (localStorage); parameters can be exported to and imported from JSON for reuse.
- A silent self-update mechanism checks an update server on launch and can swap the bundled web assets via an atomic overlay; manual check lives in Settings.

## Capabilities and Constraints

- **Geometry**: rows, columns, circle diameter, center-to-center distance, ruler tick step, border width/height, and left/top margins — all in mm, all live-editable.
- **Stroke styles**: per-group stroke thickness and color for border, circles, center crosshairs, and ruler; circles can alternate two colors in a checkerboard, and the ruler can use separate left/right colors.
- **Preview**: a live 1:1 preview that is the exact content of the exported SVG (no hidden transforms).
- **Config**: localStorage persistence with deep-merge tolerance for partial/older shapes; JSON import/export of the full parameter set; geometry and styles reset independently.
- **Theme**: light/dark, persisted, applied pre-paint.
- **Technical**: Vue 3 + Tailwind v4 + daisyUI 5 frontend; Zig + Native SDK native shell (`dev.native_sdk.piastra-print`); system WebView engine. Frontend entry `frontend/index.html`, dev server `http://127.0.0.1:5173/`.
- **Constraint**: output is SVG only — no raster export, no direct printing from the app (the user prints the saved file themselves). All geometry assumes a rectangular grid of equally-spaced circles.

## Brand Commitments

- Name: **Piastra Print** (display name, window title, and `<title>`). "Piastra" (plate/slab) signals the flat, physical-reference nature of the output.
- App icon: `assets/icon.png`.
- Version 0.2.1 as of this record.
- No confirmed voice, copy style, or visual identity beyond the name and icon.

## Evidence on Hand

- The codebase itself is the authoritative source: `frontend/src/lib/svg.ts` (the generator), `frontend/src/App.vue` (the full UI and interactions), `frontend/src/lib/config.ts` / `theme.ts` / `updater.ts`, and `src/main.zig` (native shell, SVG write, self-update bridge).
- `app.zon` carries the manifest truth (name, id, capabilities, window, frontend config).
- No external testimonials, metrics, users, or marketing assets exist — this is a personal tool. Future work must not fabricate any.

## Product Principles

1. **Precision is the whole product.** The printed sheet is useless if a single dimension is off; the generator must round and lay out faithfully in real millimeters, and printing must never silently scale.
2. **Open-to-output in seconds.** Every interaction is judged against beating CAD; sensible defaults and a live preview mean the user rarely configures more than two or three fields before saving.
3. **The preview is the contract.** What is on screen is exactly what gets written — no surprise transforms, no separate "export" rendering path.
4. **Immediate usefulness.** A first launch already shows a valid, printable grid; nothing has to be set up, named, or sized before the tool is useful.
