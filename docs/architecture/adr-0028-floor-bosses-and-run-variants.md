# ADR-0028: A Boss of Its Own per Floor, and Per-Run Boss Variants

## Status

Accepted

## Date

2026-09-25

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

Every floor now has a boss that fights differently, and each boss plays one of three
variants chosen from the run seed.

1. **Unique floor bosses.** The Vault Sentinel (Floor 1) and the Warped Warden
   (Floor 2) used to share the same three bullet layers. Each now has its own layers
   and its own arena changes, like the Cipher Keeper (Floor 3, ADR-0026).
2. **One director for every boss.** `FinalBossDirector` and `FinalBossConfig` are
   replaced by `BossDirector` and a `BossRoster` of `BossProfile`s. The Keeper's
   arena data moved into the roster unchanged.
3. **Per-run variants.** Each profile lists `BossVariant`s. `BossRoster.pick_all()`
   picks one per boss from the run seed; `WaveManager` applies it as the boss spawns.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Gameplay systems / Data |
| **Knowledge Risk** | LOW: `Resource`, typed arrays, `RandomNumberGenerator.seed`, all unchanged since 4.0. No 4.4+ APIs. |

## Context

After ADR-0026 only the final boss had its own fight. Floors 1 and 2 reused one
pattern set, so the first two boss rooms felt the same, and every boss played the
same way every run. The game's direction is a fast bullet hell with many attack
types, so each boss needs a clear identity, and repeat runs need a reason to look
at the boss again.

## Decision

### Data

- `BossPhaseEvent`: `phase`, `hazards: Array[HazardSpec]`, `clear_bullets`.
- `BossProfile`: `boss_type_id`, `events`, `banner_copy_key` (a UICopy property),
  `banner_color`, `phase_trauma`, `variants`.
- `BossVariant`: `id` (also the key into `UICopy.boss_variant_titles`),
  `extra_layers`, `extra_events`, `hp_mult`, `bullet_speed_mult`, `fire_rate_mult`,
  `move_speed_mult`, `tint`.
- `BossRoster`: `profiles`. Authored as `assets/data/bosses/boss_roster.tres`.

### Bosses

| Floor | Boss | Layers (HP gate) | Arena |
|-------|------|------------------|-------|
| 1 | Vault Sentinel | aimed double fan (100 %), ring pair (66 %), rotating laser cross (33 %) | phase 1: two turrets; phase 2: bullet wipe |
| 2 | Warped Warden | sine spiral (100 %), homing fan (70 %), mortar with splash (40 %), accelerating ring wall (15 %) | phase 1: three floor vents taking turns; phase 3: bullet wipe |
| 3 | Cipher Keeper | unchanged (ADR-0026) | unchanged: pylon, closing ring, bullet wipe |

### Variants

| Boss | Variant | Change |
|------|---------|--------|
| Sentinel | Bulwark | +25 % HP, bullets ×0.9, slow heavy ring from the start |
| Sentinel | Overclocked | −10 % HP, fire rate ×1.25, bullets ×1.12, moves ×1.25 |
| Sentinel | Lockdown | aimed laser from 66 % |
| Warden | Mirrored | counter-spinning second spiral, −5 % HP |
| Warden | Hunting | homing ring from 70 %, moves ×1.2 |
| Warden | Unstable | beam pylon at phase 2, fire rate ×1.1, −10 % HP |
| Keeper | Gilded | +15 % HP, wide triple fan from 45 % |
| Keeper | Fractured | triple aimed laser from 70 % |
| Keeper | Tempest | fire rate ×1.15, bullets ×1.1, two vents at phase 3 |

### Flow

- `debug_game_loop._ready()` keeps the seed of its room RNG as the run seed and sets
  `WaveManager.boss_variants = BossDirector.ROSTER.pick_all(run_seed)`.
  `pick_variant` seeds its own RNG with `run_seed + type_id × 7919`, so each boss's
  pick is independent and one seed always gives the same picks.
- `WaveManager` multiplies the H&D registration HP by the variant's `hp_mult`, then
  calls `EnemyInstance.apply_boss_variant()` after `apply_difficulty()`, before
  `boss_spawned`. The variant's multipliers stack on the floor's.
- `BossDirector.attach()` reads the boss's profile and variant; on each phase it
  applies the profile's and the variant's events for every phase up to the new one.
- `CombatHUD.boss_title()` shows "NAME · VARIANT".

### Rules

- A variant's extra layers use an HP threshold the boss already has (or 1.0), so a
  variant never adds an HP phase and banners stay in step. Tested.
- Hazards placed by events use the spec's `position` (room-local); closing rings take
  the room's half extents.

## Alternatives Considered

- **New EnemyTypes for Floors 1 and 2.** Rejected: the Sentinel and the Warden
  already have their own sprites and names. What made them the same fight was the
  shared layers, so only those changed.
- **Variants as separate EnemyTypes.** Rejected: nine near-copies of three bosses,
  and the pool configs would need to pick among them. A variant on top of the base
  keeps one source of truth per boss.
- **Pick variants with the room-modifier RNG stream.** Rejected: the pick would change
  whenever the room generator draws a different number of values. Each boss gets
  its own stream from the seed.
- **Keep `FinalBossDirector` and add a second director.** Rejected: two nodes doing
  the same thing with different data.

## Consequences

- `FinalBossDirector`, `FinalBossConfig` and `final_boss_config.tres` are gone; the
  Keeper's hazards are its profile in the roster.
- The unused shared layers `boss_phase2_spiral`, `boss_phase3_mortar` and
  `boss_phase3_wall` are deleted.
- The Warden now has three phases (was two). Its HP is unchanged at 500.
- The run seed is not saved, so a run cannot be replayed from a seed yet.

## Validation

- Tests: `tests/unit/bosses/boss_roster_test.gd`, `tests/unit/bosses/boss_variant_test.gd`,
  `tests/unit/enemy-data/final_boss_test.gd` (updated to `BossDirector`).
- Screenshots: `production/qa/evidence/boss-variety-evidence.md`.
- Design: `design/gdd/floor-bosses.md`.
