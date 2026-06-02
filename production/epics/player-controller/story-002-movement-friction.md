# Story 002: WASD Movement and Friction Deceleration

> **Epic**: Player Controller
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: ~2h
> **Manifest Version**: 2026-05-30
> **Last Updated**: 2026-06-02

## Context

**GDD**: `design/gdd/player-controller.md`
**Requirement**: `TR-PC-001`, `TR-PC-002` (movement timers)

**ADR Governing Implementation**: ADR-0001: Isometric View
**ADR Decision Summary**: Movement is screen-space cartesian — WASD maps to screen axes, not isometric world axes. Isometric projection is visual only. `CharacterBody2D.move_and_slide()` for physics. Gameplay coordinates are 2D cartesian throughout.

**Secondary ADR**: ADR-0004 (delta-corrected float accumulators for move_factor / friction_factor)

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: `Input.get_vector()` stable. `CharacterBody2D.move_and_slide()` signature changed in Godot 4.0 — no velocity argument, reads `velocity` property directly. Verified in `docs/engine-reference/godot/modules/`. ADR-0001 QQ-01 RESOLVED — TileMapLayer + Compatibility renderer verified (9/9 API tests passed 2026-05-30).

**Control Manifest Rules (Core layer)**:
- Required: `CharacterBody2D.move_and_slide()` for movement — screen-space cartesian.
- Required: All in-game timing uses float delta accumulators in `_physics_process(delta)`.
- Required: Movement input via `Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")`.
- Forbidden: Never use `Timer` nodes or `SceneTree.create_timer()` for gameplay timing.

---

## Acceptance Criteria

- [x] **AC-PC-01** — GIVEN `get_controller_state() == ENABLED` and `move_right` held, WHEN `_physics_process` runs one frame, THEN `velocity.x > 0` and `velocity.length() ≤ MOVE_SPEED`.
- [x] **AC-PC-02** — GIVEN `MOVE_FRICTION < 1.0` AND Fayde was moving at `MOVE_SPEED` and all input released, WHEN `_physics_process` runs at 60 fps, THEN `velocity` becomes `Vector2.ZERO` within `ceil(log(VELOCITY_SNAP_THRESHOLD / MOVE_SPEED) / log(1.0 - MOVE_FRICTION))` frames. *(With defaults: MOVE_SPEED=120, MOVE_FRICTION=0.25, VELOCITY_SNAP_THRESHOLD=8 → bound is ≤ 10 frames.)*
- [x] **AC-PC-19** — GIVEN last movement input was pure rightward `Vector2(1, 0)`, WHEN `get_facing_direction()` called, THEN result is `Vector2(1, 0)` (normalized, post-snap).

---

## Implementation Notes

**Movement in `_physics_process(delta)` (add after DISABLED guard from Story 001):**
```gdscript
# Movement (ENABLED or DASHING — velocity reading only in ENABLED)
var input_dir: Vector2 = Input.get_vector(
    &"move_left", &"move_right", &"move_up", &"move_down")

if _controller_state == ControllerState.ENABLED:
    var move_factor := 1.0 - pow(1.0 - MOVE_ACCELERATION, delta * 60.0)
    var friction_factor := 1.0 - pow(1.0 - MOVE_FRICTION, delta * 60.0)
    if input_dir.length() > 0.0:
        velocity = velocity.lerp(input_dir.normalized() * MOVE_SPEED, move_factor)
        _last_facing_dir = _snap_to_8dir(input_dir)  # post-snap storage
    else:
        velocity = velocity.lerp(Vector2.ZERO, friction_factor)
        if velocity.length() < VELOCITY_SNAP_THRESHOLD:
            velocity = Vector2.ZERO

move_and_slide()
```

**Snap to 8 directions helper (used by dash too — Story 003):**
```gdscript
func _snap_to_8dir(input: Vector2) -> Vector2:
    var snap_angle := round(atan2(input.y, input.x) / (PI / 4.0)) * (PI / 4.0)
    return Vector2(cos(snap_angle), sin(snap_angle))
```

**Facing direction getter:**
```gdscript
func get_facing_direction() -> Vector2:
    return _last_facing_dir  # always post-snap; defaults to Vector2.RIGHT

func get_cast_position() -> Vector2:
    return global_position  # wraps global_position for SC&E targeting
```

