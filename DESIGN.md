---
name: Piastra Print
description: Cassette-futurist instrument fascia — a tape-deck control surface for a precision SVG grid generator.
colors:
  aluminum-panel: "#cfd2d7"
  aluminum-deep: "#b6bac1"
  aluminum-raised: "#dee1e5"
  chassis-beige: "#cdc3ae"
  chassis-deep: "#aaa088"
  engraved-ink: "#23241f"
  engraved-ink-soft: "#44453f"
  display-face: "#f3efe4"
  display-bezel: "#16150f"
  led-amber: "#ffae3a"
  led-amber-dim: "#7a5418"
  chrome-light: "#f2f4f7"
  chrome-mid: "#c6cad1"
  chrome-dark: "#969ba3"
  chrome-ink: "#1f201b"
typography:
  display:
    fontFamily: "Chakra Petch, system-ui, sans-serif"
    fontWeight: 600
    letterSpacing: "0.06em"
  body:
    fontFamily: "Chakra Petch, system-ui, sans-serif"
    fontWeight: 400
    lineHeight: 1.45
  readout:
    fontFamily: "'Share Tech Mono', ui-monospace, monospace"
    fontWeight: 400
    letterSpacing: "0.02em"
rounded:
  xs: "2px"
  sm: "4px"
  md: "6px"
  pill: "999px"
spacing:
  grid: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
components:
  panel:
    backgroundColor: "{colors.aluminum-panel}"
    textColor: "{colors.engraved-ink}"
    rounded: "{rounded.sm}"
    padding: "{spacing.md} {spacing.lg}"
  readout:
    backgroundColor: "{colors.display-bezel}"
    textColor: "{colors.led-amber}"
    typography: "{typography.readout}"
    rounded: "{rounded.xs}"
  action-button:
    backgroundColor: "{colors.chrome-light}"
    textColor: "{colors.chrome-ink}"
    rounded: "{rounded.sm}"
    padding: "{spacing.md} {spacing.xl}"
---

# Design System: Piastra Print

## Overview

**Creative North Star: "The Amber Deck"**

Piastra Print is dressed as a single cassette-era instrument fascia — the kind of brushed-aluminum tape deck or rack-mount measurement unit a maker would trust on the bench. The whole window is one bolted-together device: a beige chassis holds an aluminum control deck and a backlit LCD that shows the live grid. Amber LEDs are the only signal; chrome switches are the only controls; engraved black caps are the only labels. The product's own geometry — the border, the radial ruler ticks, the crosshair through every center — reads as the instrument's native scale, so what you tune and what you print share one grammar.

This is a redesign that rejects the incumbent daisyUI card stack (neutral rounded cards, generic accordions, a floating preview) as the category rut. Density and legibility outrank expression because the visitor came to operate: scan a value, change a number, read the meter, hit the button, leave. Personality lives entirely in the material fidelity — the brushed grain, the inset bezels, the amber that glows only where a reading happens — never in decorative chrome laid over a flat tool.

The light/dark toggle is not "light app / dark app." It is the same device under two room conditions: a lit workbench (light: bright brushed silver, warm beige, black engraving) and a dim studio session (dark: gunmetal and taupe, lighter engraved ink, amber glowing harder against the dark). The backlit LCD and the amber readouts are constant in both.

**Key Characteristics:** brushed-aluminum ground; beige chassis framing; single amber signal reserved for measurement and the live state; chrome tactile controls; engraved uppercase labels; squared bolted panels with near-zero radius; one device, two room-lights.

## Colors

A restrained, material-led palette: two neutrals carry the surface (aluminum + beige), one signal (amber) is spent only on readouts and the active state, and engraved ink grounds all text. No second accent.

### Primary
- **Signal Amber** (`#ffae3a` light / `#ffb84d` dark): the sole accent. LED numeric readouts, the live "power" indicator, the active/pressed control state, and focus rings. It appears only where a measurement or a live state is communicated — never as decoration or a background fill.

