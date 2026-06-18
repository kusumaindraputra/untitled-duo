# Epic: Health & Damage

> **Layer**: Core
> **GDD**: design/gdd/health-damage.md
> **Architecture Module**: `src/systems/health_and_damage.gd` (Autoload #6)
> **Status**: Complete
> **Stories**: 5 stories created 2026-05-31

## Overview

Implements the centralized HP and damage pipeline as Autoload #6. HealthAndDamage owns Fayde's `current_hp`, all enemy HP instances (Dict[int, EnemyHPInstance]), the i-frame active flag, and the current HP zone. All damage and healing in the game flows through `apply_damage(target, base_damage, element, source)` and `apply_heal(target, heal_amount)` — no system modifies HP directly. H&D fires `damage_taken`, `health_restored`, `player_died`, `enemy_killed`, `heavy_hit`, and `player_hp_zone_changed` signals that downstream systems (CombatHUD, AudioSystem, WaveManager, EnemyInstance) subscribe to. HP stored as `float` internally; exposed as `int` via `roundi()`.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: Signal-Driven Architecture | All damage events exposed as signals; no polling | LOW |
| ADR-0004: Float Accumulator Timer | I-frame window via float accumulator in `_process(delta)` | LOW |
| ADR-0007: HealthAndDamage Singleton | Singleton Autoload; `apply_damage` / `apply_heal` API; dead-target guard; enemy HP registry | LOW |
| ADR-0011: StatusEffectsManager API | DoT damage routed through H&D; `enemy_killed` clears all status on target | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-HD-001 | Autoload #6 singleton; owns all HP state | ADR-0007 ✅ |
| TR-HD-002 | `apply_damage(target, base_damage, element, source)` — sole damage entry point | ADR-0007 ✅ |
| TR-HD-003 | `apply_heal(target, heal_amount)` — sole heal entry point | ADR-0007 ✅ |
| TR-HD-004 | I-frame window (0.5s) via float accumulator; `is_invincible()` blocks CONTACT damage | ADR-0004 ✅ |
| TR-HD-005 | Dead-target guard — reject `apply_damage` on targets at 0 HP | ADR-0007 ✅ |
| TR-HD-006 | Enemy HP registry: `register_enemy(enemy, type_id)` called by WaveManager before spawn | ADR-0007 ✅ |
| TR-HD-007 | `enemy_killed(instance_id, type_id, prana_affiliation)` signal — sole emitter | ADR-0007 ✅ |
| TR-HD-008 | `player_hp_zone_changed(HPZone)` — FULL / CAREFUL (≤40) / DESPERATE (≤20) | ADR-0007 ✅ |
| TR-HD-009 | HP stored as `float`; damage numbers exposed as `int` via `roundi()` | ADR-0007 ✅ |
| TR-HD-010 | `heavy_hit` signal emitted when single hit ≥ 30% max HP | ADR-0007 ✅ |
| TR-HD-011 | Player lookup via `"player"` group; target discrimination via `is_in_group()` | ADR-0010 ✅ |
| TR-HD-012 | `force_end_iframe_window()` — test seam only; never called from gameplay code | ADR-0007 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/health-damage.md` are verified
- All Logic and Integration stories have passing test files in `tests/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Autoload Skeleton, Enemy HP Registry, Run Reset](story-001-autoload-skeleton.md) | Logic | Ready | ADR-0007 |
| 002 | [apply_damage() — Core Formula and Dead-Target Guard](story-002-apply-damage-pipeline.md) | Logic | Ready | ADR-0007 |
| 003 | [I-Frame Window (Float Accumulator)](story-003-iframe-window.md) | Logic | Ready | ADR-0004 |
| 004 | [apply_heal() and HP Zone Signals](story-004-heal-and-zones.md) | Logic | Ready | ADR-0007 |
| 005 | [Death Signals, Heavy Hit, and First-Run Mercy](story-005-death-and-heavy-hit.md) | Logic | Ready | ADR-0007 |

## Next Step

Run `/story-readiness production/epics/health-damage/story-001-autoload-skeleton.md` then `/dev-story` to begin implementation.
