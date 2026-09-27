# ADR-0043: Spawn Glyph and Floor Lighting

## Status

Accepted

## Date

2026-09-27

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

Two items from the juice review:

1. **Enemy spawn glyph (item 5).** Enemies used to pop in with a scale tween and a
   sound. Now a rune circle draws itself on the floor at the spawn point and the enemy
   rises out of it.
2. **Light 2D on the floor (item 7).** The floor was evenly bright everywhere. It is
   now lit around Fayde, spells, spawns and some enemy bullets. The combat dim that
   darkens the rest of the floor is ADR-0042 (`IsometricRoom.set_combat_dim`, PR #94);
   this ADR only adds the light on top of it.

## Context

- Art bible §2 (Combat Phase): "Dynamic, spell-reactive. Ambient drops 15–20% at wave
  start. Spell bursts own the brightness budget." ADR-0042 owns the dim; this ADR owns
  the spell-reactive light.
- Art bible §6 and §9: "No dynamic lighting on sprite layers." Characters, bullets and
  UI must keep their exact colours, especially enemy bullets (ADR-0037 palette) and the
  high-contrast outline (ADR-0032).
- The game ships a web build on the Compatibility renderer (WebGL 2), so the light count
  must stay small and fixed however busy a fight gets.
- `PointLight2D` and `range_item_cull_mask` / `CanvasItem.light_mask` work the same in
  the Compatibility renderer as in Forward+ for 2D (no shadows used). No API from 4.4+
  is involved.

## Decision

### Spawn glyph

- `SpawnGlyph` (src/visual/spawn_glyph.gd) draws an outer and inner ring flattened by
  `iso_ratio` (0.5, matching the 64×32 tile), rune ticks between them and a centre
  diamond. It is rasterised with `PixelVFX` (ADR-0023) and caches its spans per sweep
  step and rotation step, so it redraws cheaply.
- Colour is `EnemyBulletPalette.rim` (ADR-0037): magenta on the floor always means
  "enemy". The glyph sits at `z_index` 3, over the tiles and under every entity.
- Timeline (`SpawnGlyphTuning`, assets/data/spawn_glyph_tuning.tres):
  draw 0.16 s → (reinforcement hold) → rise 0.2 s → settle 0.08 s → fade 0.3 s.
  The enemy's AI starts after the settle, 0.44 s after spawn, close to the old 0.30 s
  pop-in and hold.
- `WaveManager._rise_from_glyph()` replaces the pop-in. Enemy feet sit on the node
  origin (PixelCharacter), so growing `scale.y` from 0 reads as rising out of the floor.
  Width starts at `rise_start_width` and the enemy's modulate fades in from
  `rise_tint`. With Reduce motion the rise uses a sine ease (no overshoot) and the runes
  do not spin.
- Reinforcements used a red `_ReinforcementWarning` ring during their hold. The glyph
  now covers that: it finishes drawing, then pulses during the hold. The old class is
  removed.
- Glyphs are added to the room that owns the spawn markers, not to `WaveManager`, so
  they leave with the room and are never counted as enemies.

### Floor lighting

- `FloorLighting` (src/visual/floor_lighting.gd) is created by every `IsometricRoom`.
  It adds `FLOOR_LIGHT_MASK` (bit 2) to the floor `TileMapLayer`'s `light_mask`, and
  every light it owns has `range_item_cull_mask = FLOOR_LIGHT_MASK`. Nothing else
  carries that bit, so only the floor tiles are lit.
- The floor's brightness is not touched here: ADR-0042 drives the tiles'
  `self_modulate` for the combat dim and ADR-0039 drives `modulate` for the boss
  ambience. Lights add on top of both.
- Light sources, all additive `PointLight2D` with a shared banded radial
  `GradientTexture2D` (constant interpolation, so the falloff reads as pixel steps):
  - Fayde: one light following the player, art bible E7 Warm Lantern `#8E7358`.
  - Pulses: `cast_started` (at Fayde), `spell_hit_element` (at the target),
    `cascade_burst` and `special_fired` (at the burst, covering its radius), and a spawn
    glyph pulse from `WaveManager`. Prana colours come from `PranaCatalog`. A pool of
    `pulse_pool_size` (6) lights; when all are busy the oldest is reused.
  - Enemy bullets: up to `bullet_light_cap` (8) bullets carry a small light in their
    core colour (`Projectile.core_color()`). Assignment refreshes every 0.1 s; a lit
    bullet keeps its light until it is spent.
- Budget: 1 + 6 + 8 = 15 lights at most, created once per room. A test keeps it ≤ 16.
- Accessibility: pulse energy is multiplied by `GameSettings.flash_multiplier()`
  (Reduce flashes). With Reduce motion, bullet lights are off.
- `FloorLightingTuning.enabled = false` removes every light.
- `FloorLighting` listens to the autoload signals itself, so `spell_vfx.gd` (camera
  shake and hit VFX) is untouched.

## Alternatives Considered

- **CanvasModulate for a darker base.** Rejected: it darkens every sprite and bullet on
  the canvas, which breaks art bible §6 and bullet readability.
- **Additive glow sprites instead of Light2D.** Cheaper still, but they would draw over
  entities standing on them unless each glow got its own z layer, and they cannot
  multiply with the floor colour. Light2D limited to the floor mask gives the right look
  with a fixed, small count.
- **A light on every enemy bullet.** Bullet-hell patterns put hundreds of bullets on
  screen; a capped pool keeps the floor alive without the cost.

## Consequences

- The arena reads darker at its edges and brighter where the action is, and spell
  bursts visibly light the floor in their Prana colour.
- Enemy entrances are telegraphed on the floor ~0.16 s before the body appears.
- New lit floor layers must opt in by adding `FloorLighting.FLOOR_LIGHT_MASK` to their
  `light_mask`.
- Tests: tests/unit/lighting/ (spawn glyph timeline and drawing, floor lighting pools,
  cap, light mask, room wiring) and tests/unit/gamefeel/enemy_spawn_vfx_test.gd (enemy starts
  flat with a glyph).
