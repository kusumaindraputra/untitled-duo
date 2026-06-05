# Story 005: Burn Contagion and Shatter

> **Epic**: Status Effects
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: ~2 hours
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-05

## Context

**GDD**: `design/gdd/status-effects.md`
**Requirements**: `TR-SE-004`, `TR-SE-005`, `TR-SE-008`

**ADR Governing Implementation**: ADR-0011: StatusEffectsManager Public API Contract (primary)
**ADR Decision Summary**: `check_and_apply_shatter()` and `has_status()` are public methods on SEM. SC&E must call `check_and_apply_shatter()` before every DIRECT `apply_damage()` — not `has_status(target, FREEZE)` directly. Shatter does NOT consume the Freeze status.

**Secondary ADRs**:
- ADR-0003: Signal-Driven Architecture — `burn_contagion_triggered` and `shatter_triggered` are signals (Pattern 1)

**Engine**: Godot 4.6 | **Risk**: MEDIUM (typed Dictionary — Godot 4.4+ required; satisfied)

**Control Manifest Rules (Core layer)**:
- Required: `SC&E must call check_and_apply_shatter(target, base_damage) before every DIRECT apply_damage() call` — source: ADR-0011
- Forbidden: Never add per-status query helpers (`is_frozen()`, etc.) — `has_status()` is the sole interface — source: ADR-0011
- Forbidden: `SEM must not subscribe to CombinationResolution.combo_resolved` — source: ADR-0011

---

## Acceptance Criteria

*From GDD `design/gdd/status-effects.md`, scoped to this story:*

- [ ] **AC-SE-13** — GIVEN an enemy with active Burn (`spell_base_damage=20.0`) dies while a second enemy is within 200px, WHEN `enemy_killed` fires, THEN `apply_status(second_enemy, BURN, 2.0, 20.0)` is called and `burn_contagion_triggered(dying_pos, second_enemy)` emitted once
- [ ] **AC-SE-14** — GIVEN an enemy with active Burn dies while NO other enemy is within 200px, THEN no Contagion transfer occurs; `burn_contagion_triggered` NOT emitted
- [ ] **AC-SE-15** — GIVEN an enemy with active Burn dies while a second enemy is exactly 201px away (outside range), THEN Contagion does NOT transfer
- [ ] **AC-SE-16** — GIVEN an enemy with active Freeze, WHEN `check_and_apply_shatter(enemy, 16.0)` called, THEN return value is `20.0` (`16.0 × 1.25`); `shatter_triggered(enemy)` emitted once
- [ ] **AC-SE-17** — GIVEN an enemy WITHOUT active Freeze, WHEN `check_and_apply_shatter(enemy, 16.0)` called, THEN return value is `16.0` unchanged; `shatter_triggered` NOT emitted
- [ ] **AC-SE-18** — GIVEN a Frozen enemy hit by two DIRECT spells, WHEN `check_and_apply_shatter` called twice for the same target, THEN both calls return `1.25×` value; Freeze StatusInstance remains active (Shatter is non-consuming)

---

## Implementation Notes

*Derived from ADR-0011 and GDD status-effects.md Rule 10:*

**`has_status(target: Node, status_type: GameEnums.BaseStatus) -> bool`**:
```gdscript
func has_status(target: Node, status_type: GameEnums.BaseStatus) -> bool:
    var instances := _active_statuses.get(target.get_instance_id(), [])
    for instance in instances:
        if instance.status_type == status_type:
            return true
    return false
```
O(N) where N = active statuses per target (max 7). Called by `check_and_apply_shatter()` internally.

**`check_and_apply_shatter(target: Node, base_damage: float) -> float`** (Rule 10):
```gdscript
func check_and_apply_shatter(target: Node, base_damage: float) -> float:
    if has_status(target, GameEnums.BaseStatus.FREEZE):
        shatter_triggered.emit(target)
        return base_damage * SHATTER_MULTIPLIER  # 1.25
    return base_damage
```
`SHATTER_MULTIPLIER = 1.25` (from Prana Data constants, registered in entities.yaml).
Freeze is NOT removed — it runs to its full duration.

**Burn Contagion in `_on_enemy_killed()` — fires BEFORE cleanup** (Rule 8, GDD note):
```gdscript
# Insert at the TOP of _on_enemy_killed(), before the cleanup loop:
var dying_instances := _active_statuses.get(instance_id, [])
for instance in dying_instances:
    if instance.status_type == GameEnums.BaseStatus.BURN:
        _try_burn_contagion(instance.target.global_position, instance.spell_base_damage)
        break  # Only one Burn instance per target possible
```

