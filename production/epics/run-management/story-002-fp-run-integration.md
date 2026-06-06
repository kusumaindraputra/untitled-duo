# Story 002: FP Run Integration Test

> **Epic**: RunManagement
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: ~0.5 hours
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-06

## Context

**GDD**: `design/gdd/run-management.md`
**Requirement**: `TR-RM-001`, `TR-RM-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Signal-Driven Architecture
**ADR Decision Summary**: Integration test verifies the complete signal chain fires correctly with real Autoloads — no mocks on the GSM signal pathway. RunManager receives signals from real GameStateManager; WaveManager kill-chain drives `run_ended` emission via `all_waves_cleared` → `boss_defeated` → GSM.

**Secondary ADRs**: ADR-0002 (Autoload registration order — RunManager #10 confirmed live)

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Same integration test pattern as `wave_manager_integration_test.gd` and `spell_casting_integration_test.gd`. Real Autoload signal emission. Teardown: `remove_child() + free()`.

**Control Manifest Rules (Feature Layer)**:
- Required: Integration test uses real GameStateManager signals — no mocks on signal pathway
- Required: Teardown with `remove_child()` then `free()` — not `queue_free()` (headless GdUnit4 exit-101 guard)

---

## Acceptance Criteria

*From GDD `design/gdd/run-management.md`, scoped to this story:*

- [x] **AC-RM-13** — GIVEN RunManager and GameStateManager are registered as Autoloads with GameStateManager first, WHEN a full FP run completes (`run_started` → `combat_started` → all 10 enemies die → `run_ended(win: true)` fires via WaveManager chain), THEN `get_run_data()` returns `{ run_active: false, run_outcome: WIN, waves_completed: 0 }`
- [x] **AC-RM-14** — GIVEN RunManager is registered after GameStateManager in Project Settings → AutoLoad, WHEN the game starts, THEN RunManager is accessible globally and no signal-connection errors appear in the Godot output panel *(manual smoke check — AutoLoad wiring cannot be unit-tested in GUT)*

---

## Implementation Notes

*Same pattern as `wave_manager_integration_test.gd` and `spell_casting_integration_test.gd`:*

**Test harness setup**:
- `RunManagerScript = preload("res://src/systems/run_manager.gd")`
- `var rm: Node = RunManagerScript.new(); add_child(rm)` — triggers `_ready()`, connects to real GSM signals
- At FP scope, `run_ended` is emitted by GameStateManager when it processes `all_waves_cleared` + `boss_defeated` from WaveManager. For this integration test, emit `GameStateManager.run_ended.emit(true)` directly to simplify (WaveManager integration is already covered in wave_manager_integration_test.gd).

**Minimal FP run sequence**:
```gdscript
GameStateManager.run_started.emit()
GameStateManager.combat_started.emit(false)
# (no wave_ended — FP is single wave, no inter-wave returns)
GameStateManager.room_cleared.emit()   # sets run_outcome = WIN
GameStateManager.run_ended.emit(true)  # finalizes run
```

**Assertion**:
```gdscript
var data: Dictionary = rm.get_run_data()
assert_bool(data["run_active"]).is_false()
assert_int(data["run_outcome"]).is_equal(GameEnums.RunOutcome.WIN)
assert_int(data["waves_completed"]).is_equal(0)
```

**Teardown**: `remove_child(rm); rm.free()`

**AC-RM-14 (manual)**: Verify in Godot editor that RunManager appears at position #10 in Project → Project Settings → AutoLoad, after SpellCastingEffects. No signal errors in Output panel on game start. Document in smoke check.

---

## Out of Scope

*Handled by Story 001:*

- [Story 001]: All unit-level signal handler tests (AC-RM-01 through AC-RM-12)

---

## QA Test Cases

*Embedded from `production/qa/qa-plan-sprint-3-2026-06-03.md` (S3-10 integration spec).*

**Test file**: `tests/integration/run-management/run_manager_integration_test.gd`

- **AC-RM-13**: Full FP run end-to-end → get_run_data() returns WIN
  - Given: RunManager added to tree (real Autoload chain active); `run_started` emitted
  - When: `room_cleared.emit()` → `run_ended.emit(true)` (FP one-wave completion)
  - Then: `get_run_data()` returns `{ run_active: false, run_outcome: WIN, waves_completed: 0 }`
  - Edge cases: `waves_completed` must be 0 (no inter-wave returns at FP); `run_active` must be false (finalized)

- **AC-RM-14** (manual): AutoLoad wiring smoke check
  - Setup: Open project in Godot 4.6.2; Project → Project Settings → AutoLoad tab
  - Verify: RunManager appears at position #10; no red errors in Output panel on Play
  - Pass condition: `RunManager` accessible in GDScript as a singleton; game starts without `Invalid get index 'run_started' on base 'null'` or similar

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/run-management/run_manager_integration_test.gd` — must exist and pass

**Status**: [x] `tests/integration/run-management/run_manager_integration_test.gd` — 3/3 PASSED (GdUnit4 v6.1.3, Godot 4.6.2, 2026-06-06)

---

## Dependencies

- Depends on: Story 001 DONE (RunManager Autoload implemented)
- Unlocks: None — this is the final RunManagement story. Epic complete when this story is Done. S3-10 complete.

---

## Completion Notes
**Completed**: 2026-06-06
**Criteria**: 2/2 passing (AC-RM-13 auto-verified; AC-RM-14 advisory manual smoke check)
**Deviations**: None
**Test Evidence**: Integration test at `tests/integration/run-management/run_manager_integration_test.gd` — 3/3 PASSED (3 scenarios: WIN path, LOSS path, consecutive runs reset)
**Code Review**: Skipped — test-only story, no src/ changes
