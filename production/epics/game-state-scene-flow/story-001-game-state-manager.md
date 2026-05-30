# Story 001: GameStateManager — State Machine and Signals

> **Epic**: Game State & Scene Flow
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (4–6 hours)
> **Manifest Version**: 2026-05-30
> **Last Updated**: 2026-05-30

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirements**: `TR-GSF-001`, `TR-GSF-002`, `TR-GSF-005`, `TR-GSF-006`, `TR-GSF-007`, `TR-GSF-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Autoload Architecture and Registration Order
**ADR Decision Summary**: GameStateManager is Autoload position 3 — registered after PranaCatalog and EnemyCatalog, before all signal-subscribing systems. All downstream Autoloads (SceneManager, AudioSystem, etc.) connect to GameStateManager signals in their own `_ready()` safely because GSM is at position 3.

**Secondary ADRs**:
- ADR-0003: Signal-Driven Architecture — GameStateManager emits state-change signals; no downstream system reads `_active_state` directly
- ADR-0004: Float Accumulator Timer Pattern — `preparation_phase_time_limit_sec` timer uses float delta accumulator in `_process(delta)`, not a Timer node

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `get_tree().paused = true` for PAUSED state is unchanged since Godot 4.0. Known Godot 4 Autoload constraint: do not add `class_name GameStateManager` — Godot 4 "hides autoload singleton" parse error when class_name matches Autoload node name. Access via node name only.

**Control Manifest Rules (Foundation Layer)**:
- Required: Register at Autoload position 3 in Project Settings. (ADR-0002)
- Required: No `class_name` declaration on the script — Godot 4 Autoload constraint. (ADR-0002)
- Required: Connect to Autoload signals in `_ready()` only — never in `_init()`. (ADR-0002)
- Required: All in-game timing uses float delta accumulators in `_process(delta)` — no Timer nodes, no `SceneTree.create_timer()`. (ADR-0004)
- Required: Decrement accumulator by `tick_rate`, never reset to 0.0. (ADR-0004)
- Required: Gameplay nodes `PROCESS_MODE_PAUSABLE`; GameStateManager, AudioSystem, CombatHUD `PROCESS_MODE_ALWAYS`. (ADR-0004)
- Forbidden: Never use Timer nodes or `SceneTree.create_timer()` for gameplay timing. (ADR-0004)

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md` (MVP ACs only), scoped to this story:*

**State machine core:**
- [ ] `src/core/game_state_manager.gd` exists — no `class_name` declaration
- [ ] Registered at Autoload position 3 in `project.godot` (TR-GSF-001)
- [ ] `get_active_state() -> GameEnums.GameState` returns correct current state
- [ ] `_active_state` is private — not readable directly by other systems
- [ ] `state_changed(old_state, new_state)` signal emitted on every transition

**6 MVP states and valid transitions (GDD Transition Table):**
- [ ] `MAIN_MENU → PREPARATION_PHASE` on `start_run()` — emits `run_started` first, then `preparation_started(wave_index, waves_remaining)` (AC-03)
- [ ] `start_run()` while already in-run does NOT emit `run_started` again (AC-03b)
- [ ] `PREPARATION_PHASE → COMBAT_PHASE` on valid `arrangement_confirmed` — emits `grid_locked` first, then `combat_started(is_boss: false)` (AC-14 signal ordering)
- [ ] `PREPARATION_PHASE → COMBAT_PHASE` rejected when `is_loadout_valid()` returns false (AC-05)
- [ ] `COMBAT_PHASE → PREPARATION_PHASE` on `wave_cleared` — emits `wave_ended` (AC-10)
- [ ] `COMBAT_PHASE → COMBAT_PHASE` self-transition on `all_waves_cleared` — emits `grid_locked` first, then `combat_started(is_boss: true)` (AC-01)
- [ ] `COMBAT_PHASE → DEATH_SCREEN` on `player_died` — emits: (1) `death_started`, (2) state changes, (3) `run_ended(win: false)` in this order (TR-GSF-008, AC-18)
- [ ] `COMBAT_PHASE → RUN_SUMMARY` on `boss_defeated` — executed via `call_deferred` (TR-GSF-006, AC-01b)
- [ ] `PAUSED → MAIN_MENU` via quit — emits `run_ended(win: false)` (AC-19)
- [ ] **AC-01c**: Same-frame death priority — if `boss_defeated` (deferred) and `player_died` (immediate) fire in same frame, result is `DEATH_SCREEN` not `RUN_SUMMARY`

**Pause/resume (TR-GSF-002):**
- [ ] `PREPARATION_PHASE → PAUSED` and `COMBAT_PHASE → PAUSED` via pause trigger — stores `_previous_state`, calls `get_tree().paused = true`, emits `game_paused` (AC-11)
- [ ] `PAUSED → _previous_state` on resume — restores state, calls `get_tree().paused = false`, emits `game_resumed` (AC-12)
- [ ] Pause not available from `MAIN_MENU`, `RUN_SUMMARY`, `DEATH_SCREEN` — no-op + no signal (AC-13)

