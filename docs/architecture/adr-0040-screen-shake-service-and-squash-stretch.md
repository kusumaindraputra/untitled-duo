# ADR-0040: Screen Shake Service and Squash & Stretch

## Status

Accepted

## Date

2026-09-27

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

Two systems wrote `Camera2D.offset` every frame: `SpellVFX._tick_shake()` (a 4 px
random rattle on a timer) and `PlayerController._physics_process()` (a trauma shake
with sine noise). When both were active the last writer won, so a spell hit could
erase a boss-phase shake. And no shake knew which way the blow went.

1. **One owner of the camera offset.** The new `ScreenShake` autoload
   (`src/core/screen_shake.gd`) is the only code that writes `Camera2D.offset`. It
   finds the active camera with `get_viewport().get_camera_2d()` each frame.
2. **Trauma plus a directional kick.** The math lives in the pure `ShakeState`
   class (`src/core/shake_state.gd`). Trauma (0–1) adds up from every source,
   decays linearly and is squared before it becomes a noise offset, so small hits
   stay gentle. A kick moves the view along the blow and springs back
   exponentially. The two add together.
3. **Named sizes.** Callers pick `ShakeState.Strength.LIGHT / MEDIUM / HEAVY /
   MASSIVE` instead of raw numbers. All values are in `assets/data/shake_tuning.tres`.
4. **Squash & stretch.** `PixelCharacter.squash(peak, duration)` deforms the sprite
   around its feet and springs it back with one overshoot. Fayde stretches along a
   dash, squashes when the dash lands and squashes when a cast begins. Enemies
   squash along the blow when hit, and bosses squash less. The timings are in
   `CharacterFxTuning`.

## API (for other systems)

```gdscript
ScreenShake.impact(ShakeState.Strength.HEAVY, direction)  # preferred
ScreenShake.add_trauma(0.3, direction)                    # raw trauma 0–1
ScreenShake.kick(direction, 6.0)                          # lurch only, no rattle
ScreenShake.reset()                                       # settle at once
```

`direction` is the way the blow travels, for example from the attacker to the
target. `Vector2.ZERO` means no kick. Every call is fire-and-forget and safe when
there is no camera. `PlayerController.add_camera_trauma(amount, direction)` stays
as a wrapper that also rumbles the gamepad. Use it for impacts the player should
feel in their hands.

## Engine Compatibility

No APIs from 4.4 or later. It uses `Viewport.get_camera_2d()`, `Camera2D.offset`,
`Vector2.limit_length()` and `Sprite2D.scale`, which are all stable since 4.0.

## Decision

### Real time, not game time

`ScreenShake` steps with real elapsed time (`Time.get_ticks_usec`), capped at
1/20 s per frame. The shake keeps moving through hit-stop (time scale 0.05), which
is the classic frozen-frame-with-shake look. It stops while the tree is paused
because the autoload is pausable.

### Settings

Every shake is multiplied at the moment it is added by the Screen shake slider
(`GameSettings.shake_multiplier()`). With Reduce motion on, it is also multiplied
by `ShakeTuning.reduce_motion_scale` (0.35). Reduce motion turns squash & stretch
off completely. Gamepad rumble stays on its own slider (ADR-0031).

### Heavy hits shake once

Before, a heavy hit added a double-length SpellVFX rattle on top of the player's
trauma. Now `PlayerController._on_heavy_hit` alone adds the shake, scaled by
damage and kicked toward the target, and `SpellVFX` only does the hit-stop and the
flash.

### Squash scales the sprites, not the node

`PixelCharacter` applies the squash to its body and glow `Sprite2D`s, multiplied by
`pixel_scale`. Their offset puts the feet on the origin, so the character squashes
into the floor instead of around its middle. Nothing that sets the node's own
`scale` is affected.

## Alternatives Considered

- **Keep both shakes and add them.** This would still leave two tunings and two
  settings paths, and the other juice threads would need to know which one to
  call.
- **A shake on PlayerController only.** It would be tied to Fayde's physics tick,
  which freezes in hit-stop, and it has no camera outside a run.
- **Tween-based squash.** Tweens on `scale` fight each other when hits come fast.
  A timer in `advance_fx` restarts cleanly and is testable without a tree.

## Consequences

- New code must not write `Camera2D.offset`. Look-ahead keeps using
  `Camera2D.position`, and zoom keeps using `Camera2D.zoom`.
- Shake values changed slightly. Spell hits have a smaller rattle but add a kick
  along the hit and stack up during a flurry. The Special is MASSIVE (about 8 px at
  its peak, the same as before).
- The next juice ADRs (0041–0044) call this API for boss deaths and room clears.

## Validation

- `tests/unit/screen-shake/screen_shake_state_test.gd`: trauma, kick, bounds,
  determinism, presets, settings and camera write.
- `tests/unit/character-sprites/squash_stretch_test.gd`: squash curve, axes,
  sprite scale, reduce motion, enemy and boss bounce, dash stretch.
- `tests/unit/gamefeel/camera_shake_test.gd`: the player wrapper forwards to
  ScreenShake.
- Screenshots: `production/qa/evidence/adr0040-*.png`.
