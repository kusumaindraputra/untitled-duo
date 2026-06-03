# Epic: Status Effects

> **Layer**: Core
> **GDD**: design/gdd/status-effects.md
> **Architecture Module**: `src/systems/status_effects_manager.gd` (Autoload #7)
> **Status**: Ready
> **Stories**: 5 stories created — 2026-06-04

## Overview

Implements the centralized status effect runtime as Autoload #7. StatusEffectsManager owns all active `StatusInstance` objects per target per type, and tick accumulators for DoT and duration tracking. It exposes `apply_status(target, type, duration, spell_base_damage)` as the sole interface for applying any status effect, and `has_status(target, type)` as the sole query interface. DoT damage routes through H&D.apply_damage(); Regen routes through H&D.apply_heal(). All status instances on a target are cleared when H&D emits `enemy_killed` for that target. Processes via float accumulators in `_process(delta)` — no Timer nodes.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0002: Autoload Architecture | Registered as Autoload #7; access via class_name | LOW |
| ADR-0003: Signal-Driven Architecture | Listens to `enemy_killed` to clear status instances; connects in `_ready()` | LOW |
| ADR-0004: Float Accumulator Timer | All DoT ticks and duration tracking via float accumulators | LOW |
| ADR-0011: StatusEffectsManager API Contract | 4-arg `apply_status()` signature; `has_status()` sole query; Shatter check contract; no per-status helpers | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-SE-001 | Autoload #7; owns all `StatusInstance` objects | ADR-0002 ✅ |
| TR-SE-002 | `apply_status(target, type, duration, spell_base_damage: float = 0.0)` — 4-arg signature | ADR-0011 ✅ |
| TR-SE-003 | `has_status(target, type) -> bool` — sole status query interface | ADR-0011 ✅ |
| TR-SE-004 | DoT ticks via float accumulator → `H&D.apply_damage(target, tick_damage, element, DOT)` | ADR-0004 ✅ |
| TR-SE-005 | Regen ticks via float accumulator → `H&D.apply_heal(target, heal_amount)` | ADR-0004 ✅ |
| TR-SE-006 | Clear all status instances on target when `enemy_killed` fires for that target | ADR-0003 ✅ |
| TR-SE-007 | `preparation_started` → clear ALL active status instances | ADR-0003 ✅ |
| TR-SE-008 | No per-status helpers (`is_frozen()`, `is_blinded()`, etc.) — `has_status()` is sole interface | ADR-0011 ✅ |
| TR-SE-009 | SEM must NOT subscribe to `CombinationResolution.combo_resolved` for SpellEffect caching | ADR-0011 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/status-effects.md` are verified
- All Logic stories have passing unit tests in `tests/unit/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [SEM Skeleton, StatusInstance, and Burn DoT](story-001-sem-skeleton-burn-dot.md) | Logic | Ready | ADR-0011 |
| 002 | [Freeze and Regen Effects](story-002-sem-freeze-regen.md) | Logic | Ready | ADR-0011 |
| 003 | [Stub Effects — Blind, Stun, Chill, Stagger](story-003-sem-stub-effects.md) | Logic | Ready | ADR-0011 |
| 004 | [Kill Cleanup and Phase Clear](story-004-sem-kill-phase-cleanup.md) | Integration | Ready | ADR-0011, ADR-0003 |
| 005 | [Burn Contagion and Shatter](story-005-sem-contagion-shatter.md) | Logic | Ready | ADR-0011 |

## Next Step

Run `/story-readiness production/epics/status-effects/story-001-sem-skeleton-burn-dot.md` then `/dev-story` to begin implementation.