**Test setup note**: AC-PC-02 drives `_physics_process(1.0/60.0)` in a loop. Set `Engine.physics_ticks_per_second = 60` in `before_all()` per GDD test harness requirement. For `Input.get_vector()` simulation in headless tests: use `Input.action_press("move_right")` / `Input.action_release()` or override via a mock input method. If Input actions are unavailable headless, test AC-PC-01 by setting `velocity` directly and verifying the friction path, and test AC-PC-01 via a manual `input_dir` variable injection pattern.

**Note on `VELOCITY_SNAP_THRESHOLD` constraint (AC-PC-21 — Story 004)**: The setter guard that rejects `VELOCITY_SNAP_THRESHOLD >= FOOTSTEP_VELOCITY_THRESHOLD` is implemented in Story 004. Set constants as `const` in this story — setter guard is a Story 004 addition.

---

## Out of Scope

- Story 001: State machine skeleton (must exist before this story)
- Story 003: Dash velocity override (DASHING state uses different velocity path)
- Story 004: Footstep accumulator using `velocity.length()` (reads velocity computed here)

---

## QA Test Cases

**AC-PC-01 — Movement applies positive x-velocity**
- Given: `_controller_state = ENABLED`; physics ticks = 60
- When: Simulate `move_right` input; call `_physics_process(1.0/60.0)`
- Then: `velocity.x > 0`; `velocity.length() <= MOVE_SPEED` (120.0)
- Edge cases: Diagonal input → `velocity.length() <= MOVE_SPEED` (normalized input)

**AC-PC-02 — Friction decelerates to zero within bound**
- Given: `_controller_state = ENABLED`; `velocity = Vector2(MOVE_SPEED, 0)` (120, 0); no input; physics ticks = 60
- When: Call `_physics_process(1.0/60.0)` repeatedly; count frames until `velocity == Vector2.ZERO`
- Then: Frame count <= `ceil(log(8.0 / 120.0) / log(1.0 - 0.25))` = `ceil(log(0.0667) / log(0.75))` ≈ 10 frames
- Edge cases: Verify snap-to-zero fires (not infinite approach): velocity is exactly `Vector2.ZERO`, not near-zero

**AC-PC-19 — Facing direction stored post-snap**
- Given: Last input was pure `Vector2(1, 0)` (rightward)
- When: `get_facing_direction()` called
- Then: Returns `Vector2(1, 0)` exactly (no normalization error for axis-aligned input)
- Edge cases: Diagonal input `Vector2(1, 1)` → facing snapped to `Vector2(cos(PI/4), sin(PI/4))` ≈ `Vector2(0.707, 0.707)`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/player-controller/movement_test.gd` — must pass headless

**Status**: [x] PASSED — 9/9 tests, 0 orphans, 0 errors (GdUnit4 v6.1.3, Godot 4.6.2, 2026-06-02)

---

## Dependencies

- Depends on: Story 001 (skeleton + state machine must exist)
- Unlocks: Story 003 (dash uses `_last_facing_dir` and `_snap_to_8dir` from this story)

---

## Completion Notes
**Completed**: 2026-06-02
**Criteria**: 3/3 passing
**Deviations**:
- ADVISORY: Gameplay constants (`MOVE_SPEED`, `MOVE_ACCELERATION`, `MOVE_FRICTION`, `VELOCITY_SNAP_THRESHOLD`, plus future-story constants) are hardcoded `const` — violates data-driven rule. Tech-debt logged; migrate to `PlayerStats` resource before epic closes.
- ADVISORY: `input_dir` computed outside `ENABLED` block — structural debt for Story 003 to resolve. Tech-debt logged.
**Test Evidence**: Logic — `tests/unit/player-controller/movement_test.gd` PASSED (9/9 headless, Godot 4.6.2)
**Code Review**: Complete — `/code-review` APPROVED WITH SUGGESTIONS (2026-06-02). AC-PC-01/AC-PC-19 test coverage gap fixed; remaining suggestions are advisory.
**Notes**: AC-PC-01/AC-PC-19 tests use `Input.action_press()` with programmatic InputMap registration (actions not yet in project.godot). Tests are self-contained and correctly exercise the real `_physics_process` code path.
