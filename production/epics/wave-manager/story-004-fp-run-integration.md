# Story 004: Full FP Run Integration Test

> **Epic**: WaveManager
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: ~2 hours
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-06

## Context

**GDD**: `design/gdd/wave-encounter-system.md`
**Requirement**: `TR-WES-001`, `TR-WES-003`, `TR-WES-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0014: H&D ↔ WaveManager Integration Contract
**ADR Decision Summary**: The full lifecycle — `preparation_started` reset → `combat_started(false)` spawn → 10 × `enemy_killed` → `all_waves_cleared` + `boss_defeated` — is the authoritative contract. When `player_died` fires mid-wave, WaveManager must NOT emit completion signals.

**Secondary ADR**: ADR-0003: Signal-Driven Architecture — integration tests verify end-to-end signal flow across real Autoload connections.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Integration tests require the full Autoload chain (GameStateManager, HealthAndDamage) to be available. Use `add_child(autoload_node)` + `await get_tree().process_frame` pattern as established by existing integration tests in `tests/integration/status-effects/`.

**Control Manifest Rules (Feature Layer)**:
- Required: WaveManager spawn order confirmed end-to-end
- Required: `all_waves_cleared` and `boss_defeated` signal emission counts verified (exactly 1 each)
- Forbidden: Wave completion signals must NOT fire on `player_died` path

---

## Acceptance Criteria

*From GDD `design/gdd/wave-encounter-system.md`, scoped to this story:*

- [ ] **AC-WES-14** — Full FP run flow: (1) `preparation_started` fires → state = IDLE; (2) `combat_started(is_boss: false)` fires → 10 enemies spawned, `_wave_state = WAVE_ACTIVE`; (3) 10 × `enemy_killed` signals received → `_enemies_alive` reaches 0 → `all_waves_cleared` emitted → `boss_defeated` emitted → `_wave_state = WAVE_COMPLETE`. Verify signal emission counts: `all_waves_cleared` exactly 1, `boss_defeated` exactly 1.
- [ ] **AC-WES-15** — GIVEN Fayde dies (H&D emits `player_died`) while `_wave_state = WAVE_ACTIVE`, WHEN the run ends and GS&SF transitions to `DEATH_SCREEN`, THEN Wave Manager does not emit `all_waves_cleared` or `boss_defeated`. Enemy nodes are freed by scene unload; WaveManager state is reset on next `preparation_started`.

---

## Implementation Notes

*This story adds no new production code — it writes the integration test that proves Stories 001–003 work together with real Autoloads.*

**Test harness setup**: Follow the pattern from `tests/integration/status-effects/sem_cleanup_integration_test.gd`:
- Use real `HealthAndDamage` and `GameStateManager` Autoloads
- Create a minimal scene with WaveManager + 10 spawn marker Node2Ds + mock EnemyInstance nodes
- Mock EnemyInstance must respond to `init(type_id)` and `is_alive()` without crashing

**AC-WES-14 test outline**:
```
1. Emit GameStateManager.preparation_started(0, 1)
2. Assert _wave_state == IDLE
3. Emit GameStateManager.combat_started(false)
4. Assert child_count() == 10; _enemies_alive == 10; _wave_state == WAVE_ACTIVE
5. For i in 10: emit HealthAndDamage.enemy_killed(i, 0, DamageClass.NONE)
6. Assert all_waves_cleared.emit_count == 1
7. Assert boss_defeated.emit_count == 1
8. Assert _wave_state == WAVE_COMPLETE
```

**AC-WES-15 test outline**:
```
1. Setup: WAVE_ACTIVE with _enemies_alive = 5
2. Emit HealthAndDamage.player_died (H&D signal — WaveManager does NOT connect to this)
3. Assert _wave_state still WAVE_ACTIVE
4. Assert all_waves_cleared and boss_defeated NOT emitted
5. Emit preparation_started → assert _enemies_alive == 0, _wave_state == IDLE
```

**Note on AC-WES-15**: WaveManager does not connect to `player_died` at all — the test just verifies that no completion signals were emitted by WaveManager at any point during the test. The reset happens on the subsequent `preparation_started`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: Skeleton and phase gating
- [Story 002]: Spawn sequence production code
- [Story 003]: Kill tracking production code

---

## QA Test Cases

*Written by QA lead at story creation. Implement against these — do not invent new test cases.*

**Test file**: `tests/integration/wave-encounter-system/wave_manager_integration_test.gd`

- **AC-WES-14**: Full FP run flow end-to-end
  - Given: WaveManager with real GameStateManager + HealthAndDamage Autoloads; SpawnPoints container with 10 mock Node2D markers; 10 mock EnemyInstance nodes that respond to `init(type_id)` and `register_enemy()`; signal spies on `all_waves_cleared` and `boss_defeated`
  - When: Full sequence: `preparation_started(0, 1)` → `combat_started(false)` → 10 × `HealthAndDamage.enemy_killed(i, 0, DamageClass.NONE)` fired
  - Then: After `preparation_started`: `_wave_state == IDLE`; after `combat_started`: 10 child enemy nodes, `_enemies_alive == 10`, `_wave_state == WAVE_ACTIVE`; after 10th kill: `_enemies_alive == 0`, `_wave_state == WAVE_COMPLETE`, `all_waves_cleared` spy count == 1, `boss_defeated` spy count == 1
  - Edge cases: Verify `all_waves_cleared` fires before `boss_defeated` (check call order in spy)

- **AC-WES-15**: Player death mid-wave → no wave completion signals
  - Given: WaveManager with `_wave_state = WAVE_ACTIVE`, `_enemies_alive = 5`; signal spies on `all_waves_cleared` and `boss_defeated`
  - When: `HealthAndDamage.player_died` fires (WaveManager ignores it); then `preparation_started(0, 1)` fires
  - Then: `all_waves_cleared` spy count == 0; `boss_defeated` spy count == 0; after `preparation_started`: `_enemies_alive == 0`, `_enemies_total == 0`, `_wave_state == IDLE`
  - Edge cases: Enemies remaining in scene tree from the previous `combat_started` are freed by test teardown; WaveManager does not need to free them itself

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/wave-encounter-system/wave_manager_integration_test.gd` — must exist and pass

**Status**: [x] Created — 5/5 PASSED (GdUnit4 v6.1.3, Godot 4.6.2, 0 orphans, 2026-06-06)

---

## Dependencies

- Depends on: Story 002 DONE (spawn sequence must work), Story 003 DONE (kill tracking must work)
- Unlocks: None — this is the final WaveManager story. Epic complete when this story is Done.

---

## Completion Notes
**Completed**: 2026-06-06
**Criteria**: 2/2 passing (AC-WES-14 and AC-WES-15 fully covered)
**Deviations**: None
**Test Evidence**: Integration — `tests/integration/wave-encounter-system/wave_manager_integration_test.gd` (5/5 PASSED, 35/35 full WES suite, 0 orphans)
**Code Review**: Complete (lean mode — confirmed by developer)
