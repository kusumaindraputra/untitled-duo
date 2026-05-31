# Accessibility Requirements — The Last Cipher

> **Committed Tier**: Basic
> **Committed**: 2026-05-31
> **Owner**: Kusuma Putra
> **Applies to**: All MVP and First Playable scope screens and systems
> **Review trigger**: Re-evaluate at Vertical Slice gate — upgrade to Standard if audience feedback warrants it

---

## Tier Definition: Basic

The project commits to the following accessibility guarantees at MVP. Every screen,
overlay, and interactive system must meet these requirements before it can be marked
implementation-ready.

| Requirement | Description | MVP Target |
|-------------|-------------|------------|
| **Full keyboard navigation** | Every interactive element is reachable and activatable using keyboard alone (no mouse required). Tab order and arrow key navigation are defined for all menus and overlays. | All MVP screens |
| **No color-only state indicators** | No game state, status, or interactive affordance is communicated by color difference alone. A non-color signal (shape, icon, label, position, or scale) always accompanies any color-based indicator. | All MVP systems |
| **Minimum text legibility** | All player-facing text renders at ≥16px at 1080p reference resolution. Text must remain legible at 1280×720 (minimum supported resolution). | All MVP screens |
| **Colorblind-safe Prana type identity** | Each Prana type is identified by color AND icon/symbol. The 5-type color set (Ashfire, Voidblue, Stormgold, Deepfrost, Verdant) passes the colorblind pair risk assessment in Art Bible §4.5. No two types are indistinguishable under Deuteranopia, Protanopia, or Tritanopia simulation. | Prana Grid, HUD, all Prana-displaying systems |
| **Input interception on overlays** | Modal overlays (Pause Menu, confirmation dialogs) intercept all input while visible. The game world does not receive input events while a modal is open. | Pause Menu; any future modal |
| **Gamepad navigation (partial)** | All full-screen menus (Main Menu, Pause Menu, Run Summary) are navigable via d-pad and face buttons. The Prana Grid has a gamepad alternative to drag-and-drop (per ADR-0013). | All MVP screens with gamepad partial support |
| **Focus state — non-color** | Focused interactive elements indicate focus via a non-color signal (border, scale, underline, or icon) in addition to any color change. | All MVP interactive elements |

---

## Deferred to Vertical Slice

The following are out of scope for MVP but must be designed for at VS if the project
targets broader distribution.

| Feature | Reason deferred |
|---------|----------------|
| Text scaling (font size adjustment) | Requires UI layout re-testing at multiple sizes; significant engineering scope |
| Key / button remapping | Requires Input Map GDD and remapping system; scope exceeds solo dev MVP budget |
| Screen shake / motion intensity toggle | Visual polish feature; no screen shake at MVP scope |
| Subtitle / caption architecture | No voiced dialogue or time-critical audio cues at MVP |
| Screen reader (NVDA / JAWS / OS TTS) | Godot 4.5+ AccessKit integration; HIGH scope; deferred to VS or post-ship |
| High-contrast mode | Requires alternate palette; VS art scope |

---

## Per-Screen Compliance Checklist

Use this table during UX review and implementation story sign-off.

| Screen / System | Keyboard nav | No color-only | Min 16px text | Colorblind safe | Input intercept | Gamepad nav |
|----------------|:---:|:---:|:---:|:---:|:---:|:---:|
| Main Menu | ✅ (IP-10/IP-11) | ✅ | ✅ | N/A | N/A | ✅ |
| Combat HUD | ✅ (demand-only) | ⚠️ verify at implementation | ✅ | ✅ (Art Bible §4.5) | N/A | N/A (display only) |
| Prana Grid | ✅ (IP-07) | ✅ | ✅ | ✅ (Art Bible §4.5 + icon system) | N/A | ✅ (ADR-0013) |
| Pause Menu | ✅ (IP-10/IP-11) | ✅ | ✅ | N/A | ✅ (MOUSE_FILTER_STOP) | ✅ |
| Run Summary | ⚠️ spec pending | ⚠️ spec pending | ⚠️ spec pending | ⚠️ spec pending | N/A | ⚠️ spec pending |
| Death Screen | ⚠️ spec pending | ⚠️ spec pending | ⚠️ spec pending | ⚠️ spec pending | N/A | ⚠️ spec pending |

Legend: ✅ committed in spec | ⚠️ to be addressed in spec | N/A not applicable

---

## Implementation Notes

### Keyboard Navigation
- All menus must define Tab order explicitly in their UX spec's Interaction Map
- Focus must be set programmatically on overlay appear (not left to Godot's default)
- "Focus trap" required in modal overlays: Tab must cycle within the modal only, not escape to underlying content
- Escape / Back always dismisses the current layer (or confirms cancel in destructive flows)

### Color-Only State
- Prana type identity: color + 8×8 pixel icon (mandatory per Art Bible §4.5)
- HP bar: color (green→amber→red) + numeric readout or icon — verify at implementation
- Status effects: color + icon/shape signal required (no color-only status indicators)
- Enemy affiliation indicators: color + Prana icon (per Enemy Data GDD)

### Text Legibility
- Reference resolution: 1920×1080 → minimum 16px
- Minimum supported resolution: 1280×720 → text must still be legible (do not rely on pixel-perfect 1080p layout)
- Warning text in Pause Menu confirmation dialog: `autowrap = true` required; card height grows with content (flagged HIGH risk for localization expansion — see `design/ux/pause-menu.md`)

### Colorblind Safety
- Full palette and pair-risk assessment: Art Bible §4.5
- Required test before ship: simulate Deuteranopia, Protanopia, Tritanopia on a screenshot with all 5 Prana types visible simultaneously
- Corruption Violet (#9B2ED4, boss reserved): verify does not conflict with Voidblue (#4A5EF5) under any simulation

---

## How to Verify

| Check | Method |
|-------|--------|
| Keyboard-only navigation | Play through every screen without touching the mouse |
| No color-only information | Screenshot each key state; desaturate to grayscale; verify all states are distinguishable |
| Minimum text legibility | Run at 1280×720; screenshot; confirm all text readable without zooming |
| Colorblind safety | Run through Coblis or Godot's built-in accessibility debugging filter (if available in 4.6) |
| Input interception | With Pause Menu open, verify keyboard input does not reach game world |
| Gamepad navigation | Play all menus with keyboard disconnected |

---

## Revision History

| Date | Change |
|------|--------|
| 2026-05-31 | Initial commit — Basic tier defined; per-screen compliance table seeded from existing specs |
