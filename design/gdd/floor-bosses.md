# Floor Bosses and Per-Run Variants

> **Status**: Implemented (ADR-0028) · **Code**: `src/systems/boss_director.gd`,
> `src/data/boss_*.gd`, `EnemyInstance.apply_boss_variant()` ·
> **Data**: `assets/data/bosses/boss_roster.tres`, `assets/data/bullet_patterns/sentinel_*.tres`,
> `warden_*.tres`, `keeper_*.tres`

## Overview

Each of the three floors ends with a different boss: the Vault Sentinel, the Warped
Warden and the Cipher Keeper (see `final-boss.md`). Each boss has its own bullet
layers and changes the arena as its HP drops. Every run, each boss plays one of
three variants picked from the run seed, shown after its name on the name card.

## Player Fantasy

"I know this boss, but not this version of it." The first boss teaches reading
walls and lines, the second bends bullets and the floor under you, the last one
throws everything. A new run asks the player to look again.

## Detailed Rules

### Vault Sentinel (Floor 1, 250 HP): locks and walls

| HP | Bullets added | Arena | Banner |
|----|---------------|-------|--------|
| 100 % | Aimed 5-bullet fan, two bursts | — | name card |
| 66 % | Ring of 14, two offset bursts | Two turrets rise left and right | "The vault's defences wake — turrets online" |
| 33 % | Rotating laser cross (+ then ×) | Every bullet wiped once | "LOCKDOWN — the Sentinel draws its laser cross" |

### Warped Warden (Floor 2, 500 HP): warped space

| HP | Bullets added | Arena | Banner |
|----|---------------|-------|--------|
| 100 % | Sine-wave spiral | — | name card |
| 70 % | Homing fan of 3 | Three floor vents burning in turn | "Space folds — the floor starts to burn" |
| 40 % | Mortar triple shot with splash | — | "Rifts open — shells rain down" |
| 15 % | Ring wall of 20 × 3, each ring faster | Every bullet wiped once | "TIME COLLAPSES — the field goes quiet, then breaks" |

### Variants

| Boss | Variant | What changes |
|------|---------|--------------|
| Sentinel | Bulwark | Tougher (+25 % HP), slower bullets, slow heavy ring from the start |
| Sentinel | Overclocked | Frailer (−10 % HP), fires 25 % more often, faster bullets and steps |
| Sentinel | Lockdown | Adds an aimed laser from 66 % |
| Warden | Mirrored | A second spiral turning the other way |
| Warden | Hunting | Homing ring from 70 %, moves faster |
| Warden | Unstable | A beam pylon rises at phase 2; fires a little faster, −10 % HP |
| Keeper | Gilded | +15 % HP, wide triple fan from 45 % |
| Keeper | Fractured | Triple aimed laser from 70 % |
| Keeper | Tempest | Fires faster, faster bullets, two vents at the last phase |

- One variant per boss per run. The same run seed always gives the same variants.
- A variant tints the boss and its title appears on the name card:
  "VAULT SENTINEL · OVERCLOCKED".

## Formulas

- Phase index = number of distinct `hp_threshold` values (< 1) whose layers are
  active (ADR-0018).
- Variant pick: `rng.seed = run_seed + boss_type_id × 7919`,
  `index = rng.randi_range(0, variants − 1)`.
- Boss HP = `base_hp × variant.hp_mult` (× Hard Mode, if on, through the pool).
- Bullet speed = pattern speed × floor pool `bullet_speed_mult` × variant
  `bullet_speed_mult`; fire rate the same with `fire_rate_mult`.

## Edge Cases

- A hit that crosses several thresholds applies every phase in between, including
  the variant's events.
- A variant layer must reuse an existing threshold (or 1.0), or it would add a phase.
- A boss without a profile in the roster (none today) gets no arena changes and no
  variant.
- Hazards are room children, freed with the room.

## Dependencies

EnemyInstance (pattern layers, `phase_changed`, `apply_boss_variant`) · WaveManager
(`boss_variants`, `boss_spawned`) · StageHazard (turret, floor vent, sweep laser,
closing ring) · Projectile · CombatHUD · UICopy.

## Tuning Knobs

Each `sentinel_*` / `warden_*` / `keeper_*` pattern; events, hazard specs and
variants in `boss_roster.tres`; banners and variant titles in UICopy.

## Acceptance Criteria

- The three floor boss pools spawn three different bosses that share no bullet
  layer (`boss_roster_test.gd`).
- Every boss phase has a banner; every event falls on an existing phase.
- Each boss has three variants with titles; no variant adds a phase.
- The same seed picks the same variant; 64 seeds reach every variant.
- A variant scales HP, speed, bullet speed and fire rate and adds its layers; the
  HUD shows its title (`boss_variant_test.gd`).
