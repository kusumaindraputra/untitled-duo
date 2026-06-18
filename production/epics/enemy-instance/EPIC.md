# Epic: Enemy Instance

> **Layer**: Core
> **GDD**: design/gdd/enemy-ai.md
> **Architecture Module**: `src/enemies/enemy_instance.gd`
> **Status**: Complete (story-006 visual/feel advisory — QA evidence pending)
> **Stories**: 6 stories created 2026-05-31

## Overview

Implements each enemy's runtime behavior as a `CharacterBody2D` scene with `PROCESS_MODE_PAUSABLE`. Enemy Instance owns velocity, position, archetype behavior state, `_combat_active` flag, contact timer, and enemy state (ALIVE / DEAD). At First Playable scope all three archetypes (SEEKER/RUSHER/SWARMER) use direct vector movement toward Fayde's position and contact-damage via Area2D. Archetype routing scaffolding is in place for MVP/VS behavioral differentiation. WaveManager spawns and inits instances via `init(enemy_type_id)`; Enemy Instance handles all runtime behavior from there. Death sequencing uses `queue_free()` only (never `free()`) to preserve the one-frame node-lifetime guarantee required by H&D Rule 5.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: Signal-Driven Architecture | Connects to GSM `combat_started` / `preparation_started`; listens to H&D `enemy_killed` | LOW |
| ADR-0007: HealthAndDamage Singleton | Calls `H&D.apply_damage(fayde, base_damage, null, CONTACT)` per contact event; uses `queue_free()` for node-lifetime guarantee | LOW |
| ADR-0010: Player Group Convention | `add_to_group(&"enemy")` in `_ready()`; player lookup via `get_first_node_in_group(&"player")` cached at init | LOW |
| ADR-0011: StatusEffectsManager API | Exposes `apply_speed_modifier(multiplier: float)` and `apply_stun(duration: float)` (MVP); exposes `is_alive() -> bool` | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-EAI-001 | `CharacterBody2D` with `PROCESS_MODE_PAUSABLE`; separate `Area2D` hitbox | ADR-0007 ✅ |
| TR-EAI-002 | `init(enemy_type_id)` called by WaveManager after `add_child()` — caches archetype, base_damage, move_speed from EnemyCatalog | ADR-0007 ✅ |
| TR-EAI-003 | FP movement: direct vector to Fayde's position via `move_and_slide()`; degenerate-direction guard | ADR-0010 ✅ |
| TR-EAI-004 | Contact attack: Area2D `body_entered` → `apply_damage()` immediately + `_contact_timer` (0.3s minimum interval) | ADR-0007 ✅ |
| TR-EAI-005 | Phase gating: `_combat_active` flag; `_physics_process` early-returns when false or DEAD | ADR-0003 ✅ |
| TR-EAI-006 | Death: on `enemy_killed` match → DEAD state → AnimationPlayer "death" → `queue_free()` | ADR-0007 ✅ |
| TR-EAI-007 | `add_to_group(&"enemy")` in `_ready()`; must NOT be in `"player"` group | ADR-0010 ✅ |
| TR-EAI-008 | Exposes `apply_speed_modifier(multiplier)` and `apply_stun(duration)` for MVP Status Effects | ADR-0011 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/enemy-ai.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- Visual/Feel stories (death animation, hit flash) have evidence docs in `production/qa/evidence/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Skeleton, Group, init(), Phase Gating](story-001-skeleton-phase-gating.md) | Integration | Ready | ADR-0003 |
| 002 | [FP Movement and Degenerate Direction Guard](story-002-fp-movement.md) | Logic | Ready | ADR-0010 |
| 003 | [Contact Attack and Repeat-Damage Timer](story-003-contact-attack.md) | Logic | Ready | ADR-0007 |
| 004 | [Death Sequencing and Instance ID Guard](story-004-death-sequencing.md) | Integration | Ready | ADR-0007 |
| 005 | [Integration Tests and Status Effects API Stubs](story-005-integration-status-stubs.md) | Integration | Ready | ADR-0011 |
| 006 | [Death Animation Timing](story-006-death-animation-timing.md) | Visual/Feel | Ready *(ADVISORY)* | ADR-0003 |

## Next Step

Run `/story-readiness production/epics/enemy-instance/story-001-skeleton-phase-gating.md` then `/dev-story` to begin implementation.

---

## S3-13 Retro Fix: is_alive() Contract

> **Sprint 3 backlog item** — no dedicated story file. Specs recorded here per QA plan.
> **Test file**: `tests/unit/enemy-instance/enemy_instance_test.gd` (extend existing)
> **Estimated new tests**: 2

**Contract Test 1 — ALIVE state returns true:**
- Given: `enemy_instance` created; `_enemy_state == ALIVE`
- When: `enemy_instance.is_alive()` called
- Then: returns `true`

**Contract Test 2 — DEAD state returns false:**
- Given: `enemy_instance` created; `_enemy_state` set to `DEAD`
- When: `enemy_instance.is_alive()` called
- Then: returns `false`

**Edge case**: `is_alive()` called before `init()` — define and document the behavior, then test it.

**Regression guard**: Run `enemy_instance_skeleton_test.gd` headless ×3 after fix to confirm S3-14 teardown fix has not regressed.
