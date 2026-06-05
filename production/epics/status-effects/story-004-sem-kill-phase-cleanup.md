# Story 004: Kill Cleanup and Phase Clear

> **Epic**: Status Effects
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: ~2 hours
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-05

## Context

**GDD**: `design/gdd/status-effects.md`
**Requirement**: `TR-SE-009`

**ADR Governing Implementation**: ADR-0011: StatusEffectsManager Public API Contract (primary)
**ADR Decision Summary**: SEM listens to `HealthAndDamage.enemy_killed` to clear all status instances for a dead target (with per-type cleanup callbacks, but WITHOUT emitting `status_expired`). SEM listens to `GameStateManager.preparation_started` to clear ALL active statuses across all targets (with cleanup callbacks, no signals).

**Secondary ADRs**:
- ADR-0003: Signal-Driven Architecture — connect to signals in `_ready()`; scene nodes must disconnect in `_exit_tree()`
- ADR-0002: Autoload Architecture — SEM is Autoload #7; H&D is #6, GSM is #3 — both already initialized before SEM's `_ready()` fires

**Engine**: Godot 4.6 | **Risk**: MEDIUM (typed Dictionary — Godot 4.4+ required; satisfied)

**Control Manifest Rules (Core layer)**:
- Required: Connect to signals in `_ready()`, never in `_init()` — source: ADR-0003
- Required: Use Callable syntax: `signal.connect(_handler)` — source: ADR-0003
- Forbidden: No circular Autoload-to-Autoload signal subscriptions — source: ADR-0003

---

## Acceptance Criteria

*From GDD `design/gdd/status-effects.md`, scoped to this story:*

- [x] **AC-SE-12** — GIVEN an enemy with active Burn AND active Freeze, WHEN `HealthDamage.enemy_killed` fires for that enemy, THEN both StatusInstances are removed from `_active_statuses`; `apply_speed_modifier(1.0)` called on the enemy node (Freeze cleanup restores full speed); no further tick calls for that enemy after cleanup
- [x] **AC-SE-19** — GIVEN enemies with active Burn and active Freeze, WHEN `preparation_started` fires, THEN `_active_statuses` is empty; `apply_speed_modifier(1.0)` called on the Frozen enemy (restoring full speed); no tick fires after the clear

---

## Implementation Notes

*Derived from ADR-0011 and GDD status-effects.md Rules 8 and 9:*

**`_on_enemy_killed(instance_id: int, type_id: int, prana_affiliation)` (Rule 8)**:
```gdscript
func _on_enemy_killed(instance_id: int, type_id: int, prana_affiliation) -> void:
    # Note: Burn Contagion fires BEFORE cleanup (Story 005 handles this)
    if not _active_statuses.has(instance_id):
        return
    for instance in _active_statuses[instance_id]:
        _run_expiry_cleanup(instance)  # speed restore etc — no signals emitted
    _active_statuses.erase(instance_id)
```
**Do NOT emit `status_expired`** on kill cleanup — VFX cleanup is handled by death animation. The `status_expired` signal is only for natural duration expiry.

**`_on_preparation_started(...)` (Rule 9)**:
```gdscript
func _on_preparation_started(_wave_index: int = 0, _waves_remaining: int = 0) -> void:
    for target_id in _active_statuses.keys():
        for instance in _active_statuses[target_id]:
            _run_expiry_cleanup(instance)  # restore speed, etc — no signals
    _active_statuses.clear()
```
**Do NOT emit any signals** — wave has ended; all targets are being reset. No `status_expired` emissions.

**`_run_expiry_cleanup(instance: StatusInstance)` helper** (internal, not public):
```gdscript
func _run_expiry_cleanup(instance: StatusInstance) -> void:
    match instance.status_type:
        GameEnums.BaseStatus.FREEZE:
            instance.target.apply_speed_modifier(1.0)
        GameEnums.BaseStatus.CHILL:
            instance.target.apply_speed_modifier(1.0)
        # BURN, BLIND, STUN, STAGGER: no cleanup call needed
        # REGENERATE: healing just stops
```

