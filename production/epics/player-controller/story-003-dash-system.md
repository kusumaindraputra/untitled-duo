# Story 003: Dash System, I-Frame, and Interface Getters

> **Epic**: Player Controller
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: ~3h
> **Manifest Version**: 2026-05-30
> **Last Updated**: 2026-06-02

## Context

**GDD**: `design/gdd/player-controller.md`
**Requirement**: `TR-PC-002` (dash timer), `TR-PC-004` (i-frame flag), `TR-PC-008` (interface getters)

**ADR Governing Implementation**: ADR-0004: Float Accumulator Timer Pattern
**ADR Decision Summary**: Dash duration and dash cooldown use float accumulators in `_physics_process(delta)`. Decrement by delta each frame; never reset to 0.0. `PROCESS_MODE_PAUSABLE` freezes both timers on pause automatically.

**Secondary ADRs**: ADR-0007 (H&D queries `is_invincible()` at step 1a of `apply_damage` — this story exposes the flag), ADR-0011 (exposes `is_alive() -> bool`)

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Float accumulator pattern stable. `atan2()`, `cos()`, `sin()`, `round()` all stable. No post-cutoff APIs.

**Control Manifest Rules (Core layer)**:
- Required: All in-game timing uses float delta accumulators in `_physics_process(delta)`.
- Required: Decrement accumulator by delta, never reset to 0.0 on tick.
- Forbidden: Never use `Timer` nodes or `SceneTree.create_timer()`.

---

## Acceptance Criteria

- [ ] **AC-PC-05** — GIVEN `get_controller_state() == ENABLED` and dash cooldown expired, WHEN `dash` action pressed, THEN: (a) `get_controller_state() == DASHING`; (b) `is_invincible() == true`; (c) `velocity.length()` within 1% of `DASH_SPEED`. *(Assert velocity before `move_and_slide()` processes that frame; use wall-free unit scene.)*
- [ ] **AC-PC-06** — GIVEN `get_controller_state() == DASHING`, WHEN `DASH_DURATION` elapses (via `_physics_process` accumulator), THEN: (a) `get_controller_state() == ENABLED`; (b) `is_invincible() == false`; (c) `get_dash_cooldown_remaining() > 0`.
- [ ] **AC-PC-07** — GIVEN dash cooldown NOT expired and PlayerController moving at non-zero velocity, WHEN `dash` action pressed, THEN `get_controller_state()` remains `ENABLED`; velocity unchanged.
- [ ] **AC-PC-08** — GIVEN no movement input and no stored `_last_facing_dir` (default), WHEN dash triggered, THEN velocity during dash points in `Vector2.RIGHT` direction (default facing).
- [ ] **AC-PC-13** — GIVEN `DASH_SPEED=400`, `DASH_DURATION=0.15`, WHEN `_compute_dash_distance()` called, THEN result within ±1 px of 60.0.
- [ ] **AC-PC-18** — GIVEN `DASH_COOLDOWN=2.0s` and dash used 0.6s ago (driven via `_physics_process` accumulator), WHEN `get_dash_cooldown_remaining()` called, THEN result within ±0.05s of 1.4s.
- [ ] **AC-PC-09 [Manual]** — GIVEN Fayde dashing through an enemy dealing CONTACT damage during `DASH_DURATION`, THEN no damage applied; HP unchanged. *(Manual QA — requires Enemy AI in scene. Evidence in `production/qa/evidence/`)*

---

## Implementation Notes

**Add to class vars (Story 001 skeleton):**
```gdscript
var _dash_duration_timer: float = 0.0   # countdown; > 0 = dashing
var _dash_cooldown_timer: float = 0.0   # countdown; > 0 = on cooldown
```

**Dash input check (add to `_physics_process` in ENABLED block):**
```gdscript
# Dash trigger
if _controller_state == ControllerState.ENABLED:
    if Input.is_action_just_pressed(&"dash") and _dash_cooldown_timer <= 0.0:
        var input_dir := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
        var dash_dir: Vector2
        if input_dir.length() > 0.0:
            dash_dir = _snap_to_8dir(input_dir)
        else:
            dash_dir = _last_facing_dir  # fallback: last moved or default RIGHT
        _last_facing_dir = dash_dir
        velocity = dash_dir * DASH_SPEED
        _controller_state = ControllerState.DASHING
        _dash_duration_timer = DASH_DURATION
        _is_invincible = true
        # Audio: Story 004

# Dash timer countdown (every physics frame when DASHING)
if _controller_state == ControllerState.DASHING:
    _dash_duration_timer -= delta
    if _dash_duration_timer <= 0.0:
        _controller_state = ControllerState.ENABLED
        _is_invincible = false
        _dash_cooldown_timer = DASH_COOLDOWN

# Dash cooldown countdown
if _dash_cooldown_timer > 0.0:
    _dash_cooldown_timer -= delta
    if _dash_cooldown_timer < 0.0:
        _dash_cooldown_timer = 0.0
```

**Interface getters:**
```gdscript
func get_dash_cooldown_remaining() -> float:
    return max(_dash_cooldown_timer, 0.0)

func _compute_dash_distance() -> float:
    return DASH_SPEED * DASH_DURATION

func is_alive() -> bool:
    # Used by StatusEffectsManager (ADR-0011) to check before applying effects
    return _controller_state != ControllerState.DISABLED or not HealthAndDamage._fayde_dead
    # Simple implementation: delegate to H&D if accessible, else return not DISABLED
    # Full contract defined by StatusEffectsManager epic
```

