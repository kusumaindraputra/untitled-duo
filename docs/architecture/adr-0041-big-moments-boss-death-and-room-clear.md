# ADR-0041: Big Moments — Boss Death Cinematic and Room Clear

## Status

Accepted

## Date

2026-09-27

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

The game-feel review found that a boss died like an elite (a short hitstop and a
0.55 s dissolve, then the reward screen at once) and a room clear was only a gold
wash and the rank banner. Two "big moments" fix that:

1. **Boss death cinematic (`BossDeathCinematic`)**: slow-mo (0.25× for 1.4 real s),
   a white flash, the music cut to a low boom, and a camera that glides onto the
   boss, holds while it dissolves (1.1 game s instead of 0.55), then glides back to
   The duo. The memory card (non-final floors) and the run summary wait for it.
2. **Room clear moment (`RoomClearMoment`)**: a short slow-mo right after the last
   kill (0.3× for 0.45 real s), a big `CLEAR` punching in over the rank banner,
   orbs that gather for a beat and then whip into the duo with a streak, and an
   exit-door burst when the door unlocks.

All timings live in `assets/data/big_moment_tuning.tres` (`BigMomentTuning`).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Game feel / Camera / UI |
| **Knowledge Risk** | LOW. `Camera2D.make_current()`, `get_screen_center_position()`, `Tween.set_ignore_time_scale()` (4.3+, already used by CombatHUD), `CanvasItem.draw_*`. |
| **Post-Cutoff APIs Used** | None |

## Decision

### A separate cinematic camera

The boss camera is its own `Camera2D`, made current for the beat and handed back
to the duo's camera at the end. It starts from the active brother's `get_screen_center_position()`
and zoom, so the swap has no jump. The duo's camera offset belongs to screen shake
(ADR-0040 is unifying it) and her camera position to look-ahead, so the cinematic
touches neither. Camera limits are copied across.

### Real-time state machines

Both moments run inside their own slow-mo, so they advance on real seconds
(`Time.get_ticks_usec()` deltas) and expose `advance(real_dt)` / `finish_room()`
for headless tests. The banner tween uses `set_ignore_time_scale(true)`.

### DeferredWarp for slow-mo on a kill

Every kill already starts a hitstop, and TimeWarp (ADR-0019) refuses a new warp
while another is active. `DeferredWarp` retries `TimeWarp.try_apply()` for up to
`slowmo_wait_sec` real seconds, so the hitstop freeze reads first and the slow-mo
takes over after it. It never overrides another warp, so the death slow-mo still
wins over everything.

### Music cut through the stinger path

The boom is a new stinger event, `stg_boss_felled` (synthesised by
`tools/audio-gen/synth_sfx.py`), with `duck_depth_db = -40`. `AudioSystem.play_stinger()`
ducks the Music bus while the boom plays and restores it over 1.2 s, so no new
AudioSystem API was needed.

### Reward screens wait for the beat

`GameStateManager` still moves to `RUN_SUMMARY` / `floor_completed` as before.
`debug_game_loop` awaits `BossDeathCinematic.finished` (only while it is playing)
at the top of `_on_floor_completed()` and of `_on_run_ended(true)`, so the state
machine stays untouched.

### Where each part lives

- `BossDeathCinematic` (src/systems): listens for a boss `enemy_killed`.
- `EnemyInstance.dissolve_seconds()`: the boss dissolve length; the death fallback
  timer waits for it.
- `RoomClearMoment` (src/systems) + `ClearBanner` (src/ui): counts room kills and
  shows the banner. Boss rooms are skipped: the cinematic is their moment.
- `PickupOrb`: a room clear pull (`magnetize`) now ramps from 30 % to full speed and
  draws a streak. PaceDirector still triggers the pull.
- `RoomExitDoor._DoorBeacon.burst()`: flare plus a ring out to 120 px on unlock.

### Accessibility

- **Reduce motion**: no camera glide (the beat keeps its length so the dissolve still
  reads), no scale punch or growing rule on `CLEAR`, no door ring (flare only).
  Slow-mo is kept; it is timing, not movement.
- **Reduce flashes**: the white flash is scaled by `GameSettings.flash_multiplier()`.
- **Screen shake**: this ADR adds no shake. The final-kill trauma stays in WaveManager.

## Alternatives Considered

- **Tween the duo's own camera**: fights look-ahead (written every physics frame) and
  the shake offset, and would edit code another thread owns. Rejected.
- **Delay `boss_defeated` in WaveManager or GameStateManager**: touches the signal
  contract of ADR-0014 and every system that reacts to it. Rejected in favour of
  awaiting in the orchestrator.
- **Stop the music player**: needs a new AudioSystem API and a restart point. The
  stinger duck already does "cut and bring back". Rejected.

## Consequences

- A boss room now takes about 2.2 s longer before the memory card or summary.
- New big moments should reuse `DeferredWarp` rather than write `Engine.time_scale`.
- Anything else that makes a camera current must expect the cinematic camera for
  up to `boss_zoom_in_sec + boss_hold_sec + boss_zoom_out_sec` after a boss dies.

## Validation

- `tests/unit/big-moments/big_moments_boss_cinematic_test.gd`: timeline with and
  without reduced motion, flash curve and scale, boss dissolve fits in the beat,
  phase order and one `finished`, slow-mo, camera glide and hand-back, flash cleared.
- `tests/unit/big-moments/big_moments_room_clear_test.gd`: DeferredWarp wait and
  give-up, when the moment plays, kill counting, banner text from UICopy, orb pull
  ramp and arrival, door burst.
- Screenshots: `production/qa/evidence/adr0041-*.png`.
