# Story 005: Integration Tests and Status Effects API Stubs

> **Epic**: Enemy Instance
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: ~2h
> **Manifest Version**: 2026-05-30
> **Last Updated**: 2026-05-31

## Context

**GDD**: `design/gdd/enemy-ai.md`
**Requirement**: `TR-EAI-008`

**ADR Governing Implementation**: ADR-0011: StatusEffectsManager API Contract
**ADR Decision Summary**: EnemyInstance must expose `apply_speed_modifier(multiplier: float)` and `apply_stun(duration: float)` for StatusEffectsManager (MVP). At FP scope these are stubs — no behavior, just the method signatures for forward compatibility. Also exposes `is_alive() -> bool`.

**Secondary ADR**: ADR-0003 (contact signal chain), ADR-0007 (kill stops contact)

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules (Core layer)**:
- Required: EnemyInstance must expose `apply_speed_modifier(multiplier: float)` and `apply_stun(duration: float)`.
- Required: EnemyInstance must expose `is_alive() -> bool`.
- Forbidden: Never add per-status query helpers (`is_frozen()`, `is_blinded()`, etc.) — `has_status()` in SEM is the sole query interface.

---

## Acceptance Criteria

- [ ] **AC-EAI-24** — Full contact sequence: GIVEN alive enemy in COMBAT_PHASE, Fayde not overlapping: (1) Fayde enters → `apply_damage` called once immediately; (2) timer fires at 0.3s, Fayde still overlapping → second `apply_damage`; (3) Fayde exits → timer stops; (4) after one full interval post-exit → no third call. All 4 steps in one sequential test.
- [ ] **AC-EAI-25** — Phase transition during contact: (1) Fayde overlapping, timer running in COMBAT_PHASE; (2) `preparation_started` fires → timer stops, velocity zeros, no damage during PREP; (3) `combat_started` fires → contact correctly re-arms with no leaked timer state.
- [ ] **AC-EAI-26** — Kill during overlap: GIVEN Fayde overlapping and timer running, WHEN `enemy_killed` fires, THEN `$HitArea.monitoring == false` and no additional `apply_damage` after one full interval post-kill.
- [ ] **TR-EAI-008 stub** — `apply_speed_modifier(multiplier: float)` and `apply_stun(duration: float)` methods exist on `EnemyInstance`; `is_alive() -> bool` returns `true` when `_state == CHASING`, `false` when `DEAD`.

---

## Implementation Notes

**Status Effects API stubs (FP scope — no behavior):**
```gdscript
func is_alive() -> bool:
    return _state == EnemyState.CHASING

func apply_speed_modifier(multiplier: float) -> void:
    # MVP: _move_speed *= multiplier (Freeze slow)
    # FP: stub — no-op
    pass

func apply_stun(duration: float) -> void:
    # MVP: zero velocity + freeze direction cache for duration
    # FP: stub — no-op
    pass
```

**Note on AC-EAI-24 test structure**: This is a sequential integration test requiring:
1. H&D autoload (or mock) for `apply_damage` call counting
2. GameStateManager (or direct method calls) for phase signals
3. Area2D body_entered/exited simulated via direct method calls on EnemyInstance

Drive time via `_physics_process(1.0/60.0)` loops. To simulate 0.3s: call `_physics_process(1.0/60.0)` 19 times (`ceil(0.3 * 60) + 1`).

**Note on AC-EAI-25 leaked timer state**: After `preparation_started` + `combat_started` cycle, `_contact_timer` must be 0 and `_fayde_in_contact` must reflect actual current overlap state (not carry stale values from before the prep phase). The `_on_preparation_started()` handler zeros both vars — verify after the cycle that a fresh `body_entered` event correctly fires damage once (not twice from a leaked timer).

---

## Out of Scope

- Story 003: Unit tests for individual contact callbacks
- Story 004: Death transition (AC-EAI-26 assumes Story 004 death handler is in place)
- StatusEffectsManager epic: Full `apply_speed_modifier` / `apply_stun` behavior

---

## QA Test Cases

**AC-EAI-24 — Full contact sequence (4 steps)**
- Given: Enemy alive in COMBAT_PHASE; H&D call counter mock; `_move_speed = 80.0`
- Step 1: `_on_hitarea_body_entered(fayde_mock)` → assert call count == 1
- Step 2: Drive `_physics_process` 19 frames (0.3s); assert call count == 2
- Step 3: `_on_hitarea_body_exited(fayde_mock)` → assert `_contact_timer == 0`
- Step 4: Drive 19 more frames → assert call count still == 2
- Pass: All 4 assertions pass in sequence

**AC-EAI-25 — Phase transition clears contact state**
- Given: `_fayde_in_contact = true`; `_contact_timer = 0.15` (mid-interval); COMBAT_PHASE active
- Step 1: `_on_preparation_started()` → assert `_contact_timer == 0`, `velocity == Vector2.ZERO`
- Step 2: Drive 10 frames in PREP phase → assert no `apply_damage` call
- Step 3: `_on_combat_started()` → assert `_combat_active = true`
- Step 4: `_on_hitarea_body_entered(fayde_mock)` → assert fresh damage call fires (count == 1, not 2)
- Pass: No damage during PREP; fresh re-arm after combat_started

**AC-EAI-26 — Kill during contact stops further damage**
- Given: `_fayde_in_contact = true`; timer running; H&D mock
- When: `_on_enemy_killed(enemy.get_instance_id(), ...)` called; then drive 19 frames
- Then: `$HitArea.monitoring == false`; H&D call count unchanged after kill (no repeat damage)

**TR-EAI-008 stubs — Methods exist and return correct types**
- Given: `EnemyInstance` with `_state = CHASING`
- When: `is_alive()` called
- Then: Returns `true`
- When: `_state = DEAD`; `is_alive()` called
- Then: Returns `false`
- When: `apply_speed_modifier(0.5)` called → no crash; `apply_stun(0.8)` called → no crash

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/enemy-instance/enemy_instance_integration_test.gd` — must pass headless

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (contact callbacks), Story 004 (death handler for AC-EAI-26)
- Unlocks: Enemy Instance epic COMPLETE for all blocking ACs. Story 006 is advisory Visual/Feel.
