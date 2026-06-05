# Story 002: Freeze and Regen Effects

> **Epic**: Status Effects
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: ~3 hours
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-05

## Context

**GDD**: `design/gdd/status-effects.md`
**Requirements**: `TR-SE-003`, `TR-SE-006`

**ADR Governing Implementation**: ADR-0011: StatusEffectsManager Public API Contract (primary)
**ADR Decision Summary**: SEM pushes speed commands to EnemyInstance via `apply_speed_modifier(multiplier: float)`. Enemy AI stores `_speed_multiplier` and applies it in `_physics_process()`. SEM owns the timing; Enemy AI owns the movement enforcement.

**Secondary ADRs**:
- ADR-0004: Float Accumulator Timer Pattern — Freeze/Regen duration via count-down accumulators in StatusInstance

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `Dictionary[int, Array[StatusInstance]]` typed dict requires Godot 4.4+ (Godot 4.6 project — satisfied). No additional engine risk for Freeze or Regen paths.

**Control Manifest Rules (Core layer)**:
- Required: `EnemyInstance must expose apply_speed_modifier(multiplier: float)` — source: ADR-0011
- Required: `PlayerController and EnemyInstance must expose is_alive() -> bool` — source: ADR-0011
- Forbidden: Never add per-status query helpers — `has_status()` is the sole interface — source: ADR-0011

---

## Acceptance Criteria

*From GDD `design/gdd/status-effects.md`, scoped to this story:*

- [ ] **AC-SE-05** — GIVEN `apply_status(drifter, FREEZE, 2.0, 0.0)` called, THEN `drifter.apply_speed_modifier(0.50)` called exactly once; `has_status(drifter, FREEZE)` returns `true`
- [ ] **AC-SE-06** — GIVEN a Drifter with active Freeze that expires naturally, WHEN `duration_remaining` reaches 0, THEN `drifter.apply_speed_modifier(1.0)` called; `has_status(drifter, FREEZE)` returns `false`
- [ ] **AC-SE-07** — GIVEN a Frozen Drifter, WHEN Freeze is re-applied, THEN `apply_speed_modifier` is NOT called a second time (already applied); `duration_remaining ≈ 2.0s`; exactly one Freeze StatusInstance
- [ ] **AC-SE-08** — GIVEN `apply_status(fayde, REGENERATE, 3.0, 0.0)` called, WHEN 1.0s elapses, THEN `HealthDamage.apply_heal(fayde, 2.0)` called once (Formula 2: `100 × 0.02 = 2.0`)
- [ ] **AC-SE-10** — GIVEN `apply_status(enemy, REGENERATE, 3.0, 0.0)` called (Regen is Fayde-only), THEN no StatusInstance created; error logged; `status_applied` NOT emitted
- [ ] **AC-SE-21** — GIVEN `apply_status(fayde, REGENERATE, 3.0, 0.0)` called, WHEN 3.0s total elapse (3 ticks at 1.0s), THEN `apply_heal` called exactly 3 times with `tick_heal = 2.0` each; Fayde gains 6 HP total

---

## Implementation Notes

*Derived from ADR-0011 and GDD status-effects.md:*

**Freeze apply (Rule 4 step 5)**:
```gdscript
# On new FREEZE application:
target.apply_speed_modifier(1.0 - FREEZE_SLOW_PCT)  # = apply_speed_modifier(0.50)
# On re-apply (already frozen): skip apply_speed_modifier — multiplier already applied
# tick_interval = 0.0 for Freeze (no tick — duration tracking only)
```

**Freeze expiry (Rule 7)**:
```gdscript
# Freeze cleanup in _expire_status():
if instance.status_type == GameEnums.BaseStatus.FREEZE:
    instance.target.apply_speed_modifier(1.0)  # restore full speed
```

**Regen apply (no speed modifier)**:
- `tick_interval = 1.0s` (Regen tick rate from Prana Data constants)
- `spell_base_damage = 0.0` (unused for Regen — heal amount is formula-derived, not passed)
- Tick action: `HealthDamage.apply_heal(target, FAYDE_MAX_HP * REGEN_TICK_MAGNITUDE)` where `REGEN_TICK_MAGNITUDE = 0.02`

**Regen tick formula (Formula 2)**:
```
regen_tick_heal = FAYDE_MAX_HP × REGEN_TICK_MAGNITUDE = 100 × 0.02 = 2.0
```
H&D's `apply_heal` applies `roundi(2.0) = 2`. The tick fires with the float value `2.0`; H&D rounds it.

**Constants to use (from Prana Data)**:
- `FREEZE_SLOW_PCT = 0.50`
- `FREEZE_DURATION = 2.0` (default; passed as parameter)
- `REGEN_TICK_MAGNITUDE = 0.02`
- `FAYDE_MAX_HP = 100`

