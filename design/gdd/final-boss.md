# Final Boss: The Cipher Keeper

> **Status**: Implemented (ADR-0026) · **Code**: `src/systems/final_boss_director.gd` ·
> **Data**: `assets/data/enemy_types/enemy_cipher_keeper.tres`,
> `assets/data/final_boss/final_boss_config.tres`, `assets/data/bullet_patterns/keeper_*.tres`

## Overview

The Floor 3 boss is a dedicated final encounter instead of a reused floor boss. It
has a signature rotating laser lattice, five bullet layers across three HP phases,
and the arena itself changes at each phase.

## Player Fantasy

"This is the end of the run." The fight escalates in clear steps the player can
read: a named banner, a camera kick, and a new rule for the room each time.

## Detailed Rules

| HP | Bullets added | Arena change | Banner |
|----|---------------|--------------|--------|
| 100 % | Laser lattice (4 beams, rotating 22° per volley), aimed 5-bullet fan | — | Boss name card |
| 70 % | Homing ring (8) | Beam pylon rises in the room centre | "The first lock breaks — a beam pylon rises" |
| 45 % | Sine spiral | Closing ring shrinks the arena to 50 % | "The vault closes in" |
| 20 % | Mortar with splash | Every enemy bullet is wiped once | "THE LAST CIPHER — hold on" |

- A hit that crosses two thresholds applies every phase in between.
- Defeating the Keeper ends the run as a win (it is the final room of Floor 3).

## Formulas

- Phase index = number of distinct `hp_threshold` values (< 1) whose layers are
  active (ADR-0018). Thresholds 0.7 / 0.45 / 0.2 give phases 1 / 2 / 3.
- Pool multipliers from `enemy_pool_boss_f3.tres` (bullet speed ×1.2, fire rate
  ×1.15, telegraph ×0.85) apply on top, plus Hard Mode when on.

## Edge Cases

- Any other boss that spawns is ignored by the director.
- Hazards are room children, so they are freed with the room.
- The bullet wipe happens once (phase 3), not on every hit below 20 %.

## Dependencies

EnemyInstance (pattern layers, `phase_changed`, `get_type_id`) · WaveManager
(`boss_spawned`) · StageHazard (sweep laser, closing ring) · Projectile · CombatHUD.

## Tuning Knobs

HP (`base_hp` 900), each `keeper_*.tres` pattern, which phase gets which hazard and
the hazard specs in `final_boss_config.tres`, `phase_trauma`, banner text in UICopy.

## Acceptance Criteria

- The Keeper is a BOSS with three distinct HP phases; Floor 3's boss pool spawns it
  (`final_boss_test.gd`).
- Phase 1 spawns a sweep laser, phase 2 a closing ring; skipping a phase still
  applies it.
