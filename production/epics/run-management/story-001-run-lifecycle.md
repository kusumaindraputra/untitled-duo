# Story 001: RunManager Autoload — Run Lifecycle and get_run_data()

> **Epic**: RunManagement
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: ~1.5 hours
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-06

## Context

**GDD**: `design/gdd/run-management.md`
**Requirement**: `TR-RM-001`, `TR-RM-002`, `TR-RM-003`, `TR-RM-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Autoload Architecture (primary) + ADR-0003: Signal-Driven Architecture (secondary)
**ADR Decision Summary**: RunManager is Autoload #10 — registered after GameStateManager in project.godot; connects to `run_started`, `wave_ended`, `room_cleared`, `run_ended` in `_ready()` and disconnects in `_exit_tree()`. No `_process()` loop. `get_run_data()` returns a copy of the internal dict — callers cannot mutate RunManager state.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: No post-cutoff APIs. Autoload system unchanged since Godot 4.0. Signal-connection pattern identical to all other Autoloads in this project.

**Control Manifest Rules (Feature Layer)**:
- Required: Signal consumer only — no `_process()` loop, no `_request_transition()` calls
- Required: All state updates via GSM signal connections in `_ready()` (ADR-0003 Pattern 1)
- Required: Disconnect from all signals in `_exit_tree()` (ADR-0003 Rule 4)
- Required: `get_run_data()` returns a Dictionary copy (`.duplicate()`) — not a reference
- Required: No class_name — Autoload node name collision guard (same as other Autoloads)

---

## Acceptance Criteria

*From GDD `design/gdd/run-management.md`, scoped to this story:*

- [x] **AC-RM-01** — GIVEN `run_started` fires, WHEN RunManager processes it, THEN `run_active = true`, `run_outcome = NONE`, `waves_completed = 0`
- [x] **AC-RM-02** — GIVEN `run_started` fires while `run_active` is already `true`, WHEN processed, THEN fields reset (`run_active=true`, `run_outcome=NONE`, `waves_completed=0`) AND `push_error()` called with message containing `"[RunManager]"`
- [x] **AC-RM-03** — GIVEN a run is active, WHEN `wave_ended` fires 3 times, THEN `waves_completed = 3` AND `get_run_data()["waves_completed"] == 3`
- [x] **AC-RM-04** — GIVEN a run is active and `run_outcome = NONE`, WHEN `room_cleared` fires, THEN `run_outcome = WIN` and `run_active` remains `true`; second `room_cleared` keeps `run_outcome = WIN` (idempotent, no error)
- [x] **AC-RM-05** — GIVEN `run_outcome = WIN` (from `room_cleared`), WHEN `run_ended(win: true)` fires, THEN `run_active = false` and `run_outcome = WIN`
- [x] **AC-RM-06** — GIVEN `run_outcome = NONE` (no `room_cleared` fired), WHEN `run_ended(win: false)` fires, THEN `run_active = false` and `run_outcome = LOSS`
- [x] **AC-RM-07** — GIVEN `run_outcome = WIN` (from `room_cleared`), WHEN `run_ended(win: false)` fires, THEN `run_active = false` AND `run_outcome` remains `WIN` — Rule 7 conditional guard does NOT overwrite WIN with LOSS
- [x] **AC-RM-08** — GIVEN `run_active = false`, WHEN `run_ended` fires, THEN `push_error()` called with message containing `"[RunManager]"` AND `run_active` remains `false`
- [x] **AC-RM-09** — GIVEN `run_ended` has fired, WHEN `get_run_data()` called, THEN returned Dictionary has keys `"run_active"`, `"run_outcome"`, `"waves_completed"` with finalized values
- [x] **AC-RM-10** — GIVEN `run_active = true` (mid-run), WHEN `get_run_data()` called, THEN `run_active = true` and `run_outcome = NONE` in returned dict
- [x] **AC-RM-11** — GIVEN `get_run_data()` returns a Dictionary, WHEN caller modifies any field, THEN RunManager's internal fields are unchanged (copy semantics)
- [x] **AC-RM-12** — GIVEN `wave_ended` fires while `run_active = false`, WHEN processed, THEN `waves_completed` incremented AND `push_error()` called with `"[RunManager]"`

---

## Implementation Notes

*Derived from ADR-0002 and ADR-0003:*

**File**: `src/systems/run_manager.gd`
**Autoload registration**: Project Settings → AutoLoad #10 (after SpellCastingEffects #9)
**No class_name**: Godot 4 rejects `class_name RunManager` — node name collision. Access via `RunManager.get_run_data()`.

**RunOutcome enum** — use `GameEnums.RunOutcome` (already defined in `src/data/game_enums.gd`). Values: NONE=0, WIN=1, LOSS=2.

**Signal connections in _ready()**:
```gdscript
GameStateManager.run_started.connect(_on_run_started)
GameStateManager.wave_ended.connect(_on_wave_ended)
GameStateManager.room_cleared.connect(_on_room_cleared)
GameStateManager.run_ended.connect(_on_run_ended)
```

**_on_run_ended(win: bool)** — Rule 7 conditional: only set LOSS if `win == false AND _run_outcome == NONE`. If `_run_outcome` is already WIN (from `room_cleared`), do not overwrite.

**get_run_data()** — return `{ "run_active": _run_active, "run_outcome": _run_outcome, "waves_completed": _waves_completed }.duplicate()`. `.duplicate()` ensures copy semantics. Shallow copy is sufficient — all values are primitives.

**_exit_tree()** — disconnect all four signals with `is_connected()` guards (ADR-0003 Rule 4).

**Test pattern** — RunManager is an Autoload; tests must use `preload()` + `add_child()` (not `new()` directly):
```gdscript
const RunManagerScript = preload("res://src/systems/run_manager.gd")
var rm: Node = RunManagerScript.new()
add_child(rm)
```
Emit real GameStateManager signals in tests — do NOT mock GameStateManager. Teardown: `remove_child(rm); rm.free()`.

**GdUnit4 error watcher** — for ACs that check `push_error()`:
```gdscript
assert_error(rm).is_push_error_emitted("[RunManager]")
```
Or use the pattern established in prior stories (capture error via signal watcher).

---

## Out of Scope

*Handled by Story 002:*

- [Story 002]: Full FP run integration test (real Autoload signal chain end-to-end)
- [Story 002]: Manual AutoLoad registration smoke check (AC-RM-14)

---

## QA Test Cases

*Embedded from `production/qa/qa-plan-sprint-3-2026-06-03.md` (S3-10 specs).*

**Test file**: `tests/unit/run-management/run_manager_test.gd`

- **AC-RM-01**: run_started resets all fields
  - Given: RunManager added to tree (initial state: `run_active=false`, `run_outcome=NONE`, `waves_completed=0`)
  - When: `GameStateManager.run_started.emit()`
  - Then: `rm._run_active == true`, `rm._run_outcome == GameEnums.RunOutcome.NONE`, `rm._waves_completed == 0`

- **AC-RM-02**: run_started while active → reset + push_error
  - Given: `rm._run_active = true` (manual set); `rm._waves_completed = 2`
  - When: `GameStateManager.run_started.emit()`
  - Then: fields reset to active/NONE/0 AND `push_error()` called with `"[RunManager]"` in message

- **AC-RM-03**: wave_ended × 3 → waves_completed = 3 and get_run_data() reflects it
  - Given: run active (`run_started` fired)
  - When: `GameStateManager.wave_ended.emit()` × 3
  - Then: `rm._waves_completed == 3`; `rm.get_run_data()["waves_completed"] == 3`

- **AC-RM-04**: room_cleared → WIN; idempotent second call
  - Given: run active (`run_outcome=NONE`)
  - When: `GameStateManager.room_cleared.emit()`
  - Then: `rm._run_outcome == WIN`; `rm._run_active == true`; second `room_cleared.emit()` → outcome stays WIN

- **AC-RM-05**: run_ended(true) after room_cleared → active=false, outcome=WIN
  - Given: `room_cleared` fired (outcome=WIN)
  - When: `GameStateManager.run_ended.emit(true)`
  - Then: `rm._run_active == false`; `rm._run_outcome == WIN`

- **AC-RM-06**: run_ended(false) with NONE outcome → LOSS
  - Given: run active, no `room_cleared`
  - When: `GameStateManager.run_ended.emit(false)`
  - Then: `rm._run_active == false`; `rm._run_outcome == LOSS`

- **AC-RM-07**: run_ended(false) after WIN does NOT overwrite to LOSS
  - Given: `room_cleared` fired (outcome=WIN); `run_ended(false)` fires (wrong signal — should not occur in normal play)
  - When: `GameStateManager.run_ended.emit(false)`
  - Then: `rm._run_active == false`; `rm._run_outcome == WIN` (guard prevents WIN→LOSS overwrite)
  - Edge cases: this tests the `if win == false and _run_outcome == NONE` conditional branch

- **AC-RM-08**: run_ended with no active run → push_error; run_active stays false
  - Given: `rm._run_active = false` (initial state)
  - When: `GameStateManager.run_ended.emit(false)`
  - Then: `push_error()` called with `"[RunManager]"`; `rm._run_active == false`

- **AC-RM-09**: get_run_data() post-run → complete dict with correct keys and values
  - Given: `run_started` → `room_cleared` → `run_ended(true)` fired
  - When: `rm.get_run_data()` called
  - Then: dict has `"run_active"` (false), `"run_outcome"` (WIN), `"waves_completed"` (0)

- **AC-RM-10**: get_run_data() mid-run → run_active=true, outcome=NONE
  - Given: `run_started` fired, run in progress
  - When: `rm.get_run_data()` called
  - Then: `result["run_active"] == true`; `result["run_outcome"] == NONE`

- **AC-RM-11**: get_run_data() returns a copy — mutation doesn't affect internal state
  - Given: `run_started` fired
  - When: `var d = rm.get_run_data(); d["run_active"] = false; d["waves_completed"] = 99`
  - Then: `rm._run_active == true`; `rm._waves_completed == 0` (internal unchanged)

- **AC-RM-12**: wave_ended while inactive → increment + push_error
  - Given: `rm._run_active = false` (no active run)
  - When: `GameStateManager.wave_ended.emit()`
  - Then: `rm._waves_completed == 1` AND `push_error()` called with `"[RunManager]"`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/run-management/run_manager_test.gd` — must exist and pass

**Status**: [x] 13/13 PASSED — GdUnit4 v6.1.3, Godot 4.6.2, 0 orphans, 0 failures (2026-06-06)

---

## Dependencies

- Depends on: GameStateManager (Story 001 Game State & Scene Flow — DONE); GameEnums (Prana Data Story 001 — DONE)
- Unlocks: Story 002 — FP Run Integration Test
