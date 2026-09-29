# ADR-0034: Native-Resolution Boss Sprites and Character Effects

## Status

Accepted

## Date

2026-09-26

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

1. **Bosses at the active brother's pixel size**: the Vault Sentinel, Warped Warden and Cipher
   Keeper get their own sheets drawn at native resolution (96×96, 96×96, 144×144)
   with `sprite_pixel_scale = 1`. The Keeper no longer reuses the Sentinel sheet.
2. **Third sheet row**: every character sheet is now 4 columns × 3 rows. Row 2 is
   The duo's cast pose and each enemy's attack wind-up.
3. **Sprite effects in a shader**: a white hit flash and a death dissolve run in
   `assets/shaders/pixel_character.gdshader`, driven by `PixelCharacter`.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Rendering / Visual |
| **Knowledge Risk** | LOW: canvas_item shaders (`COLOR`, `UV`, `TEXTURE_PIXEL_SIZE`), `ShaderMaterial.set_shader_parameter` and `Sprite2D.hframes/vframes` are unchanged in 4.4–4.6 and work in the Compatibility renderer. |

## Context

The art review found three problems with the characters:

- The Cipher Keeper was the Vault Sentinel sheet tinted gold and drawn 3× (one sheet
  pixel = 3 world pixels). The Sentinel and Warden were drawn 2×. Their pixels were
  much larger than the duo's, and the final boss looked like a recoloured floor-1 boss.
- Sheets had only idle and walk rows, so casting and attacking had no pose.
- Hits tinted the whole node with `modulate`. The duo turned red; enemies were set to
  `Color(3, 3, 3)`, which in the Compatibility renderer only brightens the sprite and
  never reaches white on dark pixels. Dead enemies stood still for 0.7 s and popped.

## Decision

### Sheets

`tools/art-gen/generate_character_sprites.gd` writes every sheet as 4 × 3:
idle, move, cast. Bosses and the duo are "posed" and draw their own cast row. Standard
enemies get a generated wind-up row: their idle frames with the upper body leaning
(stair-step shear) and the Prana marker brightened. Boss designs follow art bible
§5.2 and each boss uses its reserved colour (§4.3): Sentinel B2 teal, Warden B1
violet, Keeper B3 rose.

`PixelCharacter.ROWS = 3`. `frame_for(time, row, fps)` now takes a row index.
`play_cast(duration)` spreads the four cast columns over the duration and holds the
last; the idle/move rows resume after it.

### Effects

`PixelCharacter` creates one `ShaderMaterial` the first time an effect runs (so
characters that are never hit keep batching with no material), shared by the body
and glow sprites. Timers advance in `_process`, so hitstop slows them like the rest
of the game.

- `flash(color, duration, strength)` mixes every opaque pixel toward the colour.
  It holds full strength for `flash_hold` of the duration, then fades.
- `dissolve(duration, rim)` removes pixels in 2×2 clusters. A noise key is mixed
  with the pixel's height in its frame (`dissolve_rise`), so the top goes first and
  the front glows in the rim colour (art bible §5.3 bloom → dissolve).

Wiring:

| Event | Before | After |
|-------|--------|-------|
| Enemy hit (`request_hit_flash`) | `modulate = (3,3,3)` | White flash on the sprite; placeholder bodies keep the old modulate |
| The duo hit (`SpellVFX._on_damage_taken`) | Whole node tinted red | White flash on the sprite |
| Cast begins (`SpellVFX._on_cast_started`) | Overbright Prana modulate | Cast row plus a 45 % Prana-colour flash |
| Enemy volley wind-up | Pattern-colour modulate only | Same modulate, plus the wind-up row |
| Enemy death | Body stays until freed | Sprite dissolves (Prana-colour rim; neutral for bosses) |

All timings are in `assets/data/character_fx_tuning.tres` (`CharacterFxTuning`).
The dissolve must finish before `EnemyInstance.BASE_DEATH_DURATION` frees the node.

## Alternatives Considered

- **Keep bosses at 2–3× and add detail**: rejected. The mismatch in pixel size is
  the problem the review raised.
- **Overbright modulate for the flash**: rejected. It cannot make dark pixels white,
  and it fights the other modulate users (status tints, wind-up, i-frame blink).
- **CanvasItem instance shader uniforms**: not used; a per-character material
  created on first use is simpler and works on every renderer.
- **Separate hit and defeat rows**: deferred. The flash covers the hit read, and the
  dissolve covers defeat until a crumple pose is worth the sheet space.

## Consequences

- Sheets are 1.5× taller. Anything that slices a sheet must use `PixelCharacter.ROWS`
  (MenuBackdrop only reads frame 0).
- A character that has been hit keeps its own material and no longer batches with
  others of the same sheet. Bosses and a handful of enemies per room are well
  inside the draw-call budget (art bible §8.5).
- Boss variant tints still multiply `modulate` and still apply under the flash.

## Validation

- `tests/unit/character-sprites/character_fx_test.gd`: flash and cast timing, dissolve
  progress and signal, lazy material, boss sheets at native size and distinct, and
  the enemy / the duo wiring.
- `tests/unit/character-sprites/pixel_character_test.gd`: updated for the 3-row layout.
- Screenshots: `production/qa/evidence/art-bosses-*.png`, `art-fx-*.png`.

## Related

ADR-0022 (pixel-art characters), ADR-0023 (pixel VFX), ADR-0028 (floor bosses and
variants), art bible §4.3, §5.3, §5.4, §8.6.
