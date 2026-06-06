# Epic: RunManagement

> **Layer**: Feature
> **GDD**: design/gdd/run-management.md
> **Architecture Module**: `src/systems/run_manager.gd`
> **Status**: Ready
> **Stories**: 2 stories created 2026-06-06

## Overview

Implements the run lifecycle tracker for The Last Cipher. RunManager is Autoload #10 — the last registered singleton, connecting to GameStateManager signals at `_ready()`. It tracks three fields across a run: `run_active`, `run_outcome` (NONE/WIN/LOSS), and `waves_completed`. At FP scope, it records the single-wave result and exposes `get_run_data()` for result screen consumption.

RunManager is intentionally minimal — pure signal consumer, no `_process()` loop, no state machine. All transitions are driven by GameStateManager signals. It never calls `_request_transition()` or mutates game state. `get_run_data()` returns a copy — downstream screens cannot mutate RunManager internals.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0002: Autoload Architecture | RunManager is Autoload #10 — registered after GameStateManager; connects to GSM signals in `_ready()` | LOW |
| ADR-0003: Signal-Driven Architecture | Pure signal consumer — Pattern 1; connects in `_ready()`, disconnects in `_exit_tree()` | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-RM-001 | RunManager Autoload #10 — persists run state (run_active, run_outcome, waves_completed) across scene transitions | ADR-0002 ✅ |
| TR-RM-002 | get_run_data() -> Dictionary returns a copy — callers cannot mutate RunManager internal state | ADR-0003 ✅ |
| TR-RM-003 | RunManager registered after GameStateManager in AutoLoad order — connects to GSM signals in _ready() | ADR-0002 ✅ |
| TR-RM-004 | No _process() loop — all state updates via GSM signal connections (run_started, wave_ended, room_cleared, run_ended) | ADR-0003 ✅ |

## Definition of Done

This epic is complete when:
- All stories implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/run-management.md` verified
- Logic story has passing unit test file; Integration story has passing integration test file
- RunManager registered as Autoload #10 in project.godot

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [RunManager Autoload — Run Lifecycle and get_run_data()](story-001-run-lifecycle.md) | Logic | Ready | ADR-0002, ADR-0003 |
| 002 | [FP Run Integration Test](story-002-fp-run-integration.md) | Integration | Ready | ADR-0003 |

## Next Step

Run `/story-readiness production/epics/run-management/story-001-run-lifecycle.md` then `/dev-story` to begin implementation.
