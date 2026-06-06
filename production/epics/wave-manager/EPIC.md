# Epic: WaveManager

> **Layer**: Feature
> **GDD**: design/gdd/wave-encounter-system.md
> **Architecture Module**: `src/systems/wave_manager.gd`
> **Status**: Ready
> **Stories**: 4 stories created 2026-06-06

## Overview

Implements the runtime encounter layer that structures what Fayde faces in each room. WaveManager owns the full encounter lifecycle: resetting state on `preparation_started`, spawning all 10 enemies simultaneously when `combat_started(is_boss: false)` fires, and tracking kills until the wave clears. It is the **sole authoritative emitter** of `wave_cleared`, `all_waves_cleared`, and `boss_defeated` — signals that drive GameStateManager to `RUN_SUMMARY`.

At First Playable scope the wave is hardcoded: 3 Drifter (ID 0) + 2 Charger (ID 1) + 5 Cluster (ID 2) = 10 enemies, threat budget 12. WaveManager is a scene node (not an Autoload) — it lives inside the arena scene and is freed when the run ends.

Spawn order is strictly enforced by ADR-0014: `instantiate()` → `register_enemy()` (H&D) → `add_child()` → `set global_position` → `init(type_id)`. Registration must precede `add_child()` so H&D's enemy HP pool is live before `_ready()` fires on the enemy node.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: Signal-Driven Architecture | Connects to GSM `preparation_started`, `combat_started` in `_ready()`; emits `all_waves_cleared`, `boss_defeated` from handler | LOW |
| ADR-0007: HealthAndDamage Singleton | Calls `H&D.register_enemy(enemy, type_id)` before `add_child(enemy)`; tracks kills via `enemy_killed` signal | LOW |
| ADR-0014: H&D ↔ WaveManager Contract | Enforces spawn ordering; kill-signal-only tracking (never polls `_enemy_registry`); reset contract on `preparation_started` | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-WES-001 | WaveManager is the sole emitter of `wave_cleared`, `all_waves_cleared`, `boss_defeated` | ADR-0003 ✅ |
| TR-WES-002 | All enemies spawned via `add_child()` in single loop iteration — same frame; `_enemies_alive = _enemies_total` set atomically | ADR-0014 ✅ |
| TR-WES-003 | Kill tracking: H&D `enemy_killed` → `_enemies_alive -= 1`; `<= 0` guard triggers wave completion | ADR-0014 ✅ |
| TR-WES-004 | Spawn markers are Node2D children of arena scene; WaveManager reads `global_position` at spawn time | ADR-0014 ✅ |
| TR-WES-005 | FP scope: `all_waves_cleared` and `boss_defeated` fire sequentially in same handler after last enemy death | ADR-0014 ✅ |

## Definition of Done

This epic is complete when:
- All stories implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/wave-encounter-system.md` verified
- All Logic stories have passing unit test files; all Integration stories have passing integration test files
- No remaining tech debt items at BLOCKING severity

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Skeleton, Signals, and Phase Gating](story-001-skeleton-phase-gating.md) | Logic | Ready | ADR-0003 |
| 002 | [FP Wave Composition and Spawn Sequence](story-002-fp-composition-spawn.md) | Integration | Ready | ADR-0014 |
| 003 | [Kill Tracking and Wave Completion Signals](story-003-kill-tracking-signals.md) | Logic | Ready | ADR-0014 |
| 004 | [Full FP Run Integration Test](story-004-fp-run-integration.md) | Integration | Ready | ADR-0014 |

## Next Step

Run `/story-readiness production/epics/wave-manager/story-001-skeleton-phase-gating.md` then `/dev-story` to begin implementation.
