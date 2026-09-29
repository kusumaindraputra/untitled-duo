# ADR-0056: Cast Styles per Prana (both brothers)

## Status

Accepted

## Date

2026-09-27

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

The duo now moves differently for each Prana. The Prana in the centre slot picks one
of five cast poses: an Ashfire fire dance (a chambered stance, a palm strike from a
lunge, a spin, then a sweeping kick, in the spirit of firebending in *Avatar: The
Last Airbender*), a Voidblue reach and pull, a Stormgold two-finger snap, a
Deepfrost horse-stance push, and a Verdant bloom.

This is the first step of the "two hands" identity direction chosen on 2026-09-27.
Combination Resolution already gave each Prana a fighting style (Ashfire is the
melee dance combo, `combination-resolution.md` Type 0). `PranaType.cast_animation`
existed in every Prana `.tres` but no code read it, so every Prana played the same
cast row with only the flash colour changed.

## Decision

- `tools/art-gen/generate_character_sprites.gd` writes a new sheet,
  `assets/art/characters/fayde_casts.png` (+ `_glow`). It has one row per
  `GameEnums.CastAnimation` value, in enum order, and four columns (wind-up,
  release, follow-through, recover). Cells are 20×32, the same size as the main
  sheet. Poses are data in `_STYLE_POSES`: lean, crouch, stance, the two hand
  positions and a mirror flag (the Ashfire spin). The glow sheet adds one small
  element mark per style, such as a flame off the palm or a spark off the
  fingertips, which the game tints with the Prana colour. The main `fayde.png` is
  unchanged.
- `PixelCharacter` gets optional `cast_sheet` / `cast_glow_sheet` exports and
  `play_cast(duration, style = -1)`. While a styled cast plays, both sprites swap
  to the cast sheet (`vframes = CAST_STYLES`, and the shader's `sheet_rows` is kept
  in step for the dissolve), then swap back when it ends. With no cast sheet, or
  with style -1 or an out-of-range style, the plain cast row plays, so enemies and
  bosses are untouched.
- `SpellVFX._on_cast_started` passes `PranaType.cast_animation` for the spell's
  primary type. `PlayerController.tscn` wires both sheets.
- Timing is unchanged: `CharacterFxTuning.fayde_cast_sec` (0.32 s) for every style.

## Alternatives Considered

- **Grow the main sheet to 8 rows.** Rejected: every enemy sheet and test assumes
  3 rows, and the dash ghost and dissolve shader read the row count.
- **Hand-drawn frames.** Better motion, but there is no artist before the beta, and
  the procedural generator keeps the whole cast in one reproducible pipeline.
- **Per-style durations.** Deferred: a longer Ashfire dance should match
  `ASHFIRE_CAST_LOCK_DURATION`. That is a feel pass after playtest, not part of this
  change.

## Consequences

- Each Prana reads as its own fighting style, which ties the grid to the active brother's body
  and to the Ayden (power) / Faith (control) story.
- At 20×32 the poses are small. The hands, glow and stance carry the read more than
  the arms do. A later pass can add frames or longer holds.
- New Prana types must add a `CastAnimation` value and a row to `_STYLE_POSES`.
  `cast_styles_test.gd` fails when a Prana maps outside the sheet or when two
  styles share a release pose.

## Evidence

`production/qa/evidence/adr0056-cast-styles-ingame.png` (in combat, one row per
Prana, four columns) and `adr0056-cast-styles-sheet.png` (the generated sheet).