**`_try_burn_contagion(dying_pos: Vector2, original_spell_base: float)`** (internal helper):
```gdscript
func _try_burn_contagion(dying_pos: Vector2, original_spell_base: float) -> void:
    # Scan all living enemies for nearest within BURN_CONTAGION_RANGE (200px)
    var nearest_node: Node = null
    var nearest_dist: float = BURN_CONTAGION_RANGE + 1.0
    for target_id in _active_statuses.keys():
        # ... iterate get_tree().get_nodes_in_group(&"enemy") to find nodes
    # Alternatively: use get_tree().get_nodes_in_group(&"enemy") directly
    var candidates := get_tree().get_nodes_in_group(&"enemy")
    for candidate in candidates:
        if not is_instance_valid(candidate):
            continue
        var dist: float = candidate.global_position.distance_to(dying_pos)
        if dist <= BURN_CONTAGION_RANGE and dist < nearest_dist:
            nearest_dist = dist
            nearest_node = candidate
    if nearest_node != null:
        apply_status(nearest_node, GameEnums.BaseStatus.BURN,
                     BURN_CONTAGION_DURATION, original_spell_base)
        burn_contagion_triggered.emit(dying_pos, nearest_node)
```
`BURN_CONTAGION_RANGE = 200` (px), `BURN_CONTAGION_DURATION = 2.0s` (both from Prana Data constants).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 004**: The cleanup loop in `_on_enemy_killed()` that fires AFTER Contagion. Story 004 must be Done first.
- Shatter at FP scope: at First Playable, SC&E uses field-write stubs (`target.status_freeze_timer`) and does NOT call `check_and_apply_shatter()`. This story implements the method; it will be inert until SC&E is wired at MVP. Tests verify the method in isolation using a mock target with an active FREEZE StatusInstance.

---

## QA Test Cases

*Sourced from `production/qa/qa-plan-sprint-3-2026-06-03.md` (S3-05). Do not invent new test cases during implementation.*

**AC-SE-13** — Burn Contagion transfers to nearest enemy within 200px on death
- Given: Enemy A with active Burn (`spell_base_damage=20.0`) at position (0,0); Enemy B at position (150,0) (150px away); `_active_statuses` contains entries for both; SEM in scene
- When: `HealthDamage.enemy_killed` fires for Enemy A
- Then: `apply_status(enemy_B, BURN, 2.0, 20.0)` called (verify via `_active_statuses` having new BURN for Enemy B); `burn_contagion_triggered` emitted once with `(Vector2(0,0), enemy_B)`
- Edge cases: Enemy B already has active Burn — re-apply path fires (not a new instance)

**AC-SE-14** — Burn Contagion does not fire when no enemy in range
- Given: Enemy A with active Burn; no other enemy nodes in `&"enemy"` group (or all > 200px away)
- When: `enemy_killed` fires for Enemy A
- Then: No new `apply_status` calls; `burn_contagion_triggered` NOT emitted
- Edge cases: `get_tree().get_nodes_in_group(&"enemy")` returns empty array — no crash, no transfer

**AC-SE-15** — Burn Contagion boundary: 201px = no transfer
- Given: Enemy A with active Burn at (0,0); Enemy B at (201,0) (201px away — outside 200px range)
- When: `enemy_killed` fires for Enemy A
- Then: No Contagion transfer; `burn_contagion_triggered` NOT emitted
- Edge cases: Enemy B at exactly 200px: transfer fires (`<= BURN_CONTAGION_RANGE` is inclusive boundary per GDD Formula 5)

**AC-SE-16** — Shatter returns 1.25× and emits signal for frozen target
- Given: Enemy with active FREEZE StatusInstance in registry; `check_and_apply_shatter` spy on `shatter_triggered`
- When: `check_and_apply_shatter(enemy, 16.0)` called
- Then: Return value == 20.0 (16.0 × 1.25); `shatter_triggered` emitted once with `(enemy)`; FREEZE StatusInstance still present in `_active_statuses` after call
- Edge cases: `base_damage = 0.0` → returns 0.0 (0 × 1.25); no divide-by-zero

**AC-SE-17** — Shatter returns unchanged value for non-frozen target
- Given: Enemy with no FREEZE StatusInstance (e.g., active BURN only or empty registry)
- When: `check_and_apply_shatter(enemy, 16.0)` called
- Then: Return value == 16.0 (unchanged); `shatter_triggered` NOT emitted
- Edge cases: Enemy with CHILL but no FREEZE — Chill does not trigger Shatter; only FREEZE does

**AC-SE-18** — Shatter fires on both of two hits against frozen target; Freeze not consumed
- Given: Enemy with active FREEZE; `shatter_triggered` spy
- When: `check_and_apply_shatter(enemy, 16.0)` called twice in the same frame
- Then: First call returns 20.0; second call also returns 20.0; `shatter_triggered` emitted twice; FREEZE StatusInstance still in registry after both calls
- Edge cases: Shatter multiplier is not removed after first use — Freeze is the condition, not a consumable token

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/status-effects/sem_contagion_shatter_test.gd` — must exist and pass headless

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 must be Done (`_on_enemy_killed()` structure must exist for Contagion to insert before cleanup)
- Unlocks: Epic complete — all 5 stories Done = StatusEffectsManager fully implemented at FP scope

## Completion Notes
**Completed**: 2026-06-05
**Criteria**: 6/6 passing
**Deviations**: ADVISORY — `_try_burn_contagion` adds `if not candidate.is_alive(): continue` (absent from story pseudocode). Required to prevent self-contagion onto the dying enemy. Functionally correct per GDD intent. Logged to tech-debt-register.md.
**Test Evidence**: Logic — `tests/unit/status-effects/sem_contagion_shatter_test.gd` — 45/45 PASSED (GdUnit4 v6.1.3, Godot 4.6.2)
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (all 4 suggestions applied: INF sentinel, dying_pos assertion, spell_base_damage assertion, empty-group edge case test)
