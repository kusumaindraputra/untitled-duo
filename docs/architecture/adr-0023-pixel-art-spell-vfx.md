# ADR-0023: Pixel-Art Spell VFX

## Status

Accepted

## Date

2026-09-25

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

Fayde's spell effects are now drawn on the same pixel grid as the pixel-art
sprites from ADR-0022. Before this change they were antialiased vector strokes
(`draw_arc`, `draw_line`, `draw_circle`), which looked smooth and thin next to the
blocky sprites. The shapes, timings and colours of every effect stay the same.
Only the way they are rasterised changes.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Rendering (2D) / VFX |
| **Knowledge Risk** | LOW: only `CanvasItem.draw_rect` and `Node2D.global_position`, both unchanged since 4.0 |

## Context

- The sprites use 1 art pixel = 1 world unit, and the camera shows them at 2× zoom.
- The spell VFX (`src/ui/spell_vfx.gd`), the cast beam (`debug_circle_2d.gd`),
  Fayde's hurtbox dot and dash dust, and the enemy death burst were vector strokes.
  At 2× zoom those strokes render at screen resolution, so they looked sharper and
  finer than the sprites around them.
- Hand-painting sprite sheets for every effect would mean about 30 sheets, and
  every change to a cone angle or a range in data would need the art redone.

## Decision

Add `PixelVFX` (`src/visual/pixel_vfx.gd`), a set of static raster helpers that
the existing `_draw()` code calls instead of the vector draw calls:

- Shapes (lines, polylines, arcs, rings, discs, convex polygons) become 1×1 cells.
  The cells are aligned to the world integer grid through `snap_origin()`, so
  effects do not shimmer as they move.
- Cells are merged into horizontal runs, so each run costs one `draw_rect`.
- Alpha is quantised into flat steps: 4 steps for strokes, 8 for large fills.
  This replaces the smooth fades.
- Each Prana colour becomes a 3-tone ramp (dark, base, light). Strokes 3 px or
  wider get a light core.
- The range cone is a scanline fill (every other row) plus a 1 px edge.

## Alternatives Considered

1. **Hand-authored sprite sheets per effect.** Rejected: too many sheets, and
   every data change to ranges or cone angles would require new art.
2. **Render all VFX into a low-resolution SubViewport and upscale it.** Rejected:
   the effects are world-space nodes parented to the root, and moving them into a
   second viewport with a mirrored camera adds wiring for little gain.
3. **Pixelate with a CanvasGroup shader.** Rejected: CanvasGroup support in the
   Compatibility renderer was not verified, and a shader cannot quantise colours
   per shape.

## Consequences

- The effects match the sprite pixel size, and effect tuning stays in data and code.
- Every `_draw()` call does a small amount of CPU rasterisation. The largest
  shape, the 90 px Cascade burst, is about 180 runs per frame.
- `tests/unit/pixel-vfx/pixel_vfx_test.gd` covers the raster maths. It also guards
  `spell_vfx.gd` and `debug_circle_2d.gd` against vector draw calls coming back.
- Still vector for now (not Fayde's effects): enemy projectiles, enemy telegraph
  rings, and hazards.
