# Story 003: Contact Attack and Repeat-Damage Timer

> **Epic**: Enemy Instance
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: ~2h
> **Manifest Version**: 2026-05-30
> **Last Updated**: 2026-06-03

## Context

**GDD**: `design/gdd/enemy-ai.md`
**Requirement**: `TR-EAI-002`, `TR-EAI-003`

**ADR Governing Implementation**: ADR-0007: HealthAndDamage Singleton
**ADR Decision Summary**: All damage through `HealthAndDamage.apply_damage(target, base_damage, element, source)`. Enemy contact uses `DamageSource.CONTACT`. Minimum inter-contact interval ≥ 0.3s (H&D Dependency #5 — i-frame protection depends on this).

**Secondary ADR**: ADR-0004 (contact timer implemented as float accumulator in `_physics_process`, NOT a Timer node)

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Area2D.body_entered` / `body_exited` signals stable. `monitoring` property stable.

**Control Manifest Rules (Core layer)**:
- Required: All damage through `HealthAndDamage.apply_damage(target, base_damage, element, source)`.
- Required: All timing via float delta accumulators in `_physics_process(delta)` — NOT Timer nodes.
- Forbidden: Never use `Timer` nodes for gameplay timing.

---

## Acceptance Criteria

- [ ] **AC-EAI-10** — GIVEN enemy alive in COMBAT_PHASE and Fayde not overlapping, WHEN Fayde's body enters `HitArea` (`body_entered` fires), THEN `apply_damage(fayde, _base_damage, GameEnums.DamageClass.NONE, DamageSource.CONTACT)` called exactly once before any timer elapses. Duplicate `body_entered` signals (no intervening `body_exited`) must not trigger a second hit.
- [ ] **AC-EAI-11** — GIVEN Fayde overlapping and initial hit fired, WHEN `_contact_timer` expires (0.3s) and `_fayde_in_contact == true`, THEN `apply_damage` called again with same arguments.
- [ ] **AC-EAI-12** — GIVEN Fayde overlapping and timer running, WHEN `body_exited` fires, THEN `_contact_timer` stops (`_contact_timer == 0`) and no further `apply_damage` calls occur after one full `ENEMY_MIN_CONTACT_INTERVAL`.
- [ ] **AC-EAI-13** — GIVEN compiled `EnemyInstance`, WHEN `ENEMY_MIN_CONTACT_INTERVAL` read, THEN equals `0.3` (float).
- [ ] **AC-EAI-14** — Both: (1) `ENEMY_MIN_CONTACT_INTERVAL >= 0.3`; (2) `FAYDE_IFRAME_DURATION / ENEMY_MIN_CONTACT_INTERVAL >= 1.0`. *(FAYDE_IFRAME_DURATION is H&D's constant — read from HealthAndDamage or check its default 0.5s meets the ratio.)*

---

## Implementation Notes

**Area2D signal connections (in `_ready()`):**
```gdscript
$HitArea.body_entered.connect(_on_hitarea_body_entered)
$HitArea.body_exited.connect(_on_hitarea_body_exited)
```

**Contact callbacks:**
```gdscript
func _on_hitarea_body_entered(body: Node) -> void:
    if not body.is_in_group(&"player"):
        return
    if _state == EnemyState.DEAD or not _combat_active:
        return
    _fayde_in_contact = true
    HealthAndDamage.apply_damage(body, _base_damage, null, GameEnums.DamageSource.CONTACT)
    _contact_timer = ENEMY_MIN_CONTACT_INTERVAL  # arm repeat timer

func _on_hitarea_body_exited(body: Node) -> void:
    if not body.is_in_group(&"player"):
        return
    _fayde_in_contact = false
    _contact_timer = 0.0  # disarm timer
```

**Contact timer in `_physics_process` (add after movement from Story 002):**
```gdscript
# Contact repeat timer (float accumulator per ADR-0004)
if _fayde_in_contact and _contact_timer > 0.0:
    _contact_timer -= delta
    if _contact_timer <= 0.0:
        if _fayde_ref != null:
            HealthAndDamage.apply_damage(
                _fayde_ref, _base_damage, null, GameEnums.DamageSource.CONTACT)
        _contact_timer = ENEMY_MIN_CONTACT_INTERVAL  # re-arm
```

**Performance**: float accumulator + Area2D signal callbacks — negligible cost per enemy, no per-frame allocations. No budget concern at FP enemy count (≤5 enemies per wave).

**AC-EAI-14 assertion approach**: Read `HealthAndDamage.FAYDE_IFRAME_DURATION` (0.5) and `EnemyInstance.ENEMY_MIN_CONTACT_INTERVAL` (0.3). Assert `0.5 / 0.3 >= 1.0` → `1.67 >= 1.0` passes. This is a static constant check — not a runtime simulation.

**Testing contact callbacks**: In GdUnit4, Area2D `body_entered` can be simulated by calling `_on_hitarea_body_entered(mock_fayde_node)` directly. The mock node must `is_in_group("player")` return true — use `mock_fayde.add_to_group(&"player")` before calling.

---

## Out of Scope

- Story 001: Phase gating guard (dead/inactive check at top of callback)
- Story 004: Death sequence stops contact timer (`_contact_timer = 0` in death handler)
- Story 005: AC-EAI-24 full sequential integration test

---

## QA Test Cases

**AC-EAI-10 — body_entered triggers immediate damage**
- Given: `_combat_active = true`; `_state = CHASING`; H&D mock or spy; mock Fayde in "player" group
- When: `_on_hitarea_body_entered(fayde_mock)` called
- Then: `HealthAndDamage.apply_damage` called once with `(fayde_mock, _base_damage, GameEnums.DamageClass.NONE, CONTACT)`; `_contact_timer == ENEMY_MIN_CONTACT_INTERVAL` (0.3)
- Edge cases: Call when DEAD → no damage call; call when `_combat_active = false` → no damage call; non-player body → no damage call; double fire (no intervening body_exited) → exactly one damage call

**AC-EAI-11 — Timer expiry triggers repeat damage**
- Given: `_fayde_in_contact = true`; `_contact_timer = ENEMY_MIN_CONTACT_INTERVAL` (0.3); `_combat_active = true`; H&D mock
- When: `_physics_process(1.0/60.0)` called `ceil(0.3 * 60) + 1` = 19 times
- Then: `HealthAndDamage.apply_damage` called again; `_contact_timer` reset to `ENEMY_MIN_CONTACT_INTERVAL`

**AC-EAI-12 — body_exited stops timer**
- Given: `_fayde_in_contact = true`; `_contact_timer = 0.15` (mid-interval)
- When: `_on_hitarea_body_exited(fayde_mock)` called; then `_physics_process` called 30 more times
- Then: `_contact_timer == 0`; `HealthAndDamage.apply_damage` NOT called during those 30 frames

**AC-EAI-13 — ENEMY_MIN_CONTACT_INTERVAL == 0.3**
- Given: `EnemyInstance` class
- When: `ENEMY_MIN_CONTACT_INTERVAL` constant read
- Then: `abs(ENEMY_MIN_CONTACT_INTERVAL - 0.3) < 0.001`

**AC-EAI-14 — Contact interval and i-frame ratio constraint**
- Given: Constants from EnemyInstance and HealthAndDamage
- When: Both constants read
- Then: `ENEMY_MIN_CONTACT_INTERVAL >= 0.3` AND `HealthAndDamage.FAYDE_IFRAME_DURATION / ENEMY_MIN_CONTACT_INTERVAL >= 1.0`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/enemy-instance/contact_attack_test.gd` — must pass headless

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (skeleton), Story 002 (movement runs in same `_physics_process`)
- Unlocks: Story 004 (death stops contact timer), Story 005 (integration tests for full sequence)

---

## Completion Notes
**Completed**: 2026-06-03
**Criteria**: 5/5 passing
**Deviations**:
- ADVISORY: Implementation Notes code snippets show original `body: Node` / `null` element sketches — final impl uses `Node2D` and `GameEnums.DamageClass.NONE`; story ACs updated to match.
- ADVISORY: `ENEMY_MIN_CONTACT_INTERVAL = 0.3` hardcoded const — pre-existing tech debt, already tracked.
**Test Evidence**: Logic — `tests/unit/enemy-instance/contact_attack_test.gd` — 11/11 PASSED (GdUnit4 v6.1.3, Godot 4.6.2)
**Code Review**: Complete — CHANGES REQUIRED → all changes applied → re-ran 27/27 PASSED