**Guards and re-entrancy:**
- [ ] **AC-07**: Re-entrancy guard rejects second `_request_transition()` call while a transition is active — calls `push_error()` with "[GameStateManager]" in message (TR-GSF-005)
- [ ] `COMBAT_PHASE → PREPARATION_PHASE` rejected if not triggered by `_on_wave_cleared()` signal path (AC-04a)

**Preparation timer (TR-GSF-002 implied):**
- [ ] **AC-16**: Timer auto-confirm — when `preparation_phase_time_limit_sec > 0` and timer expires with valid loadout, transitions to `COMBAT_PHASE`
- [ ] **AC-17**: Timer halts on timer expiry with empty grid — state remains `PREPARATION_PHASE`, timer does not resume

**`preparation_started` payload (TR-GSF-007):**
- [ ] Signal carries `wave_index: int` and `waves_remaining: int` on every `PREPARATION_PHASE` entry

---

## Implementation Notes

*Derived from ADR-0002, ADR-0003, ADR-0004 Implementation Guidelines:*

**No `class_name` declaration** — same Godot 4 Autoload constraint as PranaCatalog and EnemyCatalog.

**Core structure:**
```gdscript
extends Node

signal state_changed(old_state: int, new_state: int)
signal run_started()
signal preparation_started(wave_index: int, waves_remaining: int)
signal combat_started(is_boss: bool)
signal grid_locked()
signal grid_hidden()
signal wave_ended()
signal game_paused()
signal game_resumed()
signal death_started()
signal run_ended(win: bool)
signal room_cleared()

var _active_state: GameEnums.GameState = GameEnums.GameState.MAIN_MENU
var _previous_state: GameEnums.GameState = GameEnums.GameState.MAIN_MENU
var _is_transitioning: bool = false
var _wave_index: int = 0
var _waves_remaining: int = 0

# Timer (ADR-0004 — float accumulator, not Timer node)
var _prep_timer_acc: float = 0.0
@export var preparation_phase_time_limit_sec: float = 0.0  # 0 = no limit
```

**Re-entrancy guard** (TR-GSF-005):
```gdscript
func _request_transition(new_state: GameEnums.GameState) -> void:
    if _is_transitioning:
        push_error("[GameStateManager] Re-entrant transition request rejected: %s" % new_state)
        return
    _is_transitioning = true
    _do_transition(new_state)
    _is_transitioning = false
```

**Signal ordering (GDD signal ordering note):**
- `grid_locked` ALWAYS fires before `combat_started` (both `is_boss: false` and `is_boss: true`)
- `run_started` fires before `preparation_started` on `MAIN_MENU → PREPARATION_PHASE`
- `death_started` fires BEFORE state change and BEFORE `run_ended(win: false)`

**Same-frame death priority** (TR-GSF-006):
```gdscript
func _on_boss_defeated() -> void:
    call_deferred("_request_transition", GameEnums.GameState.RUN_SUMMARY)

func _on_player_died() -> void:
    _request_transition(GameEnums.GameState.DEATH_SCREEN)  # immediate — wins
```

**Connect to Health & Damage and WaveManager signals in `_ready()`** — see GDD Consumed Input Events table.

**Pause implementation:**
- `get_tree().paused = true` — GameStateManager has `process_mode = PROCESS_MODE_ALWAYS` (Autoload default)
- Prep timer: `_process(delta)` must check `not get_tree().paused` before advancing accumulator

**Performance**: Negligible — single float comparison per frame in `_process(delta)`; no allocations, no scene queries.

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 002: SceneManager sub-scene swap — `change_room()` implementation and main.tscn setup
- Story 003: IsometricRoom scene — TileMapLayer, Y-sort, spawn markers
- AC-08 (manual HUD walkthrough) — verified as part of Story 002 integration
- AC-04b, AC-06 (CI grep checks) — infrastructure concern, tracked separately

---

## QA Test Cases

*Logic story — automated test specs.*

- **AC-1**: Boss combat self-transition emits correct signals (AC-01)
  - Given: GameStateManager in `COMBAT_PHASE`; test stub simulates wave/encounter
  - When: `_on_all_waves_cleared()` called
  - Then: `get_active_state()` = `COMBAT_PHASE`; `combat_started` emitted with `is_boss: true`; `grid_locked` emitted before `combat_started`
  - Edge cases: State does NOT change to a different value (self-transition only)

- **AC-2**: Boss defeat via deferred transition (AC-01b)
  - Given: `COMBAT_PHASE` with `is_boss: true` simulation
  - When: `_on_boss_defeated()` called; `await get_tree().process_frame`
  - Then: `get_active_state()` = `RUN_SUMMARY`; `run_ended(win: true)` emitted once

