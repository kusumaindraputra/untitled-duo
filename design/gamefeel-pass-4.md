# Gamefeel Pass 4 — #6 Combo Window Visual Timer

## Overview

Visual ring around Fayde that depletes during the combo continuation window (2.0s),
showing the player when their chain will reset. Ring appears after each hit's cast-lock
expires, shrinks from 360°→0°, and resets on the next chain hit.

## Player Fantasy

The player feels the combo timer as a physical presence — a ring tightens around Fayde,
creating urgency and giving precise feedback on when the chain window expires. The Prana
color matches, reinforcing spell identity.

## Detailed Rules

1. When SC&E transitions from CAST_LOCKED → CHAINING, emit `combo_window_opened(duration: float)`
2. SpellVFX spawns `_ComboRing` procedural Node2D as child of root (top_level, world-space)
3. Ring draws a partial arc from full circle → nothing over `COMBO_CONTINUATION_WINDOW` (2.0s)
4. Color = current spell's Prana type color, alpha ~0.6
5. Ring freed on: `chain_index_changed(0, ...)` (expiry), `preparation_started`, `player_died`,
   or new `combo_window_opened` (next hit resets)
6. Guard: no ring during death cinematic

## Formulas

- Arc angle = (remaining_window / COMBO_CONTINUATION_WINDOW) * TAU
- Radius: 50px from Fayde center
- Line width: 3.5px
- Alpha: 0.6 × (remaining_ratio) + 0.15 (fades slightly as it depletes)

## Edge Cases

- Rapid hits: kill old ring, spawn new one
- Combo expiry: ring freed when chain_index_changed fires with 0
- Wave prep/death: ring freed on preparation_started/player_died
- Headless tests: _ComboRing self-frees when tree is null

## Dependencies

- `spell_casting_effects.gd` — new signal `combo_window_opened`
- `spell_vfx.gd` — new `_ComboRing` inner class + signal handler
- `PranaCatalog` — color lookup for ring

## Tuning Knobs

- `COMBO_WINDOW_DURATION` — same as SC&E's `COMBO_CONTINUATION_WINDOW` (2.0s)
- Ring radius: 50px (tweakable constant)
- Ring alpha: 0.6 peak, 0.15 min
- Ring width: 3.5px

## Acceptance Criteria

1. Ring appears around Fayde in world-space when combo chain is active
2. Ring arc shrinks proportionally to remaining window time
3. Ring color matches current spell's Prana type
4. Ring resets on each chain advance
5. Ring disappears on combo expiry, wave prep, or death
6. No orphan nodes in headless tests
7. All existing tests still green
