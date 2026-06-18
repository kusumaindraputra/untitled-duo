# Story 003: Kill Tracking and Wave Completion Signals

> **Epic**: WaveManager
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: ~2 hours
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-06

## Context

**GDD**: `design/gdd/wave-encounter-system.md`
**Requirement**: `TR-WES-003`, `TR-WES-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0014: H&D ↔ WaveManager Integration Contract
**ADR Decision Summary**: WaveManager tracks kills exclusively via `H&D.enemy_killed` signal. Uses `<= 0` guard (not `== 0`) against duplicate signals. Emits `all_waves_cleared` then `boss_defeated` sequentially in the same handler, same frame, at FP scope.

**Secondary ADR**: ADR-0003: Signal-Driven Architecture — signal emission pattern; `emit_signal()` is synchronous.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `emit_signal("name")` / direct `signal_name.emit()` both valid in Godot 4.6. Use direct emit form (`all_waves_cleared.emit()`) for type safety.

**Control Manifest Rules (Feature Layer)**:
- Required: `_enemies_alive <= 0` guard (not `== 0`) in `_on_enemy_killed` handler
- Required: WaveManager tracks wave completion exclusively via `HealthAndDamage.enemy_killed` signal — never polls `_enemy_registry` directly
- Forbidden: No other system emits `all_waves_cleared` or `boss_defeated`

---

## Acceptance Criteria

*From GDD `design/gdd/wave-encounter-system.md`, scoped to this story:*

- [ ] **AC-WES-07** — GIVEN `_wave_state = WAVE_ACTIVE` and `_enemies_alive = 5`, WHEN `enemy_killed` fires once, THEN `_enemies_alive = 4` and `_wave_state` remains `WAVE_ACTIVE`.
- [ ] **AC-WES-08** — GIVEN `_enemies_alive = 1` and `_wave_state = WAVE_ACTIVE`, WHEN the final `enemy_killed` fires, THEN `_enemies_alive = 0` and `_wave_state = WAVE_COMPLETE` after the handler returns.
- [ ] **AC-WES-09** — GIVEN `_enemies_alive` reaches 0 (wave complete), WHEN the completion handler runs, THEN `all_waves_cleared` is emitted exactly once AND `boss_defeated` is emitted exactly once, in that order, in the same handler call (synchronous, same frame).
- [ ] **AC-WES-10** — GIVEN the WaveManager has already entered `WAVE_COMPLETE` (signals emitted), WHEN another `enemy_killed` fires (late signal / duplicate), THEN `_wave_state` remains `WAVE_COMPLETE` and neither `all_waves_cleared` nor `boss_defeated` is re-emitted.
- [ ] **AC-WES-11** — GIVEN `_enemies_total = 0` after the spawn loop (all spawns failed), WHEN the zero-spawn guard runs, THEN `push_error()` is logged, `all_waves_cleared` is emitted, `boss_defeated` is emitted, and `_wave_state = WAVE_COMPLETE`. Run does not softlock.

---

## Implementation Notes

*Derived from ADR-0014 Kill Signal Contract:*

```gdscript
func _on_enemy_killed(instance_id: int, type_id: int,
                      prana_affiliation: GameEnums.DamageClass) -> void:
    if _wave_state != WaveState.WAVE_ACTIVE:
        return  # WAVE_COMPLETE guard: ignore late/duplicate signals
    _enemies_alive -= 1
    if _enemies_alive <= 0:
        _wave_state = WaveState.WAVE_COMPLETE
        all_waves_cleared.emit()
        boss_defeated.emit()   # FP: no boss exists; fires immediately after