- **AC-3**: Same-frame death priority (AC-01c)
  - Given: `COMBAT_PHASE` active
  - When: `_on_boss_defeated()` called then `_on_player_died()` in same frame; `await get_tree().process_frame`
  - Then: `get_active_state()` = `DEATH_SCREEN` (not `RUN_SUMMARY`)
  - Edge cases: `run_ended(win: true)` NOT emitted; `run_ended(win: false)` emitted once

- **AC-4**: Death signal ordering (TR-GSF-008)
  - Given: `COMBAT_PHASE` active; signal order recorder attached
  - When: `_on_player_died()` called
  - Then: signal order is: `death_started` → state changes to `DEATH_SCREEN` → `run_ended(win: false)`
  - Edge cases: `run_ended(win: false)` emitted AFTER state change confirmed

- **AC-5**: `run_started` emitted once on new run (AC-03 / AC-03b)
  - Given: `MAIN_MENU`
  - When: `start_run()` called
  - Then: `run_started` emitted once; `preparation_started` emitted after; state = `PREPARATION_PHASE`
  - Edge cases: Call `start_run()` again while in `PREPARATION_PHASE` → `run_started` NOT emitted again

- **AC-6**: Invalid loadout blocks combat start (AC-05)
  - Given: `PREPARATION_PHASE`; Prana Grid stub returning `is_loadout_valid() = false`
  - When: `_on_arrangement_confirmed()` called
  - Then: state remains `PREPARATION_PHASE`; no `combat_started` signal emitted

- **AC-7**: Re-entrancy guard (AC-07, TR-GSF-005)
  - Given: `PREPARATION_PHASE`; test stub that calls `_request_transition()` from `state_changed` handler
  - When: first transition fires
  - Then: second `_request_transition()` is rejected; `push_error()` called with "[GameStateManager]"; final state = first transition's target

- **AC-8**: Pause/resume cycle (AC-11 / AC-12)
  - Given: `COMBAT_PHASE` active
  - When: pause triggered
  - Then: `game_paused` emitted; `get_active_state()` = `PAUSED`; `_previous_state` = `COMBAT_PHASE`
  - When: resume triggered
  - Then: `game_resumed` emitted; `get_active_state()` = `COMBAT_PHASE`

- **AC-9**: Pause unavailable from menu states (AC-13)
  - Given: `MAIN_MENU` (or `RUN_SUMMARY` / `DEATH_SCREEN`)
  - When: pause triggered
  - Then: state unchanged; `game_paused` NOT emitted

- **AC-10**: Wave cleared cycle (AC-10)
  - Given: `COMBAT_PHASE`; `waves_remaining > 0` stub
  - When: `_on_wave_cleared()` called
  - Then: state = `PREPARATION_PHASE`; `wave_ended` emitted

- **AC-11**: `preparation_started` payload (TR-GSF-007)
  - Given: run in progress with `wave_index = 2`, `waves_remaining = 1`
  - When: state enters `PREPARATION_PHASE`
  - Then: `preparation_started` emitted with `wave_index = 2`, `waves_remaining = 1`

- **AC-12**: Timer auto-confirm (AC-16 / AC-17)
  - Given: `preparation_phase_time_limit_sec = 5.0`; `PREPARATION_PHASE`; loadout valid stub
  - When: `_process(5.01)` called (timer elapsed)
  - Then: state = `COMBAT_PHASE`
  - Edge case: Same setup but loadout invalid → state remains `PREPARATION_PHASE`; timer halted

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/game-state-scene-flow/game_state_manager_test.gd` — must exist and all tests pass

**Status**: [x] Created — `tests/unit/game-state-scene-flow/game_state_manager_test.gd` — 29/29 PASSED (GdUnit4 v6.1.3, Godot 4.6.2, 2026-05-30)

---

## Dependencies

- Depends on: Prana Data Story 001 (`production/epics/prana-data/story-001-game-enums-pure-container.md` — GameEnums, Complete); Prana Data Story 003 (`production/epics/prana-data/story-003-prana-catalog-autoload.md` — PranaCatalog Autoload position 1, Complete); Enemy Data Story 002 (`production/epics/enemy-data/story-002-enemy-catalog-autoload.md` — EnemyCatalog Autoload position 2, Complete)
- Unlocks: Story 002 — SceneManager (must connect to GameStateManager signals in its `_ready()`); all downstream systems that connect to GSM signals

---

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 20/20 passing (1 deferred: Autoload registration — applied during story-done review)
**Deviations**: Autoload position 3 not registered at dev-story time — fixed in `project.godot` before story close. No other deviations.
**Test Evidence**: Logic — `tests/unit/game-state-scene-flow/game_state_manager_test.gd` — 29/29 PASSED. (3 timer tests fixed: `add_child(gsm)` required for `is_inside_tree()` to return true in `_tick_prep_timer`.)
**Code Review**: Complete — approved with suggestions
