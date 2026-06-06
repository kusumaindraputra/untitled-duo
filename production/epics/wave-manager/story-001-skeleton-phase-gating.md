# Story 001: Skeleton, Signals, and Phase Gating

> **Epic**: WaveManager
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: ~2 hours
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-06

## Context

**GDD**: `design/gdd/wave-encounter-system.md`
**Requirement**: `TR-WES-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Signal-Driven Architecture
**ADR Decision Summary**: Systems announce events via signals; method calls are for instructions. Connect to signals in `_ready()`. Scene nodes disconnect from Autoload signals in `_exit_tree()`.

**Secondary ADR**: ADR-0014: H&D ↔ WaveManager Contract — wave reset contract and `combat_started(is_boss: true)` guard defined here.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Signal connection via Callable syntax only (`signal.connect(callable)`); string-based `connect()` forbidden since Godot 4.0.

**Control Manifest Rules (Feature Layer)**:
- Required: WaveManager tracks wave completion exclusively via `HealthAndDamage.enemy_killed` signal — never polls `_enemy_registry` directly
- Required: Signal declarations on the WaveManager node; `GameStateManager` connects to them at `_ready()`
- Forbidden: Never use string-based signal connections

---

## Acceptance Criteria

*From GDD `design/gdd/wave-encounter-system.md`, scoped to this story:*

- [ ] **AC-WES-SKEL** — GIVEN the WaveManager node is added to the scene tree, WHEN `_ready()` completes, THEN `_wave_state == IDLE`, `_enemies_alive == 0`, `_enemies_total == 0`, and signals `wave_cleared`, `all_waves_cleared`, `boss_defeated` are declared and connectable on the WaveManager node.
- [ ] **AC-WES-12** — GIVEN `_wave_state = WAVE_ACTIVE`, WHEN `combat_started(is_boss: true)` fires, THEN `_wave_state` remains `WAVE_ACTIVE`, no enemies are spawned, and a debug warning is logged.
- [ ] **AC-WES-13** — GIVEN `_wave_state = WAVE_COMPLETE` from a finished run, WHEN `preparation_started` fires (next run start), THEN `_enemies_alive = 0`, `_enemies_total = 0`, `_wave_state = IDLE`. System is ready for the next spawn.

---

## Implementation Notes

*Derived from ADR-0003 and ADR-0014:*

**Node class skeleton:**
```gdscript
class_name WaveManager
extends Node

enum WaveState { IDLE = 0, WAVE_ACTIVE = 1, WAVE_COMPLETE = 2 }

signal wave_cleared
signal all_waves_cleared
signal boss_defeated

var _wave_state: WaveState = WaveState.IDLE
var _enemies_alive: int = 0
var _enemies_total: int = 0
var _wave_composition: Array = []

func _ready() -> void:
    GameStateManager.preparation_started.connect(_on_preparation_started)
    GameStateManager.combat_started.connect(_on_combat_started)
    HealthAndDamage.enemy_killed.connect(_on_enemy_killed)

func _exit_tree() -> void:
    if GameStateManager.preparation_started.is_connected(_on_preparation_started):
        GameStateManager.preparation_started.disconnect(_on_preparation_started)
    if GameStateManager.combat_started.is_connected(_on_combat_started):
        GameStateManager.combat_started.disconnect(_on_combat_started)
    if HealthAndDamage.enemy_killed.is_connected(_on_enemy_killed):
        HealthAndDamage.enemy_killed.disconnect(_on_enemy_killed)
```

**Phase gating handlers:**
```gdscript
func _on_preparation_started(_wave_index: int, _waves_remaining: int) -> void:
    _enemies_alive = 0
    _enemies_total = 0
    _wave_state = WaveState.IDLE

func _on_combat_started(is_boss: bool) -> void:
    if is_boss:
        push_warning("WaveManager: combat_started(is_boss:true) received while wave active — FP scope guard")
        return
    _spawn_wave()
```

`_spawn_wave()` is implemented in Story 002. This story only establishes the skeleton and handler stubs.

**Signal declarations**: Declare `wave_cleared`, `all_waves_cleared`, `boss_defeated` as `signal` on the WaveManager node. `wave_cleared` is unused at FP scope (only one wave); declare it for forward-compatibility.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 002]: `_spawn_wave()` body — FP composition constants, spawn loop, marker lookup
- [Story 003]: `_on_enemy_killed()` body — kill tracking, completion check, signal emission

---

## QA Test Cases

*Written by QA lead at story creation. Implement against these — do not invent new test cases.*

**Test file**: `tests/unit/wave-encounter-system/wave_manager_skeleton_test.gd`

- **AC-WES-SKEL**: Initial state invariant
  - Given: WaveManager instantiated with `.new()` and added to a test scene tree
  - When: `_ready()` completes
  - Then: `_wave_state == WaveState.IDLE`; `_enemies_alive == 0`; `_enemies_total == 0`; `wave_cleared`, `all_waves_cleared`, and `boss_defeated` signals exist on the node (verify via `node.has_signal("wave_cleared")` etc.)
  - Edge cases: Instantiate without calling `_ready()` manually — verify defaults are set by variable declarations, not only by `_ready()`

- **AC-WES-12**: `combat_started(is_boss: true)` guard
  - Given: WaveManager added to scene tree; `_wave_state` manually set to `WAVE_ACTIVE`; `_on_combat_started` stub wired (Story 002 not yet present — `_spawn_wave()` is a no-op stub)
  - When: `_on_combat_started(true)` called
  - Then: `_wave_state` remains `WAVE_ACTIVE`; `_enemies_alive` unchanged; `push_warning()` (or equivalent debug log) was emitted
  - Edge cases: Call with `is_boss: false` when `_wave_state = IDLE` → `_spawn_wave()` stub called (no crash)

- **AC-WES-13**: `preparation_started` resets state
  - Given: WaveManager with `_wave_state = WAVE_COMPLETE`, `_enemies_alive = 3`, `_enemies_total = 10`
  - When: `_on_preparation_started(0, 0)` called
  - Then: `_enemies_alive == 0`, `_enemies_total == 0`, `_wave_state == WaveState.IDLE`
  - Edge cases: Call `preparation_started` when already `IDLE` → no crash; state remains `IDLE`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/wave-encounter-system/wave_manager_skeleton_test.gd` — must exist and pass

**Status**: [x] PASSED — 14/14 tests, GdUnit4 v6.1.3 + Godot 4.6.2, 0 orphans (2026-06-06)

---

## Dependencies

- Depends on: None
- Unlocks: Story 002 (spawn loop needs the skeleton node + signal handlers), Story 003 (kill handler needs the skeleton)

## Completion Notes

**Completed**: 2026-06-06
**Criteria**: 3/3 passing
**Deviations**:
- ADVISORY: `_on_enemy_killed` param typed as `GameEnums.DamageClass` (story pseudocode said `int`) — correct type-safe choice matching actual signal declaration
- ADVISORY: `_wave_composition` typed as `Array[Dictionary]` with Story 002 TODO (story skeleton said untyped `Array`) — improvement applied during code review
**Test Evidence**: Logic — `tests/unit/wave-encounter-system/wave_manager_skeleton_test.gd` — 14/14 PASSED headless
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (all required changes applied)