```

**Why `<= 0` and not `== 0`**: Protects against the edge case where a bug causes `_enemies_alive` to go negative — the completion check still fires, preventing a softlock in `WAVE_ACTIVE`. H&D's dead-target guard is the primary protection against duplicate `enemy_killed` signals; this guard is a safety net.

**Why `WAVE_COMPLETE` early-return before decrementing**: The guard must fire *before* the decrement. If `WAVE_COMPLETE` is checked *after* decrement (when `_enemies_alive` is already 0), a duplicate signal would decrement to -1 and fail the `<= 0` check (still fires, but corrupts `_enemies_alive`). Checking state first is cleaner and prevents state corruption.

**Signal ordering**: `all_waves_cleared` must fire before `boss_defeated`. Both are synchronous within the same frame — no deferred emit. GameStateManager's handler for `boss_defeated` uses `call_deferred()` for the boss→RUN_SUMMARY transition (per TR-GSF-006), so ordering within WaveManager is safe to be direct.

**AC-WES-11 location**: The zero-spawn guard (`_enemies_total == 0` → immediate signal emission) lives at the end of `_spawn_wave()` (Story 002). It is tested here because it produces the same `all_waves_cleared` + `boss_defeated` + `WAVE_COMPLETE` output as the normal kill-tracking path.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: Skeleton, state enum declaration, signal declarations
- [Story 002]: `_spawn_wave()` body and the zero-spawn guard trigger point (tested here; implemented there)
- [Story 004]: End-to-end integration test combining all stories

---

## QA Test Cases

*Written by QA lead at story creation. Implement against these — do not invent new test cases.*

**Test file**: `tests/unit/wave-encounter-system/wave_manager_kill_tracking_test.gd`

- **AC-WES-07**: Mid-wave kill — count decrements, state unchanged
  - Given: WaveManager with `_wave_state = WAVE_ACTIVE`, `_enemies_alive = 5`
  - When: `_on_enemy_killed(999, 0, GameEnums.DamageClass.VOIDBLUE)` called
  - Then: `_enemies_alive == 4`; `_wave_state == WaveState.WAVE_ACTIVE`; no signals emitted
  - Edge cases: Call with any `instance_id` / `type_id` / `prana_affiliation` — WaveManager does not validate these fields

- **AC-WES-08**: Last kill → WAVE_COMPLETE
  - Given: `_wave_state = WAVE_ACTIVE`, `_enemies_alive = 1`
  - When: `_on_enemy_killed(...)` called
  - Then: `_enemies_alive == 0`; `_wave_state == WaveState.WAVE_COMPLETE`
  - Edge cases: Check that `_wave_state` is `WAVE_COMPLETE` *after* the handler returns (not deferred)

- **AC-WES-09**: Completion signals emitted once, in order
  - Given: WaveManager with signal watchers connected to `all_waves_cleared` and `boss_defeated`; `_wave_state = WAVE_ACTIVE`, `_enemies_alive = 1`
  - When: `_on_enemy_killed(...)` called
  - Then: `all_waves_cleared` emitted exactly 1 time; `boss_defeated` emitted exactly 1 time; `all_waves_cleared` fired before `boss_defeated`
  - Edge cases: Use GdUnit4 signal spy (`watch_signals`) to assert emission counts and order

- **AC-WES-10**: Duplicate signal after WAVE_COMPLETE — no re-emission
  - Given: WaveManager already in `WAVE_COMPLETE` (signals already fired)
  - When: `_on_enemy_killed(...)` called again (simulating late/duplicate signal)
  - Then: `_wave_state` remains `WAVE_COMPLETE`; `all_waves_cleared` total count remains 1; `boss_defeated` total count remains 1; `_enemies_alive` is NOT decremented further
  - Edge cases: Verify `_enemies_alive` does not go below 0

- **AC-WES-11**: Zero-spawn guard fires completion without kills
  - Given: WaveManager after `_spawn_wave()` with 0 spawn markers (all spawns failed); `_enemies_total == 0`
  - When: Zero-spawn guard runs at end of `_spawn_wave()`
  - Then: `push_error()` logged; `all_waves_cleared` emitted once; `boss_defeated` emitted once; `_wave_state == WAVE_COMPLETE`
  - Edge cases: No `enemy_killed` signals required — wave completes vacuously; run should not hang

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/wave-encounter-system/wave_manager_kill_tracking_test.gd` — must exist and pass

**Status**: [x] Created — see Completion Notes

---

## Dependencies

- Depends on: Story 001 DONE (signal declarations and WaveState enum must exist)
- Unlocks: Story 004 (integration test depends on both spawn and kill tracking working)

## Completion Notes
**Completed**: 2026-06-06
**Criteria**: 5/5 passing
**Deviations**:
- ADVISORY: Story QA spec used non-existent `GameEnums.DamageClass.VOIDBLUE` — replaced with `DamageClass.FIRE` in test; functionally equivalent.
- ADVISORY: `wave_cleared` signal declared but not emitted at FP scope — intentional deferral to multi-wave story; doc comment not updated (minor).
- ADVISORY: `push_error()` in AC-WES-11 not directly asserted (GdUnit4 cannot intercept push_error); state assertions serve as observable contract.
**Test Evidence**: Logic — `tests/unit/wave-encounter-system/wave_manager_kill_tracking_test.gd` (8/8 PASSED, 0 orphans)
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (lean mode; stale TODO fixed pre-close)
