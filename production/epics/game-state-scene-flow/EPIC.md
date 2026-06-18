# Epic: Game State & Scene Flow

> **Layer**: Foundation
> **GDD**: design/gdd/game-state-scene-flow.md
> **Architecture Module**: GameStateManager + SceneManager + IsometricRoom
> **Status**: Complete
> **Stories**: 3 stories

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [GameStateManager — State Machine and Signals](story-001-game-state-manager.md) | Logic | Ready | ADR-0002 |
| 002 | [SceneManager and main.tscn Infrastructure](story-002-scene-manager.md) | Integration | Ready | ADR-0005 |
| 003 | [IsometricRoom Scene Root](story-003-isometric-room.md) | Integration | Blocked | ADR-0001 |

## Overview

Implements the state machine backbone that all other systems plug into, the scene-swap infrastructure that transitions between arena rooms without re-instantiating the persistent HUD, and the isometric arena root scene that TileMapLayer and spawn markers live in. GameStateManager owns the 6-state MVP machine (MAIN_MENU → PREPARATION_PHASE ↔ COMBAT_PHASE → DEATH_SCREEN / RUN_SUMMARY, PAUSED) and emits all lifecycle signals. SceneManager handles sub-scene swap via `await process_frame` between `queue_free()` and `add_child()`. IsometricRoom wraps TileMapLayer + Y-sort and exposes spawn marker positions via `get_spawn_markers()`.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Isometric View | TileMapLayer + `TILE_SHAPE_ISOMETRIC` + `y_sort_enabled` wrapper — validation test required before implementation | HIGH |
| ADR-0002: Autoload Architecture | GameStateManager #3, SceneManager #4 in Autoload registration order | LOW |
| ADR-0003: Signal-Driven Architecture | All systems communicate via GSM signals — no direct typed references between systems | LOW |
| ADR-0004: Float Accumulator Timer | All gameplay timers use delta accumulators in `_process(delta)` — `PROCESS_MODE_PAUSABLE` | LOW |
| ADR-0005: Persistent HUD Sub-Scene Swap | CanvasLayer (layer 10) on permanent `main.tscn` root; sub-scene swap preserves HUD | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-GSF-001 | GameStateManager is Autoload singleton — position 3 in AutoLoad order | ADR-0002 ✅ (implicit) |
| TR-GSF-002 | Pause via `get_tree().paused = true` — `PROCESS_MODE_PAUSABLE` gameplay, `ALWAYS` Autoloads | ADR-0003 ✅ |
| TR-GSF-003 | `await get_tree().process_frame` between `queue_free()` and `add_child()` in `SceneManager.change_room()` | ❌ No ADR — acceptance criterion on story |
| TR-GSF-004 | Persistent HUD via CanvasLayer (layer 10) on permanent `main.tscn` root | ❌ No ADR — ADR-0005 intent; acceptance criterion on story |
| TR-GSF-005 | Re-entrancy guard on `_request_transition()` — second call during active transition rejected with `push_error()` | ❌ No ADR — acceptance criterion on story |
| TR-GSF-006 | `call_deferred()` for `boss_defeated → RUN_SUMMARY` transition — same-frame `player_died` takes priority | ❌ No ADR — acceptance criterion on story |
| TR-GSF-007 | `preparation_started` signal carries payload: `wave_index: int`, `waves_remaining: int` | ADR-0005 ✅ |
| TR-GSF-008 | `death_started` is first signal in `COMBAT_PHASE → DEATH_SCREEN` handler — before state change and `run_ended` | ADR-0002 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/game-state-scene-flow.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- ADR-0001 validation test project passes (TileMapLayer isometric + Compatibility renderer confirmed in Godot 4.6) — **must complete before any IsometricRoom story is picked up**
- State machine transition table fully covered by GUT tests (all 6 states, valid + invalid transitions)
- Re-entrancy guard verified: calling `_request_transition()` twice in same frame produces exactly one `push_error()` and no double-transition
- Same-frame death priority verified: `player_died` + `all_waves_cleared` in same frame → DEATH_SCREEN wins over RUN_SUMMARY

## Next Step

Run `/create-stories game-state-scene-flow` to break this epic into implementable stories.
**Note**: Tag IsometricRoom stories as BLOCKED until ADR-0001 validation test passes.
