# Epic: Player Controller

> **Layer**: Core
> **GDD**: design/gdd/player-controller.md
> **Architecture Module**: `src/gameplay/player_controller.gd`
> **Status**: Ready
> **Stories**: 4 stories created 2026-05-31

## Overview

Implements Fayde's runtime movement, dash, and cast-lock behavior as a `CharacterBody2D` scene. PlayerController owns velocity, position, controller state (DISABLED / ENABLED / DASHING), the `_is_invincible` i-frame flag, dash cooldown accumulator, footstep shuffle-bag, and facing direction. It exposes `is_invincible()`, `get_facing_direction()`, `get_cast_position()`, and `get_controller_state()` for downstream consumers. Movement uses screen-space WASD (not isometric axes) via `Input.get_vector()` and `CharacterBody2D.move_and_slide()`. All timing uses float accumulators per ADR-0004; no Timer nodes.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Isometric View | Screen-space WASD on isometric TileMapLayer; `y_sort_enabled = true` on IsometricRoom | HIGH — TileMapLayer isometric Godot 4.6 |
| ADR-0003: Signal-Driven Architecture | Connect to `combat_started`, `preparation_started`, `cast_hit_started` in `_ready()` | LOW |
| ADR-0004: Float Accumulator Timer | Dash cooldown, i-frame window, footstep timer via `_process(delta)` float accumulators | LOW |
| ADR-0010: Player Group Convention | `add_to_group(&"player")` in `_ready()`; single-player assertion | LOW |
| ADR-0011: StatusEffectsManager API | Exposes `is_alive() -> bool`; `apply_speed_modifier(multiplier)` for Freeze | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-PC-001 | `CharacterBody2D.move_and_slide()` for movement — screen-space cartesian | ADR-0001 ✅ |
| TR-PC-002 | Float accumulators for dash cooldown, i-frame window, footstep timer | ADR-0004 ✅ |
| TR-PC-003 | `PROCESS_MODE_PAUSABLE` — halts on `get_tree().paused = true` | ADR-0004 ✅ |
| TR-PC-004 | Dash i-frame via `_is_invincible: bool`; exposed as `is_invincible() -> bool` | ADR-0007 ✅ |
| TR-PC-005 | Footstep shuffle-bag: 3 variants, anti-consecutive-repeat, pop-from-bag | ADR-0003 ✅ |
| TR-PC-006 | `"player"` group membership; single-player assertion in `_ready()` | ADR-0010 ✅ |
| TR-PC-007 | Listens to `SpellCastingEffects.cast_hit_started(duration)` → CAST_LOCKED sub-state | ADR-0003 ✅ |
| TR-PC-008 | Exposes `get_facing_direction()`, `get_cast_position()` for SC&E targeting | ADR-0009 ✅ |
| TR-PC-009 | `class_name PlayerController` for GUT test scene access | — (test scaffolding — no ADR needed) |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/player-controller.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- Visual/Feel stories have evidence docs in `production/qa/evidence/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Skeleton, Group Registration, State Machine](story-001-skeleton-state-machine.md) | Integration | Ready | ADR-0003 |
| 002 | [WASD Movement and Friction Deceleration](story-002-movement-friction.md) | Logic | Ready | ADR-0001 ⚠️ HIGH |
| 003 | [Dash System, I-Frame, Interface Getters](story-003-dash-system.md) | Logic | Ready | ADR-0004 |
| 004 | [Footstep Shuffle-Bag and Audio Events](story-004-footstep-audio.md) | Logic | Ready | ADR-0003 |

## Next Step

Run `/story-readiness production/epics/player-controller/story-001-skeleton-state-machine.md` then `/dev-story` to begin implementation.
