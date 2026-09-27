# ADR-0047: Colour-Blind Prana Palettes

## Status

Accepted

## Date

2026-09-27

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

Settings → Comfort gains a **Prana colours** choice: Default, Deuteranopia,
Protanopia or Tritanopia. Picking a mode swaps the five Prana colours everywhere
(grid slots, bag tokens, core and sigil cards, spell VFX, hit tints, HUD combo
counter, title glow) for a palette tuned to that colour-vision deficiency. The shape
icons from ADR-0036 stay as they are, so colour is never the only cue.

- `PranaPalette` (`src/data/prana_palette.gd`) holds `colors: Array[Color]` in
  catalog id order. One file per mode lives in `assets/data/prana_palettes/`.
- `GameSettings.color_mode` (enum `ColorMode`, default `OFF`) is saved as
  `game/color_mode` in `user://settings.cfg`. `prana_palette()` loads the file from
  `PRANA_PALETTES`, or returns null for `OFF`.
- `PranaCatalog.set_palette()` swaps the colour served by `get_type_color()`,
  `get_type()` and `get_all_types()`, and emits `palette_changed`. The catalog reads
  the saved mode once in `_ready()`; the Settings panel calls `set_palette()` on
  change.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | UI / Data |
| **Knowledge Risk** | LOW: typed `Array[Color]` exports and `Dictionary[int, String]` constants (4.4+) are already used in the project; `Color.srgb_to_linear()` is unchanged. |

## Context

The five Prana colours (Ashfire orange-red, Voidblue, Stormgold, Deepfrost cyan,
Verdant green) follow the art bible. Simulated with the Machado et al. (2009) model
at full severity, the closest pair drops to CIE76 ΔE 23 (Ashfire/Verdant) for
deuteranopia, 26 (Stormgold/Verdant) for protanopia and 15 (Deepfrost/Verdant) for
tritanopia. The icons help on the grid, but spell VFX, hit tints and the combo
counter are colour only.

## Decision

### Swap colours at the catalog (chosen over a screen-space filter)

Every Prana colour already flows through `PranaCatalog`: `get_type_color()` for UI
and `get_type().color` for VFX. Overriding it there reaches every consumer with one
change and keeps enemy bullets (ADR-0037), boss tints and UI chrome untouched. A
full-screen daltonisation shader would shift those too, and could pull the hostile
magenta rim toward a Prana hue.

### One palette per deficiency (chosen over one shared "safe" palette)

A single palette that works for all three types keeps the closest pair near ΔE 25.
Tuning per mode lets each reach ΔE 45 or more. The palettes were found by searching
inside each element's hue family (fire stays red-orange, lightning yellow, ice
cyan, nature green, shadow blue or violet) for the largest minimum distance under
that deficiency, while also staying apart in normal vision and from the bullet rim.

| Mode | Ashfire | Voidblue | Stormgold | Deepfrost | Verdant | Closest pair ΔE (default → mode) |
|------|---------|----------|-----------|-----------|---------|------|
| Deuteranopia | `#D22A14` | `#2233F0` | `#F5F010` | `#55C4FA` | `#10F5A0` | 23 → 47 |
| Protanopia | `#CD3018` | `#1E3EDC` | `#FFF520` | `#80E6FE` | `#10F5A8` | 26 → 49 |
| Tritanopia | `#DF2410` | `#8A40F0` | `#F4DD28` | `#5AF8F8` | `#1E8A1E` | 15 → 45 |

Every palette colour stays at least ΔE 28 from the hostile rim `#FF339E` under its
own deficiency and at least ΔE 60 in normal vision, so enemy fire still reads as a
separate family.

### Default is off

Most players see the art-bible colours as designed. The mode is one row in Comfort,
next to high-contrast bullets.

## Alternatives Considered

- **Screen-space colour-blind filter.** Rejected: changes every colour on screen,
  including the enemy bullet family and boss tints, and costs a full-screen pass.
- **One shared palette for all modes.** Rejected: weaker separation for each type
  (see above).
- **Per-PranaType colour arrays.** Rejected: spreads each palette across five
  files; one file per mode is easier to tune and test.

## Consequences

- A new Prana type needs a colour in every palette file; the test checks the count.
- UI that caches Prana colours must listen to `PranaCatalog.palette_changed`.
  `PranaGrid` and `TitleGlow` do. Other screens read colours when they open.
- Boss bullet cores are not part of the rim check. The protanopia Voidblue and the
  Warped Warden violet core stay close (ΔE 9, the same as the default colours); the
  magenta rim still marks the Warden's bullets as hostile.

## Validation

`tests/unit/prana-palette/prana_palette_test.gd` simulates each deficiency and
checks: one colour per type, closest pair ΔE ≥ 40 and better than the default
colours, ΔE ≥ 25 from the bullet rim in normal and simulated vision, settings round
trip and clamping, and that the catalog serves and restores palette colours.
