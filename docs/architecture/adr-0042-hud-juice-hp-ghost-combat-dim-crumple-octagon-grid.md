# ADR-0042: HUD and Screen Juice — HP Ghost Chunk, Combat Dim, Crumple Pose, Octagonal Grid

## Status

Accepted

## Date

2026-09-27

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

Items 3 and 8 of the juice review, plus the three gaps ADR-0039 logged for later:

1. **HP bar ghost chunk and jolt** (`CombatHUD`): a hit leaves a bone-white chunk
   where the lost HP was. It holds, then drains to the real HP. The HP row also
   jolts a few pixels, sized by the hit.
2. **Prep→combat dim** (art bible §2.3): the room's ambient drops 18 % over 0.3 s at
   wave start and lifts again when the wave or room is over.
3. **Crumple pose** (art bible §5.3 stage 1): when the duo falls, her sprite gives way
   to a new crumple strip (knees bend, arms loose, head down, eyes close). The
   defeat screen shows the same pose beside the stats, drained of warmth, with the
   last Prana colour still in her hands (§2.5).
4. **Octagonal grid, circular slots** (art bible §3.4): the 3×3 Prana grid sits in an
   octagonal frame with four Prana-fragment ornaments, and each slot is a circle.

All timings live in `assets/data/hud_juice_tuning.tres` (`HudJuiceTuning`).

## Decision

### HP ghost chunk and jolt

- A second `ProgressBar` (`_ghost_bar`) sits under `hp_bar`. It owns the track
  background and draws its fill in `ghost_color`; `hp_bar` now has an empty
  background, so the real fill covers the ghost except for the lost chunk.
- On damage the ghost keeps its current top edge (`max(ghost, value before the
  hit)`) and restarts a `ghost_hold_sec` hold. A burst of hits reads as one growing
  chunk that drains once, over `ghost_drain_sec` with an ease-out, after the burst.
- A heal lifts the ghost with the fill: the chunk only ever means "lost".
- The jolt is a deterministic decaying offset (`CombatHUD.jolt_offset`, no
  randomness) on the bar, ghost and number together. Its peak is `jolt_px`, scaled by
  damage between half and full size (`jolt_amplitude`). It is off with Reduce motion.
- Both run in `_process` as float accumulators (ADR-0004), like the existing drain.
- The DESPERATE scale pulse also scales the ghost, so they never separate.

### Combat dim

- `IsometricRoom.set_combat_dim(amount, seconds)` tweens the floor
  `TileMapLayer.self_modulate`, the `PlatformEdge` and `RoomDecor` modulate, and the
  backdrop void rect. The boss ambience (ADR-0039) drives the tile map's `modulate`,
  so the two stack instead of fighting.
- Characters, spells, hazards, doors, cover pillars and rubble keep full brightness.
  Everything the player has to read in a fight stays as legible as in prep, and
  "spell bursts own the brightness budget" (§2.3) holds.
- The game loop connects `combat_started` to the dim and `wave_ended` /
  `room_cleared` to the lift (`dim_out_sec`).

### Crumple pose

- `tools/art-gen/generate_character_sprites.gd` now also writes
  `fayde_crumple.png` and `fayde_crumple_glow.png`: one row of 4 columns in the duo's
  20×32 cell, feet on the origin. The main `fayde.png` sheet is unchanged, so
  `PixelCharacter` (owned by the squash/stretch work, ADR-0040) is not touched.
- `CrumplePose` (`src/visual/crumple_pose.gd`) plays the strip once over
  `crumple_sec` in real time (it must play during the 0.15× death slow-mo) and holds
  the last column. Its glow sheet takes the last Prana colour.
- On a loss the game loop hides the duo's `PixelCharacter` and adds a `CrumplePose`
  under the player at the same pixel scale and facing. A restart rebuilds the scene.
- `RunSummaryPanel` shows a `CrumplePose` at `crumple_portrait_scale` beside the stat
  cards on a loss only, tinted cool (`CRUMPLE_TINT`) with the Prana glow from the new
  `prana_color` data key. With Reduce motion it starts on the held frame.

### Octagonal grid and circular slots

- `PranaGridFrame` (a `MarginContainer`) draws the octagon: E6 haze fill, E7 edge,
  corners cut by 20 % of the shorter side, and four muted Prana diamonds on the
  diagonal edges. The grid is its only child, so layout and focus are unchanged.
- `PranaGridSlot` draws a circle in `_draw()` (fill, then a 2 px E7 rim that turns
  `ACCENT` on hover) instead of a full-rect `ColorRect`. The Panel box stays as the
  hit area, so drag-and-drop, clicks and the gamepad cursor work exactly as before.
- The gamepad cursor's border is rounded into a ring around the slot.

## Alternatives Considered

- **Ghost via a Tween**: the HUD's HP animation already uses float accumulators
  (ADR-0004) so tests can drive time by hand. A Tween would break that. Rejected.
- **Ghost as a child of `hp_bar`**: `hp_bar.modulate` carries the zone colour and
  would tint the ghost red. A sibling bar avoids that. Chosen.
- **`CanvasModulate` for the combat dim**: it darkens the duo and spells too, which
  §2.3 and ADR-0039 rule out. Rejected.
- **A fourth row on `fayde.png`**: this changes `PixelCharacter.ROWS`, and that file
  belongs to the squash/stretch thread. A separate strip needs no change there.
- **Circular hit areas**: this would make corners of each cell dead to the mouse. The
  square hit area is more forgiving and keeps ADR-0013 intact.

## Consequences

- New damage paths get the ghost and jolt for free through `damage_taken`.
- Anything else that tints the floor should use `modulate`; `self_modulate` on the
  tile map belongs to the combat dim.
- A room-clear warm wash (§2.4) can sit on top of the lift; the dim lifts on
  `room_cleared` without knowing about it.
- The prep panel is about 24 px taller because of the frame padding.

## Validation

- `tests/unit/hud-juice/hud_juice_test.gd` (16 tests): ghost hold, drain, bursts,
  heals and reset; jolt maths, settling and Reduce motion; dim tuning against §2.3 and
  the room dim leaving the boss ambience alone; crumple frames, glow and the defeat
  screen on a loss only; octagon points, ornaments, slot circles and corner-slot
  clearance.
- Screenshots: `production/qa/evidence/adr0042-*.png` (copies in the project
  `juice/` folder).
