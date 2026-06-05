# Story 003: Stub Effects — Blind, Stun, Chill, Stagger

> **Epic**: Status Effects
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: ~2 hours
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-05

## Completion Notes
**Completed**: 2026-06-05
**Criteria**: 6/6 passing (AC-SE-26 `has_status` assertion deferred to Story 005 — stub returns false unconditionally)
**Deviations**: ADVISORY — has_status(CHILL) assertion deferred to Story 005; STAGGER duration_remaining fix applied during code review (emitted 1.0 instead of 0.3 — caught and fixed)
**Test Evidence**: Logic — `tests/unit/status-effects/sem_stub_effects_test.gd` — 9/9 PASSED, 31/31 full suite, 0 orphans
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (all 5 required changes applied)

## Context

**GDD**: `design/gdd/status-effects.md`
**Requirements**: `TR-SE-003`, `TR-SE-007`

**ADR Governing Implementation**: ADR-0011: StatusEffectsManager Public API Contract (primary)
**ADR Decision Summary**: Stubs accept `apply_status()` calls, display their visual indicator (via signal), and hold their duration without executing tick logic. `apply_stun(duration)` is called on EnemyInstance at apply time and is self-terminating in Enemy AI. SEM tracks the instance for expiry signal and wave-clear cleanup only.

**Secondary ADRs**:
- ADR-0004: Float Accumulator Timer Pattern — stub durations tracked via count-down accumulators

**Engine**: Godot 4.6 | **Risk**: MEDIUM (typed Dictionary — Godot 4.4+ required; satisfied by project 4.6 pin)

**Control Manifest Rules (Core layer)**:
- Required: `EnemyInstance must expose apply_stun(duration: float)` — source: ADR-0011
- Forbidden: Never add per-status query helpers (`is_frozen()`, `is_blinded()`, etc.) — source: ADR-0011
- Forbidden: `SEM must not subscribe to CombinationResolution.combo_resolved` — source: ADR-0011

---

## Acceptance Criteria

*From GDD `design/gdd/status-effects.md`, scoped to this story:*

- [ ] **AC-SE-22** — GIVEN `apply_status(enemy, BLIND, 2.0, 0.0)` called, THEN a Blind StatusInstance is created; `status_applied(enemy, BLIND, 2.0)` emitted; no tick logic fires; after 2.0s `status_expired(enemy, BLIND)` emitted and instance removed
- [ ] **AC-SE-23** — GIVEN `apply_status(enemy, STUN, 0.8, 0.0)` called, THEN `enemy.apply_stun(0.8)` called exactly once at application (self-terminating in Enemy AI); after 0.8s `status_expired(enemy, STUN)` emitted when `duration_remaining` reaches 0; no second method call on expiry
- [ ] **AC-SE-24** — GIVEN an enemy with active FREEZE, WHEN `apply_status(enemy, CHILL, 2.0, 0.0)` called, THEN no CHILL StatusInstance created; `apply_speed_modifier` NOT called a second time; `status_applied` NOT emitted for CHILL
- [ ] **AC-SE-25** — GIVEN an enemy with no active Freeze, WHEN `apply_status(enemy, CHILL, 2.0, 0.0)` called, THEN a CHILL StatusInstance created; `enemy.apply_speed_modifier(0.85)` called once (`1.0 - 0.15`); `status_applied(enemy, CHILL, 2.0)` emitted
- [ ] **AC-SE-26** — GIVEN an enemy with active Chill (no Freeze), WHEN the Chill StatusInstance expires, THEN `enemy.apply_speed_modifier(1.0)` called; `has_status(enemy, CHILL)` returns `false`
- [ ] **AC-SE-27** — GIVEN `apply_status(enemy, STAGGER, 0.3, 0.0)` called, THEN `enemy.apply_stun(0.3)` called once at application; `status_applied(enemy, STAGGER, 0.3)` emitted; after 0.3s `status_expired(enemy, STAGGER)` emitted; no second method call on expiry

---

## Implementation Notes

*Derived from ADR-0011 and GDD status-effects.md Rules 4 (steps 6-8) and 6-7:*

**Blind stub** (no tick, no cleanup callback):
- `tick_interval = 0.0` — never ticks
- On apply: emit `status_applied`; create StatusInstance
- On expiry: emit `status_expired`; remove instance. No cleanup method call.

**Stun stub** (Rule 4 step 6):
```gdscript
# On new STUN application:
target.apply_stun(duration)  # self-terminating in Enemy AI
# tick_interval = 0.0 — no ticks
# On expiry: emit status_expired only (no second call to apply_stun)
```
Stun is self-terminating in Enemy AI — the enemy un-stuns itself after `duration`. SEM only needs to know about the instance for the expiry signal and wave-clear cleanup.

**Chill stub — Freeze suppression (Rule 4 step 7)**:
```gdscript
# Before creating a CHILL StatusInstance:
var target_statuses := _active_statuses.get(target.get_instance_id(), [])
for s in target_statuses:
    if s.status_type == GameEnums.BaseStatus.FREEZE:
        return  # FREEZE already active — CHILL suppressed; no instance, no signal

# No FREEZE found — apply CHILL:
target.apply_speed_modifier(1.0 - CHILL_SLOW_PCT)  # = apply_speed_modifier(0.85)
# CHILL expiry cleanup:
target.apply_speed_modifier(1.0)
```
`CHILL_SLOW_PCT = 0.15` (from Prana Data constants)

**Stagger stub** (Rule 4 step 8) — same apply_stun interface as Stun but fixed duration:
```gdscript
# STAGGER_DURATION = 0.3 (fixed; ignore duration parameter for Stagger)
target.apply_stun(STAGGER_DURATION)
```

