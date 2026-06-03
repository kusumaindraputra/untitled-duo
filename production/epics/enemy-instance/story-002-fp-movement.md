# Story 002: FP Movement and Degenerate Direction Guard

> **Epic**: Enemy Instance
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: ~2h
> **Manifest Version**: 2026-05-30
> **Last Updated**: 2026-06-03

## Context

**GDD**: `design/gdd/enemy-ai.md`
**Requirement**: `TR-EAI-001`

**ADR Governing Implementation**: ADR-0010: Player Group Convention
**ADR Decision Summary**: Player lookup via `get_tree().get_first_node_in_group(&"player")` cached at `_ready()`. Re-resolve only on null. Target discrimination via `is_in_group()`.

**Secondary ADR**: ADR-0007 (movement uses `CharacterBody2D.move_and_slide()` — same pattern as PlayerController)

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Vector2.normalized()` returns `Vector2.ZERO` for zero-length vectors in Godot 4 (changed from prior versions that returned NaN). `is_nan()` check still needed for explicit guard. `move_and_slide()` stable.

**Control Manifest Rules (Core layer)**:
- Required: Player lookup `get_tree().get_first_node_in_group(&"player")` — cache result; re-resolve only on null.
- Required: Target discrimination via `is_in_group(&"player")`.
- Forbidden: Never use `get_nodes_in_group()` for per-frame player lookups.
- Forbidden: Never call `instance_from_id()` without null-checking result.

---

## Acceptance Criteria

- [ ] **AC-EAI-07** — GIVEN enemy at `(0,0)`, Fayde at `(100,0)`, `_combat_active = true`, WHEN `_physics_process(delta)` runs, THEN `velocity == Vector2(1,0) × _move_speed`.
- [ ] **AC-EAI-08** — GIVEN enemy and Fayde at the exact same position, WHEN `_physics_process(delta)` runs, THEN `velocity` is a valid non-NaN vector (`not is_nan(velocity.x) and not is_nan(velocity.y)`).
- [ ] **AC-EAI-09** — GIVEN `_dir_last_valid = Vector2(0,1)` from a prior valid frame, then enemy and Fayde at same position, WHEN `_physics_process(delta)` runs, THEN `velocity == Vector2(0,1) × _move_speed`.
- [ ] **AC-EAI-27** — GIVEN `_fayde_ref == null`, WHEN `_physics_process(delta)` runs, THEN `velocity == Vector2.ZERO` and no null-access error.

---

## Implementation Notes

**Movement in `_physics_process` (add after phase-gating guard from Story 001):**
```gdscript
func _physics_process(delta: float) -> void:
    if not _combat_active or _state == EnemyState.DEAD:
        velocity = Vector2.ZERO
        return

    # Re-resolve Fayde ref if lost (AC-EAI-27)
    if _fayde_ref == null:
        _fayde_ref = get_tree().get_first_node_in_group(&"player")
    if _fayde_ref == null:
        velocity = Vector2.ZERO
        return

    # Direction to Fayde (AC-EAI-07, 08, 09)
    var raw_dir := _fayde_ref.global_position - global_position
    if raw_dir.length() >= 0.01:
        _dir_last_valid = raw_dir.normalized()

    velocity = _dir_last_valid * _move_speed
    move_and_slide()

    # Contact timer tick (Story 003)
```

**Degenerate guard rationale**: In Godot 4, `Vector2.ZERO.normalized()` returns `Vector2.ZERO` (not NaN). The `is_nan()` check in AC-EAI-08 is still valid as a belt-and-suspenders assertion — if velocity were ever set from an external NaN source, the test would catch it. The `raw_dir.length() >= 0.01` guard prevents the `_dir_last_valid` from being overwritten with a near-zero direction on degenerate overlap.

**Note**: Fayde ref is cached at `_ready()`. The per-frame null check handles the rare case where PlayerController is freed and re-added between frames (not expected at FP scope but defensive). Per ADR-0010, do not use `get_nodes_in_group()` (returns Array) — use `get_first_node_in_group()` (returns single node).

---

## Out of Scope

- Story 001: Phase gating guard (already implemented)
- Story 003: Contact timer tick (runs in same `_physics_process` after movement)
- Story 004: DEAD state transition (checked in phase guard)

---

## QA Test Cases

**AC-EAI-07 — Direction vector to Fayde**
- Given: Enemy at `Vector2(0, 0)`; mock Fayde at `Vector2(100, 0)`; `_combat_active = true`; `_move_speed = 80.0`
- When: `_physics_process(1.0/60.0)` called
- Then: `velocity.x > 0`; `velocity.length()` approximately equals `_move_speed` (80.0 ± 0.5)
- Edge cases: Diagonal direction (Fayde at (100, 100)) → velocity normalized then × speed

**AC-EAI-08 — No NaN at same position**
- Given: Enemy and Fayde mock at identical position `Vector2(50, 50)`; `_combat_active = true`
- When: `_physics_process(1.0/60.0)` called
- Then: `not is_nan(velocity.x)` AND `not is_nan(velocity.y)`

**AC-EAI-09 — Last valid direction used as fallback**
- Given: `_dir_last_valid = Vector2(0, 1)` (set from prior frame); enemy and Fayde at same position; `_move_speed = 80.0`
- When: `_physics_process(1.0/60.0)` called
- Then: `velocity == Vector2(0, 1) * 80.0` (i.e., `Vector2(0, 80)`)

**AC-EAI-27 — Null Fayde ref → zero velocity, no crash**
- Given: `_fayde_ref = null`; `_combat_active = true`; no PlayerController in scene
- When: `_physics_process(1.0/60.0)` called
- Then: `velocity == Vector2.ZERO`; no NullReferenceError raised

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/enemy-instance/fp_movement_test.gd` — must pass headless

**Status**: [x] PASSED — 5/5 tests (GdUnit4 v6.1.3, Godot 4.6.2, 2026-06-03)

---

## Dependencies

- Depends on: Story 001 (skeleton + phase guard must exist)
- Unlocks: Story 003 (contact timer runs in same physics frame as movement)

---

## Completion Notes
**Completed**: 2026-06-03
**Criteria**: 4/4 passing (all covered by automated tests)
**Deviations**: `_fayde_ref` retyped `Node` → `Node2D` during code review (improvement, no design conflict); `delta` param not renamed to `_delta` (INFO suggestion, deferred)
**Test Evidence**: Logic — `tests/unit/enemy-instance/fp_movement_test.gd` — 5/5 PASSED (exit 0, 0 orphans)
**Code Review**: Complete — APPROVED post-fixes (6 required changes applied)
