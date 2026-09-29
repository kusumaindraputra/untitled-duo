# ADR-0026: Run Variety, the Final Boss, and Player Settings

## Status

Accepted

## Date

2026-09-25

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

Four additions that make each run play differently and make the game ready for
outside players:

1. **Behaviour sigils.** Seven sigils change how a run plays instead of adding a
   percentage. A run-scoped `SigilEffects` node hangs their effects off signals
   that already exist; `SigilManager` only adds stacks.
2. **Room modifiers.** Some combat rooms roll Challenge (no-hit bonus) or Cursed
   (harder, two picks). Rest rooms become Wayshrines (trade HP for a sigil). The
   modifier is a key on the existing `DungeonGraph` room, not a new room type.
3. **The Cipher Keeper.** Floor 3 gets its own final boss. Its bullets are normal
   pattern layers; a `FinalBossDirector` changes the arena at each HP phase.
4. **Settings.** One panel for display, comfort (shake, flashes), audio and keyboard
   rebinding, saved to `user://settings.cfg`. The window scales a fixed 1152×648
   view (`canvas_items` stretch).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Gameplay systems / UI / Persistence |
| **Knowledge Risk** | LOW: `ConfigFile`, `InputMap`, `DisplayServer.window_set_mode/size/vsync_mode`, `Resource.duplicate()`, all unchanged since 4.0. No 4.4+ APIs. |

## Context

After ADR-0025 a run looked the same every time: the sigil pool was eight stat
bumps, every combat room was the same fight at a different size, rest rooms were a
free heal, and Floor 3 reused the Floor 1 boss. Outside players also had no way to
turn off screen shake, reduce flashes, rebind keys or go fullscreen.

## Decision

### Behaviour sigils

- Catalog entries in `SigilConfig.sigils` carry `"behaviour": true`; tuning is in the
  "Behaviour Sigils" group of the same resource.
- `SigilEffects` (created in `debug_game_loop._ready`) listens to `grazed`,
  `special_fired`, `perfect_cast`, `enemy_killed` and `run_started`. The parent
  connects `PaceDirector.perfect_dodge_triggered` to `on_perfect_dodge` (sibling
  wiring rule). Ember Wake polls `player.is_dashing()`.
- `SigilManager.apply_sigil` routes any id `SigilEffects.handles()` to `add_stack`.
  A second pick of the same sigil adds a stack that scales it.

### Room modifiers

- `RoomModifiers.assign(graph, rng)` runs right after each floor is generated. It
  sets `room["modifier"]` on combat rooms other than the entry room, capped per
  floor. Elite, rest and boss rooms are never modified.
- Cursed rooms swap `WaveManager.enemy_pool_config` for a harder copy of the floor
  pool; the shared `.tres` is never changed (same rule as Hard Mode).
- Challenge: the first `damage_taken` on the duo during combat in that room loses the
  bonus. A flawless clear adds `bonus_shards` to the run data, which
  `MetaProgress.record_run` pays after the Hard Mode multiplier.
- `SigilManager.offer_sigils(picks)` re-opens with fresh cards until the picks are
  used, then emits `offer_finished`.
- Wayshrine: `HealthAndDamage.pay_fayde_hp(cost)` is a price, not an attack. It never
  leaves the duo below 1 HP and emits `damage_taken` so the HUD updates.
- Doors, the minimap ("!" Challenge, "X" Cursed) and a HUD banner show the modifier.

### The Cipher Keeper

- New `EnemyType` id 11 (`enemy_cipher_keeper.tres`), five pattern layers:
  rotating four-beam laser lattice (signature) and aimed fan from the start; homing
  ring at 70 %; sine spiral at 45 %; mortar at 20 %. `enemy_pool_boss_f3.tres`
  now spawns it.
- `FinalBossDirector.attach()` is called on every `boss_spawned` and ignores every
  boss but id 11. On `phase_changed` it applies each phase up to the new one (a
  big hit can cross two thresholds): phase 1 beam pylon, phase 2 closing ring,
  phase 3 bullet wipe. Hazards are the existing `StageHazard` kinds.
  Data: `assets/data/final_boss/final_boss_config.tres`.
- `EnemyType.sprite_tint` lets the Keeper reuse the Vault Sentinel sheet in gold.

### Settings

- `GameSettings` (RefCounted) owns the "game" and "keys" sections of
  `settings.cfg`; `AudioSystem` keeps "audio". Saving keeps the other sections.
- `GameSettings.current` is read through static helpers:
  `PlayerController.add_camera_trauma` and `SpellVFX` shake scale by
  `shake_multiplier()`; heavy-hit, heal and room-clear screen washes scale by
  `flash_multiplier()`.
- Keyboard rebinding replaces only the `InputEventKey` events of an action, so
  gamepad bindings stay. A key already used by another action is swapped.
- `project.godot`: 1152×648 viewport, `canvas_items` stretch with `keep` aspect,
  version 0.9.0, file logging on (crash logs in `user://logs/`).

## Alternatives Considered

- **New room types for Challenge / Cursed / Wayshrine.** Rejected: every system that
  switches on `ROOM_TYPE_*` (music, rewards, doors, minimap, room templates) would
  need a new branch. A modifier on a combat room changes only what differs.
- **Behaviour sigils inside SigilManager.** Rejected: SigilManager is unit-tested
  without a tree and owns the overlay. Effects that listen to signals and spawn
  nodes belong in a node with a lifetime.
- **A new boss script for the Keeper.** Rejected: the pattern-layer system already
  gives HP phases and telegraphs. Only the arena changes are new, so only they got
  code.
- **Keep the window unscaled.** Rejected: fullscreen or a larger window would show
  more of the room than the camera tuning (ADR-0024) assumes.

## Consequences

- The reward pool is 20 cards (8 stat, 7 behaviour, 5 Prana).
- A run's shard payout can include Challenge bonuses; the end screen total already
  shows it.
- `settings.cfg` gains two sections; old files load with defaults.
- The main menu and pause menu no longer have volume sliders; volume is in Settings.
- The gamepad cannot be rebound yet.

## Validation

- Tests: `tests/unit/sigil-effects/`, `tests/unit/level-generation/room_modifiers_test.gd`,
  `tests/unit/enemy-data/final_boss_test.gd`, `tests/unit/settings/`.
- Screenshots: `production/qa/evidence/run-variety-evidence.md`.
- Design: `design/gdd/behaviour-sigils.md`, `design/gdd/room-modifiers.md`,
  `design/gdd/final-boss.md`.