**Test setup for time-based ACs**: Drive via `_physics_process(1.0/60.0)` calls. For AC-PC-06: `ceil(DASH_DURATION * 60)` = `ceil(0.15 * 60)` = `ceil(9.0)` = 9 frames to expire. For AC-PC-18: `ceil(0.6 * 60)` = 36 frames to simulate 0.6s elapsed.

**Note on AC-PC-05 velocity assertion**: Assert `velocity.length()` before `move_and_slide()` processes. In a unit test, call `_physics_process(1.0/60.0)` once and check `velocity` before it has been modified by collision. Use a bare scene with no walls.

---

## Out of Scope

- Story 001: `_on_preparation_started()` clears `_is_invincible` (already implemented)
- Story 004: `audio_system.play_event(&"sfx_fayde_dash")` on dash initiation
- Health & Damage epic: wires `is_invincible()` call into `apply_damage` step 1a

---

## QA Test Cases

**AC-PC-05 — Dash state, invincibility, and velocity**
- Given: `_controller_state = ENABLED`; `_dash_cooldown_timer = 0.0`; physics ticks = 60
- When: Simulate `dash` action press (`Input.action_press(&"dash")`); call `_physics_process(1.0/60.0)` once
- Then: (a) `get_controller_state() == DASHING`; (b) `is_invincible() == true`; (c) `velocity.length()` within 1% of `DASH_SPEED` (400.0 ± 4.0)

**AC-PC-06 — Dash expires after DASH_DURATION**
- Given: `_controller_state = DASHING`; `_is_invincible = true`; `_dash_duration_timer = DASH_DURATION` (0.15)
- When: Call `_physics_process(1.0/60.0)` exactly `ceil(0.15 * 60) + 1` = 10 times
- Then: (a) `get_controller_state() == ENABLED`; (b) `is_invincible() == false`; (c) `get_dash_cooldown_remaining() > 0`

**AC-PC-07 — Dash blocked during cooldown**
- Given: `_controller_state = ENABLED`; `_dash_cooldown_timer = 1.0` (cooldown active); `velocity = Vector2(60, 0)`
- When: Simulate `dash` action press; call `_physics_process(1.0/60.0)`
- Then: `get_controller_state() == ENABLED`; velocity unchanged (60, 0)

**AC-PC-08 — Default dash direction is Vector2.RIGHT**
- Given: `_last_facing_dir = Vector2.RIGHT` (default); no movement input
- When: Trigger dash (cooldown expired)
- Then: `velocity` points in `Vector2.RIGHT` direction (within floating-point tolerance)

**AC-PC-13 — Dash distance formula**
- Given: `DASH_SPEED = 400.0`; `DASH_DURATION = 0.15`
- When: `_compute_dash_distance()` called
- Then: Result within ±1 px of 60.0 (`abs(result - 60.0) < 1.0`)

**AC-PC-18 — Dash cooldown remaining**
- Given: Dash triggered (sets `_dash_cooldown_timer = DASH_COOLDOWN = 2.0`)
- When: `_physics_process(1.0/60.0)` called 36 times (= 0.6s at 60fps); then `get_dash_cooldown_remaining()`
- Then: Result within ±0.05s of 1.4 (`abs(result - 1.4) <= 0.05`)

**AC-PC-09 [Manual] — I-frame blocks enemy CONTACT during dash**
- Setup: Arena scene with PlayerController + EnemyInstance overlapping; Fayde in DASHING state; H&D autoload present
- Verify: `apply_damage` is called from Enemy AI contact; `is_invincible()` returns true during dash
- Pass condition: `HealthAndDamage._fayde_current_hp` unchanged after overlap during DASHING
- Evidence file: `production/qa/evidence/dash-iframe-manual-check.md`

---

## Test Evidence

**Story Type**: Logic (AC-PC-09 is Manual — advisory)
**Required evidence**:
- Automated: `tests/unit/player-controller/dash_system_test.gd` — must pass headless (BLOCKING)
- Manual: `production/qa/evidence/dash-iframe-manual-check.md` (ADVISORY — requires EnemyInstance)

**Status**: [x] PASSED — 11/11 (GdUnit4 v6.1.3, Godot 4.6.2 headless, 2026-06-02)

---

## Dependencies

- Depends on: Story 001 (state machine), Story 002 (`_last_facing_dir` and `_snap_to_8dir`)
- Unlocks: Story 004 (audio events trigger during dash); H&D Story 002 (can wire `is_invincible()` call)

---

## Completion Notes
**Completed**: 2026-06-02
**Criteria**: 6/7 passing (AC-PC-09 [Manual] deferred — requires EnemyInstance in scene; ADVISORY)
**Deviations**:
- ADVISORY: Gameplay constants (MOVE_SPEED, DASH_SPEED, DASH_DURATION, DASH_COOLDOWN) hardcoded in class — pre-existing tech debt from Story 002; tracked for PlayerStats resource migration
- ADVISORY: `is_alive()` returns `true` unconditionally — intentional placeholder per ADR-0011; full implementation deferred to H&D death-signal story
**Test Evidence**: Logic — `tests/unit/player-controller/dash_system_test.gd` — 11/11 PASSED
**Code Review**: Complete — CHANGES REQUIRED → 3 test-file fixes applied → APPROVED WITH SUGGESTIONS
