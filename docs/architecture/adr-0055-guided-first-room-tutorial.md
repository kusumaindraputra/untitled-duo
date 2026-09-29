# ADR-0055: Guided First-Room Tutorial

## Status

Accepted

## Date

2026-09-27

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

The first room of a player's first run is now a guided lesson instead of loose hints.
Six lessons appear one at a time on a card at the bottom centre:

| # | Lesson | Phase | Ticks when |
|---|--------|-------|------------|
| 1 | Place a Prana from the bag | Prep | a Prana leaves the bag while the grid is open |
| 2 | Lock the grid | Prep | combat starts (also ticks lesson 1) |
| 3 | Move | Combat | The duo travels `move_distance` px |
| 4 | Dash | Combat | Faith is dashing |
| 5 | Cast at a training target | Combat | a training target takes damage |
| 6 | Perfect Dodge | Combat | PaceDirector reports a Perfect Dodge |

The room's real wave waits until the lessons end, then arrives with a "NOW FOR REAL"
banner. Holding **Backspace** or pad **Back** for `skip_hold_sec` ends the lessons at
once, in either phase. The lessons run once: `MetaProgress.tutorial_room_done` is saved
when they finish or are skipped.

- `TutorialRoom` (`src/systems/tutorial/tutorial_room.gd`) keeps the lesson list and
  spawns the training targets (tougher `DummyEnemy` instances) and a shot pylon.
- `TutorialTurret` (`src/gameplay/tutorial_turret.gd`) glows, then fires one slow
  **0-damage** `Projectile` at the duo. Only while lesson 6 is on screen.
- `TutorialRoomPanel` (`src/ui/tutorial_room_panel.gd`) is the card: counter, lesson,
  detail line, hold-to-skip prompt and fill bar.
- `WaveManager.hold_wave` and `release_wave()` hold the room's wave back.
- Values are in `assets/data/tutorial_room_tuning.tres`. Copy is in the new
  "Tutorial Room" group of `UICopy`.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | UI / Gameplay flow |
| **Knowledge Risk** | LOW: `Input.is_action_pressed`, `ProgressBar`, `SceneTree.create_timer` and `Label.autowrap_mode` are unchanged in 4.4–4.6. |

## Context

ADR-0031 replaced the old "HOW TO FIGHT" card with one-at-a-time hints. They still
arrived in the middle of a real fight, so a new player learned the grid, the dash and
Perfect Dodge while being shot at. The first room had nothing to cast at safely, and
Perfect Dodge (the move the fast-pace layer rests on) was only described, never
practised. The prep grid also opened with only the core Prana, so "arrange your Prana"
had nothing to arrange.

## Decision

- **Where.** Only floor 1's entry room, on a run that starts with
  `tutorial_room_done == false`. `debug_game_loop._on_core_picked()` sets
  `WaveManager.hold_wave` **before** `GameStateManager.start_run()`, so the wave
  preview never flashes up during the lessons.
- **Lesson Prana.** The loop drops `bag_prana` Prana of the picked core's type into
  the bag. `PranaGrid.on_bag_changed()` (wired by the parent) rebuilds the tray when
  Prana land while the grid is open. Matching the core type makes lesson 1 also teach
  spell tiers.
- **Order.** One lesson on screen, always the first unticked one. Lessons tick in any
  order, so a player who dashes early is never asked again. Starting the fight ticks
  both grid lessons, because confirming the grid is what starts it.
- **Targets.** Targets use `DummyEnemy` with `hp_mult = target_hp_mult`, passed to both
  `HealthAndDamage.register_enemy()` and the dummy's own bar. A destroyed target comes
  back after `target_respawn_sec`. Their kills are not a Spellbook discovery:
  `_log_enemy_discovery()` asks `TutorialRoom.is_target()` first, because the dummy
  borrows the Warped Warden's catalog id.
- **Spots.** Targets take the room's spawn markers nearest the duo (at least
  `target_min_distance` away). The pylon takes the free marker whose distance is
  closest to `turret_distance`. Markers are always inside the room.
- **Perfect Dodge.** The pylon fires a normal `Projectile` with `base_damage = 0`, so
  a hit costs nothing, arms no i-frames and still despawns. A dash through it runs the
  real Perfect Dodge path (slow-mo, Special meter). With Assist auto-dash on, the
  bullet is dodged but earns nothing, so after `dodge_fallback_shots` shots the lesson
  ticks on its own. The room never soft-locks.
- **End.** On finish, the loop saves `tutorial_room_done` (and `tutorial_done` when
  skipped), frees the lesson nodes and calls `WaveManager.release_wave()`. After a
  full run it waits `done_hold_sec` on a pausable timer so "Training complete." shows
  first. `PaceDirector.style.begin_room()` restarts the room rank, so the lessons do
  not count against it.
- **Coach.** After a full run the ADR-0031 coach starts with the six hints the room
  taught ticked quietly (`TutorialCoach.pretick()`). Only Perfect Cast and Special are
  left, and they show during the real fight. A skip means "I know this": both flags
  are set and no coach runs.
- **Old saves.** `tutorial_room_done` defaults to `tutorial_done or runs > 0`, so a
  returning tester does not get sent back to training. Pause → Replay Tutorial clears
  both flags. The coach restarts at once, and the guided room comes back on the next
  run.
- **Skip input.** `tutorial_skip` = Backspace / pad Back. Back is never offered for pad
  rebinding (ADR-0031), so it cannot clash. Holding (not tapping) it stops a stray
  press from throwing the lesson away.

## Alternatives Considered

- **A separate tutorial scene before the run** (like `TrainingRoom`). Rejected: it
  would need its own run bootstrap. It would also teach in a room the player never
  sees again, and it is one more screen between PLAY and the game.
- **Keep the coach and only add targets.** Rejected: the hints would still arrive
  while real enemies shoot, which is the problem.
- **Lock later lessons until earlier ones tick.** Rejected: it punishes players who
  already know a move, and lesson order already guides without locking.
- **Killable, fragile targets.** Rejected: one Special would clear the lesson before
  the cast was learned, and the kill would unlock the Warden in the Spellbook.

## Consequences

- The first run's first room is longer, by roughly 30–60 s for a new player. A skip
  costs one second of holding.
- Two extra Prana on the first run's first room make it slightly easier. This is
  intended.
- `WaveManager` gains a hold state. Any future flow that wants a scripted beat before a
  wave can reuse `hold_wave` / `release_wave()`.
- The card sits where the coach toast sits. At 130 % text it is 436 px wide and clears
  the prep panel at 1152 × 648.

## Validation

- `tests/unit/tutorial/tutorial_room_test.gd`: lesson order, any-order ticks, grid
  lessons on combat start, bag shrink, finish/skip once, copy sizes, placeholder
  filling for keyboard and pad, spot picking, tuning sanity, save round trip, old-save
  default, coach pretick.
- `tests/unit/wave-encounter-system/wave_manager_hold_test.gd`: hold, release, no-op
  release, stale hold cleared.
- Screenshots at 130 % text, keyboard and pad:
  `production/qa/evidence/adr0055-*.png` (copies in `/mnt/project-files/tutorial-room/`).
