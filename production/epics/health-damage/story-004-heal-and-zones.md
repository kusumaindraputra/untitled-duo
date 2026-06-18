# Story 004: apply_heal() and HP Zone Signals

> **Epic**: Health & Damage
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: ~3h
> **Manifest Version**: 2026-05-30
> **Last Updated**: 2026-06-02

## Context

**GDD**: `design/gdd/health-damage.md`
**Requirement**: `TR-HD-003`, `TR-HD-008`

**ADR Governing Implementation**: ADR-0007: HealthAndDamage Singleton
**ADR Decision Summary**: `apply_heal(target, heal_amount)` sole heal entry. HP zone state machine fires `player_hp_zone_changed(HPZone)` signal when zone boundary is crossed. Only the final destination zone fires per call — no intermediate zone signals.

**Secondary ADR**: ADR-0003 (signal-driven: emit `health_restored` and `player_hp_zone_changed` signals)

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: No post-cutoff APIs. `roundi()` for heal amount rounding.

**Control Manifest Rules (Core layer)**:
- Required: All healing through `HealthAndDamage.apply_heal(target, heal_amount)`.
- Required: Emit `health_restored` signal with actual healed delta (not raw input amount).
- Forbidden: Never access HP state directly from another system.

---

## Acceptance Criteria

*From GDD `design/gdd/health-damage.md`, scoped to this story:*

- [ ] **AC-HD-10** — Given Fayde `current_hp=80, max_hp=100`, `apply_heal(fayde, 30)`: `current_hp=100` (clamped at max).
- [ ] **AC-HD-11** — Given Fayde at max HP (100), `apply_heal(fayde, 10)`: `current_hp` remains 100; `health_restored` **NOT** emitted.
- [ ] **AC-HD-12** — Given Fayde `current_hp=10`, `apply_heal(fayde, 6)`: `current_hp=16` and `health_restored(fayde, 6, 16)` emitted.
- [ ] **AC-HD-19** — Given Fayde `current_hp=45`, damage brings HP to 39 (crossing CAREFUL=40 threshold): `player_hp_zone_changed(HPZone.CAREFUL)` emitted once.
- [ ] **AC-HD-20** — Given Fayde already in CAREFUL zone (HP=35, zone tracker=CAREFUL), damage brings HP to 30 (still in CAREFUL): `player_hp_zone_changed` **NOT** re-emitted.
- [ ] **AC-HD-21** — Given Fayde in CAREFUL zone (HP=25), damage brings HP to 19 (crossing DESPERATE=20): `player_hp_zone_changed(HPZone.DESPERATE)` emitted once; CAREFUL signal **NOT** re-emitted.
- [ ] **AC-HD-22** — Given Fayde `current_hp=10`, heal brings HP to 45 (crossing both DESPERATE and CAREFUL thresholds): `player_hp_zone_changed(HPZone.FULL)` emitted once; CAREFUL **NOT** separately emitted.
- [ ] **AC-HD-24** — `apply_heal(fayde, -10.0)`: `current_hp` unchanged; no signal emitted (precondition violation — logged, returns).
- [ ] **AC-HD-26** — Given Fayde `current_hp=10` (DESPERATE zone), heal to `current_hp=25` (above DESPERATE=20, below CAREFUL=40): `player_hp_zone_changed(HPZone.CAREFUL)` emitted once; FULL **NOT** emitted.
- [ ] **AC-HD-32** — Given run ended with Fayde in DESPERATE zone; after `run_started`: (1) `current_hp = FAYDE_MAX_HP` (100); (2) `player_hp_zone_changed(HPZone.FULL)` emitted once.

---

## Implementation Notes

*Derived from ADR-0007:*

**apply_heal:**
```gdscript
func apply_heal(target: Node, heal_amount: float) -> void:
    if heal_amount < 0.0:
        push_error("apply_heal: negative heal_amount — precondition violation")
        return
    if not target.is_in_group(&"player"):
        return  # FP scope: only Fayde can receive healing
    var old_hp := _fayde_current_hp
    _fayde_current_hp = clampf(_fayde_current_hp + heal_amount, 0.0, FAYDE_MAX_HP)
    var healed: int = roundi(_fayde_current_hp - old_hp)
    if healed <= 0:
        return  # no signal for zero-effect heals (AC-HD-11)
    emit_signal("health_restored", target, healed, roundi(_fayde_current_hp))
    _check_hp_zone_change()
```

**HP zone state machine (`_check_hp_zone_change`):**
```gdscript
func _check_hp_zone_change() -> void:
    var new_zone: GameEnums.HPZone
    var desperate_threshold := FAYDE_MAX_HP * FAYDE_HP_CRITICAL_DESPERATE  # 20.0
    var careful_threshold := FAYDE_MAX_HP * FAYDE_HP_CRITICAL_CAREFUL      # 40.0
    if _fayde_current_hp <= desperate_threshold:
        new_zone = GameEnums.HPZone.DESPERATE
    elif _fayde_current_hp <= careful_threshold:
        new_zone = GameEnums.HPZone.CAREFUL
    else:
        new_zone = GameEnums.HPZone.FULL
    if new_zone != _current_zone:
        _current_zone = new_zone
        emit_signal("player_hp_zone_changed", new_zone)
```

**Integrate into apply_damage (Story 002 stub → replace)**: Call `_check_hp_zone_change()` after applying HP in step 3 of `apply_damage`.