**`GameEnums.BaseStatus` additions required** (flagged in status-effects.md GDD):
`STATUS_CHILL` and `STATUS_STAGGER` must be added to `GameEnums.BaseStatus` before this story compiles. Confirm these are present in `src/data/game_enums.gd` before implementing.

**Pre-condition from Story 002 code review (2026-06-05):**
`_expire_status` in Story 002 calls `apply_speed_modifier(1.0)` unconditionally when FREEZE expires. If a CHILL StatusInstance pre-dates the FREEZE (CHILL applied before FREEZE was applied — suppression is one-way), the Freeze expiry will restore to 1.0 and silently clobber the active Chill's 0.85 multiplier. Story 003 must make the speed-restore in `_expire_status` status-aware:
```gdscript
# When FREEZE expires, check if CHILL is still active on the same target.
# If yes, restore to CHILL speed (0.85) not full speed (1.0).
if instance.status_type == GameEnums.BaseStatus.FREEZE:
    var has_chill: bool = false
    var remaining := _active_statuses.get(target_id, [])
    for s in remaining:
        if s.status_type == GameEnums.BaseStatus.CHILL:
            has_chill = true
            break
    instance.target.apply_speed_modifier(0.85 if has_chill else 1.0)
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: Freeze speed modifier infrastructure (reused by Chill — must be Done first)
- **Story 004**: Kill cleanup and preparation_started clear (will handle Chill/Stagger expiry cleanup on wave clear)
- **Story 005**: `has_status()` return values for CHILL (AC-SE-26 uses it — Story 005 must be Done for that AC to fully pass in integration)

---

## QA Test Cases

*Sourced from `production/qa/qa-plan-sprint-3-2026-06-03.md` (S3-05). Do not invent new test cases during implementation.*

**AC-SE-22** — Blind stub: instance + signals, no tick
- Given: Enemy node; SEM initialized (Stories 001-002 Done)
- When: `apply_status(enemy, BLIND, 2.0, 0.0)` called; `_process(delta)` driven to 2.0s
- Then: StatusInstance created at apply; `status_applied(enemy, BLIND, 2.0)` emitted once; no `apply_damage` or `apply_heal` calls during the 2.0s; `status_expired(enemy, BLIND)` emitted once after 2.0s; instance removed
- Edge cases: Re-apply during active Blind resets duration (same re-apply logic as Burn)

**AC-SE-23** — Stun stub: apply_stun called once, no second call on expiry
- Given: Enemy node with mock `apply_stun(duration)` method; SEM initialized
- When: `apply_status(enemy, STUN, 0.8, 0.0)` called; `_process(delta)` driven to 0.8s
- Then: `apply_stun` spy called exactly once at apply time with `0.8`; after 0.8s `status_expired(enemy, STUN)` emitted; `apply_stun` spy call count remains 1 (no second call on expiry)
- Edge cases: Stun during active Freeze — Freeze timer still decrements (Stun/Freeze timer pause is VS scope per GDD Rule 5 note)

**AC-SE-24** — Chill suppressed when FREEZE active
- Given: Enemy with active FREEZE StatusInstance; `apply_speed_modifier` spy
- When: `apply_status(enemy, CHILL, 2.0, 0.0)` called
- Then: No CHILL StatusInstance in `_active_statuses`; `apply_speed_modifier` spy call count unchanged (no new call); `status_applied` NOT emitted for CHILL
- Edge cases: FREEZE expires AFTER Chill suppression — Chill is never retroactively created; player must re-cast Chill after Freeze expires

**AC-SE-25** — Chill applies speed modifier when no FREEZE active
- Given: Enemy with no active FREEZE; `apply_speed_modifier` mock
- When: `apply_status(enemy, CHILL, 2.0, 0.0)` called
- Then: `apply_speed_modifier` called once with `0.85` (`1.0 - 0.15`); CHILL StatusInstance in registry; `status_applied(enemy, CHILL, 2.0)` emitted
- Edge cases: `CHILL_SLOW_PCT = 0.15` — confirm constant is read from Prana Data, not hardcoded

**AC-SE-26** — Chill expiry restores full speed
- Given: Active CHILL on enemy (no FREEZE); `apply_speed_modifier` spy
- When: `_process(delta)` driven until Chill `duration_remaining <= 0`
- Then: `apply_speed_modifier` called with `1.0`; CHILL instance removed from registry
- Edge cases: `has_status(enemy, CHILL)` returns false after expiry (requires Story 005 `has_status()` to be Done for this assertion)

**AC-SE-27** — Stagger: apply_stun with fixed 0.3s, no second call on expiry
- Given: Enemy node with `apply_stun` mock
- When: `apply_status(enemy, STAGGER, 0.3, 0.0)` called; `_process(delta)` driven to 0.3s
- Then: `apply_stun` spy called once with `0.3`; `status_applied(enemy, STAGGER, 0.3)` emitted; after 0.3s `status_expired(enemy, STAGGER)` emitted; `apply_stun` spy count remains 1
- Edge cases: `STAGGER_DURATION = 0.3` is fixed regardless of `duration` parameter passed

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/status-effects/sem_stub_effects_test.gd` — must exist and pass headless

**Status**: [x] Complete — `tests/unit/status-effects/sem_stub_effects_test.gd`, 9/9 PASS (GdUnit4 v6.1.3, Godot 4.6.2)

---

## Dependencies

- Depends on: Story 002 must be Done (Chill suppression check requires FREEZE StatusInstance detection; `apply_speed_modifier` infrastructure from Story 002)
- Unlocks: Story 004 (cleanup must handle Chill/Stagger instances too)
