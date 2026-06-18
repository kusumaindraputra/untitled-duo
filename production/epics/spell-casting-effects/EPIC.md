# Epic: Spell Casting & Effects

> **Layer**: Core
> **GDD**: design/gdd/spell-casting-effects.md
> **Architecture Module**: `src/systems/spell_casting_effects.gd` (Autoload #9)
> **Status**: Complete
> **Stories**: 4 stories (created 2026-06-06)

## Overview

Implements the runtime spell execution loop as Autoload #9. SpellCastingEffects owns the SpellEffect cache per wave, SC&E state machine (IDLE / READY / CHAINING / CAST_LOCKED), combo index, and timing accumulators. On player cast input, it fires a ray via `PhysicsDirectSpaceState2D.intersect_ray()` to find the primary target, applies the damage formula through H&D, applies status effects via StatusEffectsManager, and advances the chain indicator. It exposes `get_stat_bonus(stat_id: StringName) -> float` as the wave-scoped stat broker per ADR-0009 — the sole interface for querying wave-level spell stats. Emits `chain_index_changed`, `spell_hit_element`, and `cast_hit_started` signals.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: Signal-Driven Architecture | Emits `chain_index_changed`, `spell_hit_element`, `cast_hit_started`; listens to `combo_resolved` | LOW |
| ADR-0004: Float Accumulator Timer | Chain timing and cast-lock duration via float accumulators | LOW |
| ADR-0009: SC&E Wave-Scoped Stat Broker | Sole owner of SpellEffect cache; `get_stat_bonus()` as sole stat query interface | LOW |
| ADR-0011: StatusEffectsManager API | Calls `apply_status(target, type, duration, spell_base_damage)` after each hit; calls `check_and_apply_shatter()` before each DIRECT `apply_damage()` | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-SC-001 | Autoload #9; caches SpellEffect from `combo_resolved`; clears on `preparation_started` | ADR-0009 ✅ |
| TR-SC-002 | SC&E state machine: IDLE → READY → CHAINING → CAST_LOCKED | ADR-0003 ✅ |
| TR-SC-003 | Ray cast via `PhysicsDirectSpaceState2D.intersect_ray()` for primary target | ADR-0009 ✅ |
| TR-SC-004 | Damage formula applied via `H&D.apply_damage(target, base_damage, element, DIRECT)` | ADR-0007 ✅ |
| TR-SC-005 | `get_stat_bonus(stat_id: StringName) -> float` — returns 0.0 between waves | ADR-0009 ✅ |
| TR-SC-006 | Chain indicator signals: `chain_index_changed(combo_index, combo_attack_count)` | ADR-0003 ✅ |
| TR-SC-007 | `cast_hit_started(duration)` → PlayerController CAST_LOCKED sub-state | ADR-0003 ✅ |
| TR-SC-008 | `check_and_apply_shatter()` called before every DIRECT `apply_damage()` | ADR-0011 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/spell-casting-effects.md` are verified
- All Logic and Integration stories have passing test files in `tests/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | SpellEffect Resource, Stub CR, and SC&E Autoload Skeleton | Logic | Ready | ADR-0009 |
| 002 | Cast Input, Float Accumulators, and Chain Timing | Logic | Ready | ADR-0004 |
| 003 | FP Damage Formula, Targeting, and Status Stubs | Logic | Ready | ADR-0011 |
| 004 | FP Integration Test | Integration | Ready | ADR-0003 |

## Next Step

Run `/story-readiness production/epics/spell-casting-effects/story-001-spell-effect-resource-skeleton.md` then `/dev-story` to begin implementation.