**Target scope validation**:
- Regen target must be in `&"player"` group (Fayde only). Log error and return if enemy node passed.
- Freeze target must be in `&"enemy"` group. (Covered by Story 001's scope guard — Story 002 adds the specific Freeze path to apply_speed_modifier.)

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: Burn DoT, scope guard, dead-target guard (already implemented — reuse those guards)
- **Story 003**: Chill (15% slow — similar to Freeze but with Freeze suppression logic)
- **Story 004**: `_on_enemy_killed()` and `_on_preparation_started()` cleanup (Freeze cleanup on kill/wave clear)
- **Story 005**: `has_status(target, FREEZE)` return values are tested here via AC-SE-05/06, but `has_status()` itself is implemented in Story 005

---

## QA Test Cases

*Sourced from `production/qa/qa-plan-sprint-3-2026-06-03.md` (S3-05). Do not invent new test cases during implementation.*

**AC-SE-05** — Freeze apply calls speed modifier once and registers status
- Given: Drifter enemy node; `apply_speed_modifier` method available (mock or real); SEM initialized with Story 001 complete
- When: `apply_status(drifter, FREEZE, 2.0, 0.0)` called
- Then: `apply_speed_modifier` spy called exactly once with `0.50`; `has_status(drifter, FREEZE)` returns `true`
- Edge cases: `has_status` is implemented in Story 005 — for this story's tests, verify via direct registry inspection (`_active_statuses[drifter.get_instance_id()]` contains a FREEZE entry)

**AC-SE-06** — Freeze expiry restores full speed
- Given: Active Freeze on drifter; `apply_speed_modifier` mock
- When: `_process(delta)` driven until `duration_remaining <= 0`
- Then: `apply_speed_modifier` called with `1.0` (restore full speed); FREEZE StatusInstance removed from registry
- Edge cases: After expiry, another `apply_status(FREEZE)` creates a fresh instance and calls `apply_speed_modifier(0.50)` again (re-freeze is allowed)

**AC-SE-07** — Freeze re-apply does not double-call speed modifier
- Given: Drifter already frozen (FREEZE active); `apply_speed_modifier` spy call count tracked
- When: `apply_status(drifter, FREEZE, 2.0, 0.0)` called again
- Then: `apply_speed_modifier` spy NOT called a second time; `duration_remaining ≈ 2.0`; exactly 1 FREEZE StatusInstance in registry
- Edge cases: `duration_remaining` is reset even though multiplier is not re-pushed

**AC-SE-08** — Regen tick fires at 1.0s intervals with correct heal value
- Given: Fayde node (in `&"player"` group); H&D mock injected; `apply_status(fayde, REGENERATE, 3.0, 0.0)` called
- When: `_process(delta)` driven to cumulative delta = 1.0s
- Then: H&D mock's `apply_heal` called once with `(fayde, 2.0)` (100 × 0.02 = 2.0)
- Edge cases: `FAYDE_MAX_HP = 80` edge: `round(80 × 0.02) = round(1.6) = 2` — still non-zero; safe minimum confirmed by GDD

**AC-SE-10** — Regen scope guard rejects enemy target
- Given: Enemy node in `&"enemy"` group
- When: `apply_status(enemy, REGENERATE, 3.0, 0.0)` called
- Then: No StatusInstance created; `push_error()` called; `status_applied` NOT emitted
- Edge cases: Same guard covers all player-only statuses

**AC-SE-21** — Regen delivers 3 ticks = 6 HP total over 3.0s
- Given: `apply_status(fayde, REGENERATE, 3.0, 0.0)` called; H&D mock
- When: `_process(delta)` driven to cumulative delta = 3.0s
- Then: `apply_heal` called exactly 3 times, each with `tick_heal = 2.0`; Regen StatusInstance removed after expiry
- Edge cases: No 4th tick fires after expiry even if accumulator slightly overshoots 3.0s

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/status-effects/sem_freeze_regen_test.gd` — must exist and pass headless

**Status**: [x] Complete — `tests/unit/status-effects/sem_freeze_regen_test.gd`, 9/9 PASS (GdUnit4 v6.1.3, Godot 4.6.2)

---

## Dependencies

- Depends on: Story 001 must be Done (scope guard and tick loop infrastructure required)
- Unlocks: Story 003 (Chill stub requires Freeze suppression logic from this story)

---

## Completion Notes
**Completed**: 2026-06-05
**Criteria**: 6/6 passing
**Deviations**:
- ADVISORY (fixed): `_expire_status` ordering — speed restore was placed before `status_expired.emit()`. Fixed to match GDD Rule 7 sequence (erase → emit → cleanup). Applies to future Chill expiry as well.
- ADVISORY: `FREEZE_DURATION = 2.0` constant unused internally — doc comment clarified ("Reference only — SC&E must pass as duration parameter").
- ADVISORY: `FAYDE_MAX_HP = 100.0` hardcoded — known tech debt; must sync with PlayerController.MAX_HEALTH when that lands. Logged in tech-debt-register.md.
- ADVISORY: Story 003 pre-condition logged — `_expire_status` speed-restore for Freeze must check for active Chill before restoring to 1.0 (see story-003 Implementation Notes).
**Test Evidence**: Logic — `tests/unit/status-effects/sem_freeze_regen_test.gd`, 9/9 PASS headless (GdUnit4 v6.1.3, Godot 4.6.2)
**Code Review**: Complete — CHANGES REQUIRED → all fixes applied → APPROVED WITH SUGGESTIONS
