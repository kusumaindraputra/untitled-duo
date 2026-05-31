# Story 005: Death Signals, Heavy Hit, and First-Run Mercy

> **Epic**: Health & Damage
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: ~3h
> **Manifest Version**: 2026-05-30
> **Last Updated**: 2026-05-31

## Context

**GDD**: `design/gdd/health-damage.md`
**Requirement**: `TR-HD-007`, `TR-HD-010`

**ADR Governing Implementation**: ADR-0007: HealthAndDamage Singleton
**ADR Decision Summary**: `enemy_killed(instance_id, type_id, prana_affiliation)` emitted once per enemy death, fires from within `apply_damage()`. `player_died` emits once per run; subsequent damage on dead Fayde is silently rejected by the dead-target guard (Story 002). `heavy_hit(target, final_damage)` fires when `final_damage >= HEAVY_HIT_THRESHOLD`. First-run mercy multiplies CONTACT final_damage by `FIRST_RUN_DAMAGE_MULTIPLIER` (0.5) when `_first_run_active=true`.

**Secondary ADRs**: ADR-0003 (signals), ADR-0014 (enemy_killed feeds WaveManager kill counter)

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules (Core layer)**:
- Required: `enemy_killed` is the sole death signal — WaveManager and Prana Drop listen to it.
- Required: Enemy node is guaranteed alive for at least one frame after `enemy_killed` fires (EnemyInstance calls `queue_free()` in its own handler).
- Forbidden: Never re-emit `player_died` if Fayde is already dead.

---

## Acceptance Criteria

*From GDD `design/gdd/health-damage.md`, scoped to this story:*

- [ ] **AC-HD-13** — Given enemy `current_hp=5`, `apply_damage(enemy, 5.0, null, CONTACT)`: `current_hp=0` and `enemy_killed(instance_id, type_id, prana_affiliation)` emitted once.
- [ ] **AC-HD-14** — Given Fayde `current_hp=10`, `apply_damage(fayde, 15.0, null, CONTACT)`: `current_hp=0` and `player_died` emitted once.
- [ ] **AC-HD-15** — Given Fayde already in DEAD state: `apply_damage(fayde, 20.0, null, CONTACT)` does not re-emit `player_died`.
- [ ] **AC-HD-16** — Given 3 enemies killed: `enemy_killed` emitted exactly 3 times with distinct `instance_id` values.
- [ ] **AC-HD-28** — Given `final_damage=20` (above `HEAVY_HIT_THRESHOLD=15`): `damage_taken(target, 20, ...)` and `heavy_hit(target, 20)` both emitted in same `apply_damage` call.
- [ ] **AC-HD-29** — Given `final_damage=4` (below threshold): `heavy_hit` NOT emitted; `damage_taken` emitted normally.
- [ ] **AC-HD-30** — Given `_first_run_active=true`, Fayde receives CONTACT `base_damage=20.0, element=null`: `final_damage=round(20 × 0.5)=10`; HP decreases by 10.
- [ ] **AC-HD-31** — Given `_first_run_active=false`, same CONTACT `base_damage=20.0`: `final_damage=20` (no mercy).

---

## Implementation Notes

*Derived from ADR-0007 step 5 and first-run mercy:*

**Step 5 — death check (add to `apply_damage()` after step 4 signals):**
```gdscript
# Step 5 — death check
if _get_current_hp(target) <= 0.0:
    if target.is_in_group(&"player"):
        _fayde_dead = true
        emit_signal("player_died")
    else:
        var id := target.get_instance_id()
        var inst: EnemyHPInstance = _enemy_registry[id]
        inst.is_dead = true
        emit_signal("enemy_killed", id, inst.type_id, inst.prana_affiliation)
        _enemy_registry.erase(id)  # unregister on kill
```

**heavy_hit — add to step 4 (after damage_taken):**
```gdscript
if final_damage >= HEAVY_HIT_THRESHOLD:
    emit_signal("heavy_hit", target, final_damage)
```

**First-run mercy — add as step 2b (after formula, before apply):**
```gdscript
# Step 2b — first-run mercy (CONTACT to Fayde only)
if target.is_in_group(&"player") and source == GameEnums.DamageSource.CONTACT and _first_run_active:
    final_damage = roundi(float(final_damage) * FIRST_RUN_DAMAGE_MULTIPLIER)
    final_damage = clampi(final_damage, 0, roundi(_get_current_hp(target)))
```

