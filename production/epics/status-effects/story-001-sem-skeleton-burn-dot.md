# Story 001: SEM Skeleton, StatusInstance, and Burn DoT

> **Epic**: Status Effects
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: ~3 hours
> **Manifest Version**: 2026-06-03
> **Last Updated**: —

## Context

**GDD**: `design/gdd/status-effects.md`
**Requirements**: `TR-SE-001`, `TR-SE-002`, `TR-SE-003`

**ADR Governing Implementation**: ADR-0011: StatusEffectsManager Public API Contract (primary)
**ADR Decision Summary**: SEM exposes three public methods (`apply_status`, `has_status`, `check_and_apply_shatter`) and four signals. No per-status helpers. All timing via float accumulators in `_process(delta)`.

**Secondary ADRs**:
- ADR-0004: Float Accumulator Timer Pattern — tick loop uses `_process(delta)` with decrement (not reset) pattern
- ADR-0002: Autoload Architecture — register as Autoload #7; connect signals in `_ready()` only

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `Dictionary[int, Array[StatusInstance]]` typed dictionary syntax requires Godot 4.4+. Project is pinned to 4.6 — satisfied. **Pre-implementation check**: confirm `Dictionary[int, Array[StatusInstance]]` is accepted by the Godot 4.6 GDScript parser with no error before writing any SEM code (ADR-0011 AC-0011-01).

**Control Manifest Rules (Core layer)**:
- Required: `apply_status(target, status_type, duration, spell_base_damage: float = 0.0)` — 4-arg signature; spell_base_damage required non-zero for Burn ticks
- Required: All in-game timing uses float delta accumulators in `_process(delta)` — decrement by `tick_rate`, never reset to 0.0
- Required: Connect signals in `_ready()`, never in `_init()`
- Required: `process_mode = PROCESS_MODE_PAUSABLE`
- Forbidden: Never use Timer nodes or `SceneTree.create_timer()` for gameplay timing
- Forbidden: Never add per-status helpers (`is_frozen()`, `is_blinded()`, etc.) — `has_status()` is the sole interface

---

## Acceptance Criteria

*From GDD `design/gdd/status-effects.md`, scoped to this story:*

- [ ] **AC-SE-01** — GIVEN `apply_status(enemy, BURN, 2.0, 20.0)` is called, THEN `_active_statuses` contains exactly one Burn StatusInstance for that enemy with `duration_remaining ≈ 2.0s`; `status_applied(enemy, BURN, 2.0)` emitted once
- [ ] **AC-SE-02** — GIVEN an active Burn instance (`tick_interval=0.5s`, `spell_base_damage=20.0`), WHEN 0.5s elapses via `_process(delta)`, THEN `HealthDamage.apply_damage(enemy, 1.6, null, DamageSource.DOT)` called once (Formula 1: `max(0, 20.0) × 0.08 = 1.6`; assert value passed, not H&D's rounded output)
- [ ] **AC-SE-03** — GIVEN an active Burn whose `duration_remaining` reaches 0, THEN the StatusInstance is removed from `_active_statuses`; `status_expired(enemy, BURN)` emitted once; no additional tick fires after expiry
- [ ] **AC-SE-04** — GIVEN Burn with 1.0s remaining at `spell_base_damage=20.0`, WHEN `apply_status(enemy, BURN, 2.0, 30.0)` is called, THEN `duration_remaining ≈ 2.0s`; `spell_base_damage = 30.0`; exactly one Burn StatusInstance exists; `status_applied` emitted once
- [ ] **AC-SE-09** — GIVEN `apply_status(fayde, BURN, 2.0, 20.0)` is called (Burn is enemies-only), THEN no StatusInstance created; error logged; `status_applied` NOT emitted
- [ ] **AC-SE-11** — GIVEN an enemy with `current_hp=0` (i.e. `is_alive()` returns false), WHEN `apply_status(enemy, BURN, 2.0, 20.0)` is called, THEN no StatusInstance created; `status_applied` NOT emitted
- [ ] **AC-SE-20** — GIVEN `apply_status(enemy, BURN, 0.0, 20.0)` is called, THEN no StatusInstance created; error logged

---

## Implementation Notes

*Derived from ADR-0011 and ADR-0004:*

**StatusInstance inner class** (GDScript class, not a Node):
```gdscript
class StatusInstance:
    var target:            Node
    var status_type:       GameEnums.BaseStatus
    var duration_remaining: float
    var tick_interval:     float  # 0.5s for Burn; 0.0 for no-tick statuses
    var tick_timer:        float  # accumulator counting down to next tick
    var spell_base_damage: float  # captured at apply time; updated on re-apply
```

**Registry**: `var _active_statuses: Dictionary[int, Array[StatusInstance]] = {}`
keyed by `target.get_instance_id()`.

**`_ready()` signal connections**:
```gdscript
HealthAndDamage.enemy_killed.connect(_on_enemy_killed)
GameStateManager.preparation_started.connect(_on_preparation_started)
```

**`apply_status()` steps (Rule 4)**:
1. Validate target scope via `is_in_group()`: Burn/Freeze/Blind/Stun → `&"enemy"`; Regen → `&"player"`. Log error and return on mismatch.
2. Check `target.is_alive()` — log error and return if false.
3. Look up `_active_statuses[target.get_instance_id()]`. Search for existing StatusInstance with matching `status_type`.
4. If found (re-apply): reset `duration_remaining = duration`; reset `tick_timer = 0`; update `spell_base_damage`. Emit `status_applied`.
5. If not found (new): create StatusInstance with `tick_timer = tick_interval` (first tick fires after one interval, NOT immediately). Append to registry. Emit `status_applied`.

**Tick loop `_process(delta)` (Rule 5)** — iterate a **copy** of the array to handle mid-loop expiry:
```gdscript
for instance in _active_statuses.get(target_id, []).duplicate():
    instance.duration_remaining -= delta
    if instance.tick_interval > 0.0:
        instance.tick_timer -= delta
        if instance.tick_timer <= 0.0:
            _fire_tick(instance)
            instance.tick_timer = instance.tick_interval  # decrement, not reset
    if instance.duration_remaining <= 0.0:
        _expire_status(instance)
```

**Burn tick** (Rule 6): `HealthDamage.apply_damage(target, max(0.0, spell_base_damage) * BURN_TICK_MAGNITUDE, null, DamageSource.DOT)`
where `BURN_TICK_MAGNITUDE = 0.08` (from Prana Data constants).

**Status expiry** (Rule 7): remove from `_active_statuses`; emit `status_expired`. Burn has no cleanup callback.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: Freeze (`apply_speed_modifier`) and Regen (heal tick)
- **Story 003**: Blind, Stun, Chill, Stagger stubs
- **Story 004**: `_on_enemy_killed()` cleanup and `_on_preparation_started()` clear
- **Story 005**: `check_and_apply_shatter()`, `has_status()`, Burn Contagion

---

## QA Test Cases

*Sourced from `production/qa/qa-plan-sprint-3-2026-06-03.md` (S3-05). Do not invent new test cases during implementation.*

**AC-SE-01** — Burn apply creates registry entry and emits signal
- Given: Enemy node with no active statuses; SEM initialized
- When: `apply_status(enemy, BURN, 2.0, 20.0)` called
- Then: `_active_statuses[enemy.get_instance_id()]` contains exactly 1 StatusInstance with `duration_remaining ≈ 2.0`; `status_applied` signal spy received exactly 1 call with `(enemy, BURN, 2.0)`
- Edge cases: Second call while active triggers re-apply path (Story 001 AC-SE-04), not double-entry

**AC-SE-02** — Burn tick fires at 0.5s with correct damage value
- Given: Active Burn instance with `tick_interval=0.5`, `spell_base_damage=20.0`; H&D mock injected
- When: `_process(delta)` driven until cumulative delta = 0.5s
- Then: H&D mock's `apply_damage` called once with `(enemy, 1.6, null, DOT)`; the raw value 1.6 is asserted (not H&D's `roundi(1.6)=2`)
- Edge cases: `spell_base_damage=0.0` → tick calls `apply_damage` with `max(0, 0.0)*0.08=0.0`; no negative DoT

