---
version: 1
slug: "frontend-src-app-vue"
primary_target: "frontend/src/App.vue"
related_targets: ["frontend/src/components/StrokeControls.vue","frontend/src/components/ToastHost.vue"]
---

# Surface brief — main window (frontend/src/App.vue)

## Scope & mode
The application's single window. **Operate** — the visitor completes the task of producing a printable SVG grid. Not Persuade; this is a tool surface.

## Audience, job, action
- **Audience:** a single maker (personal tool) at their workbench.
- **Job:** get a dimensionally-exact paper guide — open, glance, change one or two numbers, save, print at 1:1.
- **Action:** tune geometry + per-group stroke styles, read the live preview, download the SVG (native Save-As or browser blob).
- **Proof:** the live preview IS the output (1:1, real mm); the cell count reads as a meter.
- **Constraints:** preserve every function — params model, preview, download, config persistence + import/export, light/dark toggle, silent + manual self-update, toasts. Default window 720×480; must be compact and legible there.

## Chosen direction
**The Amber Deck** — a cassette-futurist instrument fascia. One beige chassis holding an aluminum control deck and a backlit LCD preview; amber LED readouts, chrome switches, engraved labels. See DESIGN.md.

## Memorable moment
The control reads like a digital readout: dark inset cells with glowing amber tabular numerals, and the live preview glowing in a recessed bezel like a backlit LCD — the geometry you tune is the scale the device displays.

## Unresolved
- Exact aluminum/beige ramps and amber brightness settle during the build and are re-recorded.
- No in-app printing remains (SVG download only) — out of scope.