**Signal declarations (add to class):**
```gdscript
signal damage_taken(target: Node, final_damage: int, current_hp: int)
signal health_restored(target: Node, healed_amount: int, current_hp: int)
signal player_died()
signal enemy_killed(instance_id: int, type_id: int, prana_affiliation: GameEnums.DamageClass)
signal heavy_hit(target: Node, final_damage: int)
signal player_hp_zone_changed(zone: GameEnums.HPZone)
```

**Note on `_first_run_active` lifecycle**: H&D holds the flag; Tutorial/Onboarding owns the lifecycle. For FP scope, initialize `_first_run_active = false` (no tutorial at FP). The flag is a test-accessible var — set directly in tests for AC-HD-30/31.

**Note on enemy unregistration**: `_enemy_registry.erase(id)` in step 5 is H&D's internal cleanup — WaveManager never calls `unregister_enemy()`. This matches ADR-0014.

---

## Out of Scope

- Story 002: Dead-target guard (step 1, `_fayde_dead` check) — already implemented there
- Story 004: Zone signals — `_check_hp_zone_change()` continues to fire at step 4 before death check; a killing blow still fires zone signals if crossing into DESPERATE before HP reaches 0

---

## QA Test Cases

**AC-HD-13 — Enemy kill emits enemy_killed once**
- Given: enemy registered with `current_hp=5.0`
- When: `apply_damage(enemy, 5.0, null, CONTACT)`
- Then: `enemy_killed` emit count == 1; args match `(instance_id, type_id, prana_affiliation)` of the registered enemy

**AC-HD-14 — Fayde death emits player_died once**
- Given: `_fayde_current_hp = 10.0`, `_fayde_dead = false`
- When: `apply_damage(fayde, 15.0, null, CONTACT)` → final_damage=10 (clamped); HP=0
- Then: `player_died` emit count == 1; `_fayde_dead == true`

**AC-HD-15 — No player_died re-emit after death**
- Given: Fayde dead (`_fayde_dead = true`, `current_hp = 0`)
- When: `apply_damage(fayde, 20.0, null, CONTACT)`
- Then: `player_died` emit count == 0; `current_hp` still 0

**AC-HD-16 — enemy_killed emitted for each enemy with distinct IDs**
- Given: 3 enemies registered with distinct node instance IDs; all at 1.0 HP
- When: `apply_damage(enemy_N, 1.0, null, CONTACT)` for each
- Then: `enemy_killed` emit count == 3; all 3 `instance_id` args are distinct

**AC-HD-28 — heavy_hit fires with damage_taken on heavy blow**
- Given: target alive with `current_hp > 20`
- When: `apply_damage(target, 20.0, null, DIRECT)` → final_damage=20 (>HEAVY_HIT_THRESHOLD=15)
- Then: `damage_taken` emit count == 1 AND `heavy_hit` emit count == 1; `heavy_hit` arg `final_damage == 20`

**AC-HD-29 — heavy_hit NOT fired on light blow**
- Given: target alive
- When: `apply_damage(target, 4.0, null, CONTACT)` → final_damage=4 (<15)
- Then: `damage_taken` emit count == 1; `heavy_hit` emit count == 0

**AC-HD-30 — First-run mercy halves CONTACT damage**
- Given: `_first_run_active = true`; `_fayde_current_hp = 100.0`
- When: `apply_damage(fayde, 20.0, null, CONTACT)`
- Then: `_fayde_current_hp == 90.0` (final_damage=10, not 20); `damage_taken(fayde, 10, 90)` emitted

**AC-HD-31 — No mercy when first_run_active false**
- Given: `_first_run_active = false`; `_fayde_current_hp = 100.0`
- When: `apply_damage(fayde, 20.0, null, CONTACT)`
- Then: `_fayde_current_hp == 80.0` (final_damage=20); `damage_taken(fayde, 20, 80)` emitted

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/health-damage/death_and_heavy_hit_test.gd` — must pass headless

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (apply_damage pipeline must exist — this story adds step 5 and mercy to it), Story 001 (enemy registry for AC-HD-13, 16)
- Unlocks: Epic complete. All TR-HD-001–012 covered across Stories 001–005.