### Neutral
- **Brushed Aluminum** (`#cfd2d7` / dark `#54585e`): the dominant ground. Panel faces, the control deck, control tracks. Carries a subtle anisotropic brushed grain.
- **Aluminum Deep** (`#b6bac1` / dark `#3c4045`): recessed channels, panel joins, milled slider tracks, inset seams.
- **Aluminum Raised** (`#dee1e5` / dark `#62666c`): raised faces, bezel rims, the high side of metal relief.
- **Chassis Beige** (`#cdc3ae` / dark `#5d5648`): the device body/surround and panel gaskets; frames the aluminum like a plastic case.
- **Chassis Deep** (`#aaa088` / dark `#463f33`): gasket lines and bolt recesses between panels.
- **Engraved Ink** (`#23241f` / dark `#e7e3d9`): all labels and body text, engraved into the metal. Soft variant `#44453f` / dark `#d3cfc3` for secondary text — tuned to clear 4.5:1 contrast on both aluminum and the recessed display bar in each theme; always a warm-tinted dark, never flat gray.
- **Display Face** (`#f3efe4` / dark `#ece8db`): the backlit LCD ivory behind the live preview; constant light in both themes because the display is always backlit.
- **Display Bezel** (`#16150f` / dark `#0d0c08`): the dark recessed frame around readouts and the preview window.
- **Chrome** (`#f2f4f7`→`#c6cad1`→`#969ba3` gradient; dark `#d6dade`→`#878d96`): switch thumbs, action buttons, knurled knobs — a metallic gradient, never a flat gray. Chrome labels use **Chrome Ink** (`#1f201b`), a constant dark in both room-lights, so engraved chrome text stays legible on the light metal face.

### Named Rules
**The One Signal Rule.** Amber is the only saturated color on the device. It appears on readout numerals, the live indicator, the active control state, and focus — collectively under 10% of any viewport. If a thing is not measuring or alive, it is not amber.

## Typography

**Display/Label Font:** Chakra Petch (fallback: system-ui condensed sans)
**Readout Font:** Share Tech Mono (fallback: ui-monospace)

**Character:** Chakra Petch is the engraved panel lettering — a squared, slightly technical grotesk that reads as silk-screened or engraved device labels in uppercase with open tracking. Share Tech Mono is reserved exclusively for measurement numerals on the LED/dot-matrix readouts, where its tabular, instrument-display character is earned by data, not borrowed as a "technical" costume.

### Hierarchy
- **Wordmark** (Chakra Petch 600, ~1.25rem, 0.06em, uppercase): "PIASTRA PRINT" on the brand plate.
- **Panel Label** (Chakra Petch 600, 0.7rem, 0.12em, uppercase): engraved zone labels (LAYOUT, CIRCLE, BORDER) on each bolted panel.
- **Field Label** (Chakra Petch 500, 0.72rem, 0.04em): the name above each control (Diameter, Distance…), often with an `mm` unit in the soft ink.
- **Readout** (Share Tech Mono 400, ~0.95rem, tabular): the amber numeric value in every input cell and meter count.
- **Caption** (Chakra Petch 400, 0.7rem, soft ink): the one-line helper under the display.

### Named Rules
**The Measurement-Only Rule.** Share Tech Mono is used only for numeric measurement values and counts. Labels, headings, and prose use Chakra Petch. Mono on a label is a costume; mono on a reading is the device.

## Layout

One device, not a page of cards. The window holds a beige chassis containing: a slim brand plate across the top (wordmark + power LED + chrome switches for theme and settings), then a two-region body — the **control deck** (bolted sub-panels for Layout, Circle, Border, and four hinged stroke-style compartments) beside the **display** (a large recessed LCD showing the live preview, a cell-count meter, and the prominent action button beneath it). At ≤880px the deck stacks above the display as bolted panels; nothing becomes a card.

Spacing is a 4px bolt-grid: tight groupings inside a panel (8–12px), generous gasket separation between panels (16–24px). More space sits above a panel label than below it. The default window is 720×480; the fascia is compact and dense-but-legible there and expands gracefully, with the display preview flexing to fill available height rather than holding a fixed box.

## Elevation & Depth

Depth is structural and material, not ambient glow. Real metal relief: raised faces carry a top highlight + bottom shade; recessed readouts and the display sit in dark insets with inner shadow; panels are bolted onto the chassis with thin chassis-deep seams. Every shadow has an offset and a soft blur; zero-offset colored halos are decoration and are banned.