**AC-SE-03** — Burn expiry removes instance and emits expired signal
- Given: Active Burn with `duration_remaining` reaching 0 via `_process`
- When: Accumulator decrements past 0
- Then: `_active_statuses` no longer contains StatusInstance for that enemy; `status_expired(enemy, BURN)` emitted once; no further `apply_damage` call after removal
- Edge cases: If a tick fires on the same frame as expiry, the tick must fire before the instance is removed (tick loop runs first, then expiry check in same iteration)

**AC-SE-04** — Burn re-apply resets duration and damage, maintains single instance
- Given: Active Burn with `duration_remaining=1.0`, `spell_base_damage=20.0`
- When: `apply_status(enemy, BURN, 2.0, 30.0)` called
- Then: `duration_remaining ≈ 2.0`; `spell_base_damage == 30.0`; exactly 1 Burn StatusInstance in registry; `status_applied` emitted once; `tick_timer` reset to 0 (next tick fires at next full interval)
- Edge cases: Re-apply at tick 3 (1 tick remaining) fully restores 4 ticks from new base

**AC-SE-09** — Target scope guard rejects Burn on player
- Given: Fayde node in `&"player"` group
- When: `apply_status(fayde, BURN, 2.0, 20.0)` called
- Then: No StatusInstance created; `push_error()` called; `status_applied` NOT emitted
- Edge cases: Same test for all offensive statuses (Freeze, Blind, Stun) on Fayde

**AC-SE-11** — Dead target guard rejects apply on hp=0 enemy
- Given: Enemy node with `is_alive()` returning false (current_hp=0)
- When: `apply_status(enemy, BURN, 2.0, 20.0)` called
- Then: No StatusInstance created; `status_applied` NOT emitted
- Edge cases: Race condition: `is_alive()` returns false AND `enemy_killed` fires in same frame — both guards prevent StatusInstance creation

**AC-SE-20** — Zero-duration guard rejects apply
- Given: Enemy node with `is_alive()` returning true
- When: `apply_status(enemy, BURN, 0.0, 20.0)` called
- Then: No StatusInstance created; `push_error()` called
- Edge cases: `duration = -1.0` (negative) — same guard should catch it

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/status-effects/sem_skeleton_burn_test.gd` — must exist and pass headless

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None — this is the foundation story
- Unlocks: Story 002 (Freeze/Regen), Story 003 (Stubs), Story 004 (Cleanup), Story 005 (Contagion/Shatter)