**Run reset zone sync (AC-HD-32)**: In `_on_run_started()`, after resetting `_fayde_current_hp = FAYDE_MAX_HP`, call `_check_hp_zone_change()`. If zone was DESPERATE, this will transition to FULL and fire the signal.

**Note on fixture setup for AC-HD-20/21**: Zone tracker must be established via the pipeline (call `apply_damage` to cross into CAREFUL zone), NOT by direct `_current_zone` assignment. The GDD explicitly notes: "Fixture must establish zone state via the pipeline."

---

## Out of Scope

- Story 002: `apply_damage()` shell (this story replaces the `_check_hp_zone_change` stub)
- Story 005: `player_died` guard (edge case where damage also kills)
- Enemy healing: `apply_heal` is Fayde-only at FP scope; enemy healing is Post-FP

---

## QA Test Cases

**AC-HD-10 — Heal clamped at max HP**
- Given: `_fayde_current_hp = 80.0`
- When: `apply_heal(fayde, 30.0)`
- Then: `_fayde_current_hp == 100.0`; `health_restored(fayde, 20, 100)` emitted (delta=20, not 30)

**AC-HD-11 — No signal at max HP**
- Given: `_fayde_current_hp = 100.0`
- When: `apply_heal(fayde, 10.0)`
- Then: `_fayde_current_hp == 100.0`; `health_restored` emit count == 0

**AC-HD-12 — Normal heal emits correct delta**
- Given: `_fayde_current_hp = 10.0`
- When: `apply_heal(fayde, 6.0)`
- Then: `_fayde_current_hp == 16.0`; `health_restored(fayde, 6, 16)` emitted

**AC-HD-19 — Zone transition into CAREFUL**
- Given: `_fayde_current_hp = 45.0`; zone = FULL (confirmed via no prior zone emission)
- When: `apply_damage(fayde, 6.0, null, DIRECT)`
- Then: `player_hp_zone_changed(HPZone.CAREFUL)` emitted once

**AC-HD-20 — No re-emit within same zone**
- Given: pipeline call establishes CAREFUL zone (HP=35); `player_hp_zone_changed` emit count reset to 0
- When: `apply_damage(fayde, 5.0, null, DIRECT)` → HP=30 (still CAREFUL)
- Then: `player_hp_zone_changed` emit count == 0

**AC-HD-21 — DESPERATE transition skips CAREFUL re-emit**
- Given: CAREFUL zone established via pipeline (HP=25); emit count reset
- When: `apply_damage(fayde, 6.0, null, DIRECT)` → HP=19
- Then: `player_hp_zone_changed(HPZone.DESPERATE)` emit count == 1; no CAREFUL emission

**AC-HD-22 — Single-call multi-zone heal emits only final zone**
- Given: `_fayde_current_hp = 10.0`; DESPERATE zone established
- When: `apply_heal(fayde, 35.0)` → HP=45 (FULL zone)
- Then: `player_hp_zone_changed(HPZone.FULL)` emit count == 1; CAREFUL emit count == 0

**AC-HD-24 — Negative heal rejected**
- Given: `_fayde_current_hp = 80.0`
- When: `apply_heal(fayde, -10.0)`
- Then: `_fayde_current_hp == 80.0`; no signals emitted

**AC-HD-26 — Partial recovery into CAREFUL (not FULL)**
- Given: DESPERATE zone (HP=10)
- When: `apply_heal(fayde, 15.0)` → HP=25
- Then: `player_hp_zone_changed(HPZone.CAREFUL)` emitted; FULL NOT emitted

**AC-HD-32 — Run reset emits zone signal from DESPERATE**
- Given: DESPERATE zone established via pipeline (HP < 20)
- When: `_on_run_started()` called
- Then: `_fayde_current_hp == 100.0`; `player_hp_zone_changed(HPZone.FULL)` emitted once

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/health-damage/heal_and_zones_test.gd` — must pass headless

**Status**: [x] Created — see Completion Notes

---

## Dependencies

- Depends on: Story 002 (apply_damage stub must exist; `_check_hp_zone_change` replaces the stub from this story)
- Unlocks: Story 005 (death checks can now reach zone logic if needed)

---

## Completion Notes

**Completed**: 2026-06-02
**Criteria**: 10/10 passing
**Deviations**:
- ADVISORY: No dedicated `heal_and_zones_test.gd` — all AC covered in shared `health_damage_skeleton_test.gd`
- ADVISORY: Story references TR-HD-003/TR-HD-008; implements TR-HD-002 (apply_heal) and TR-HD-006 (zone signal) — same misassignment pattern as Story 002
- ADVISORY: `_on_run_started()` emits `player_hp_zone_changed(FULL)` unconditionally instead of calling `_check_hp_zone_change()` — correct design (ensures HUD/Audio sync regardless of prior zone)
- ADVISORY: `apply_heal` guard uses `<= 0.0` (rejects zero heals) vs `< 0.0` in spec; no AC failure
**Test Evidence**: Logic — all 10 AC in `tests/unit/health-damage/health_damage_skeleton_test.gd`
**Code Review**: Complete — `/code-review` APPROVED WITH SUGGESTIONS; 3 test fixes applied (untyped `rec`, untyped zone `Array`, weak `is_greater(0)` assertion on run_started zone emit)