**Signal connection in `_ready()`** (connections were stubbed in Story 001 — flesh them out here):
```gdscript
func _ready() -> void:
    HealthAndDamage.enemy_killed.connect(_on_enemy_killed)
    GameStateManager.preparation_started.connect(_on_preparation_started)
```

**Integration test scope**: This story crosses the H&D and GSM signal boundaries — the integration test should wire real (or realistic mock) signal emitters to confirm the handlers fire and the registry is correctly cleared.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 005**: Burn Contagion fires inside `_on_enemy_killed()` BEFORE cleanup. Story 004 only handles the cleanup loop; Story 005 adds the Contagion check that must run first.
- Natural status expiry (`status_expired` signal): handled by the `_process()` tick loop in Stories 001-003.

---

## QA Test Cases

*Sourced from `production/qa/qa-plan-sprint-3-2026-06-03.md` (S3-05). Do not invent new test cases during implementation.*

**AC-SE-12** — Kill cleanup removes all instances and restores Freeze speed
- Given: Enemy with active Burn StatusInstance AND active Freeze StatusInstance; `apply_speed_modifier` spy; H&D real or mock signal emitter
- When: `HealthDamage.enemy_killed` emitted with the enemy's instance_id
- Then: `_active_statuses[enemy.get_instance_id()]` key removed (or array empty); `apply_speed_modifier` spy called once with `1.0` (Freeze cleanup); no `apply_damage` calls for that enemy after cleanup; `status_expired` NOT emitted (kill cleanup is silent)
- Edge cases: Enemy with only Burn (no Freeze): cleanup runs but no `apply_speed_modifier` call; Enemy with Chill: `apply_speed_modifier(1.0)` also called

**AC-SE-19** — Phase clear removes all instances across all targets
- Given: Enemy A with active Burn; Enemy B with active Freeze; `apply_speed_modifier` spy on Enemy B; GSM real or mock signal emitter
- When: `GameStateManager.preparation_started` emitted
- Then: `_active_statuses` dictionary is empty (`.is_empty() == true`); `apply_speed_modifier` spy on Enemy B called once with `1.0`; no tick fires for Enemy A or Enemy B after clear (drive `_process(delta)` for one more frame — no `apply_damage` calls)
- Edge cases: `preparation_started` fires while tick accumulator is mid-countdown — instances cleared before next tick loop iteration; tick loop skips cleared instances (iterating a copy of the array handles this safely)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/status-effects/sem_cleanup_integration_test.gd` — must exist and pass headless

**Status**: [x] Created — `tests/integration/status-effects/sem_cleanup_integration_test.gd` (10 tests)

---

## Dependencies

- Depends on: Stories 001, 002, and 003 must be Done (all StatusInstance types must exist before cleanup logic is meaningful)
- Unlocks: Story 005 (Burn Contagion fires inside `_on_enemy_killed()` before the cleanup loop — Story 004's cleanup must exist first for Story 005 to insert Contagion before it)

---

## Completion Notes

**Completed**: 2026-06-05
**Criteria**: 2/2 passing
**Deviations**:
- ADVISORY: `_run_expiry_cleanup` signature uses `(target_id: int)` bulk-per-target form vs. story spec's `(instance: StatusInstance)` per-instance form. Functionally equivalent; refactoring is cleaner. Logged to tech-debt-register.
- ADVISORY: Open code quality items (CHILL_SLOW_PCT naming asymmetry, `apply_status` 49-line length, per-frame `keys()` allocations). Non-correctness. Logged to tech-debt-register.
**Test Evidence**: Integration test at `tests/integration/status-effects/sem_cleanup_integration_test.gd` — 10 tests covering all ACs including BURN+FREEZE kill combo and post-cleanup tick-stop assertions
**Code Review**: Complete — `/code-review` run this session, verdict APPROVED WITH SUGGESTIONS; all 3 BLOCKING findings fixed before story-done