### Shadow Vocabulary
- **Raised metal** (`0 1px 0 rgba(255,255,255,.5) inset, 0 -1px 0 rgba(0,0,0,.18) inset, 0 2px 4px rgba(20,18,12,.18)`): raised faces and bezel rims.
- **Recessed display** (`inset 0 2px 6px rgba(0,0,0,.55), inset 0 0 0 1px rgba(0,0,0,.4)`): the LCD window and readout cells.
- **Amber LED glow** (`0 0 6px rgba(255,174,58,.55)`): on active readout numerals and the live LED only — small, bound, never a page-wide bloom.
- **Pressed control** (`inset 0 2px 4px rgba(0,0,0,.4)`): active/pressed switches and buttons invert to recessed.

## Shapes

Squared, engineered form language. Panel radius is 4px (near-square, like a bolted plate); readout cells and the display use 2–6px with a dark inset; the only fully round forms are LED dots, the live power indicator, and the toggle thumb (pill). Color swatches are squared chips with a 1px chrome rim. No large radii, no pill cards, no nested rounded containers.

## Components

### Panels (bolted sub-panel)
- **Character:** an engraved aluminum plate bolted to the chassis.
- **Shape:** 4px radius, chassis-deep 1px seam, optional bolt dots at corners.
- **Label:** engraved uppercase panel label top-left in soft ink.

### Readout inputs (LED numeric)
- **Character:** a dark inset display cell with an amber tabular numeral — the control reads like a DRO.
- **Shape:** 2px radius, display-bezel fill, recessed shadow.
- **Value:** Share Tech Mono amber; placeholder in `led-amber-dim`.
- **Focus:** amber ring + brighter glow; caret amber.

### Chrome toggle (switch)
- **Character:** a snap-action switch for booleans (alternate colors, two-color ruler).
- **Shape:** pill track, chrome thumb; snaps with a quick ease.
- **State:** off = aluminum-deep track + aluminum thumb; on = amber-tinted track + chrome thumb lit at the amber side.

### Color slot
- **Character:** a labeled knob-like swatch + hex readout.
- **Shape:** squared 4px chip with chrome rim, paired with a mono hex field.

### Hinge panel (stroke-style compartment)
- **Character:** a fold-down compartment (replaces the accordion).
- **State:** closed = flush plate with engraved label + color dot + a hinge chevron; open = drops down like a cassette door revealing its readouts.

### Action button (primary)
- **Character:** the big chrome pushbutton — the "record/save" control.
- **Shape:** 4px radius, chrome gradient, engraved uppercase label, tactile press.
- **State:** rest chrome; hover slightly raised; active inverts to pressed + amber edge glow.

### Display (preview)
- **Character:** a recessed backlit LCD showing the live SVG.
- **Shape:** dark bezel frame + ivory display face; the SVG centered, scaled to fit.

### LED status (toasts)
- **Character:** a small amber/green/red LED status line, not a flat alert card.

### Settings (cassette door)
- **Character:** the settings tray hinges down like a cassette compartment door over the fascia.

## Do's and Don'ts

### Do:
- **Do** render metal with real relief (highlight + shade + offset shadow) and brushed grain via CSS gradients — never flat fills where the material is the identity.
- **Do** spend amber only on readouts, the live indicator, the active state, and focus.
- **Do** keep numerals in Share Tech Mono on dark inset cells; keep all labels in uppercase Chakra Petch.
- **Do** make light/dark the same device under two room lights — swap the metal/chassis/ink, keep the backlit LCD and amber constant.

### Don't:
- **Don't** use a flat gray for secondary text — tint it warm (engraved-ink-soft).
- **Don't** put Share Tech Mono on labels or headings; it is for measurement only.
- **Don't** use large radii, pill cards, or nested cards — panels are squared bolted plates.
- **Don't** scatter hover glows; the single authored motion is the toggle snap and the hinge drop, both quick exponential eases.
- **Don't** render literal skeuomorphic calipers or cassette reels — the material is texture and grammar, not illustrated props.
