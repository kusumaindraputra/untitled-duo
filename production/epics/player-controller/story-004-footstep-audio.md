# Story 004: Footstep Shuffle-Bag and Audio Events

> **Epic**: Player Controller
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: ~2h
> **Manifest Version**: 2026-05-30
> **Last Updated**: 2026-05-31

## Context

**GDD**: `design/gdd/player-controller.md`
**Requirement**: `TR-PC-005`, `TR-PC-002` (footstep timer), `TR-PC-007` (audio dispatch)

**ADR Governing Implementation**: ADR-0003: Signal-Driven Architecture
**ADR Decision Summary**: All audio from PlayerController dispatched via `AudioSystem.play_event(event_name: StringName)`. PlayerController is the authoritative caller for footstep and dash audio events — no other system calls these events.

**Secondary ADR**: ADR-0004 (footstep timer via float accumulator in `_physics_process`)

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Array.shuffle()`, `StringName` literals (`&"..."`) both stable.

**Control Manifest Rules (Core layer)**:
- Required: All audio goes through `AudioSystem.play_event(event_name: StringName)`.
- Required: Dynamic `play_event()` keys from variables must be wrapped: `StringName(variable)`.
- Forbidden: Never instantiate `AudioStreamPlayer` nodes directly outside AudioSystem.

---

## Acceptance Criteria

- [ ] **AC-PC-14** — GIVEN `FOOTSTEP_INTERVAL_SEC = 0.38`, WHEN `_compute_steps_per_second()` called, THEN result within ±0.01 of 2.63.
- [ ] **AC-PC-15** — GIVEN `get_controller_state() == ENABLED` and `velocity.length() > FOOTSTEP_VELOCITY_THRESHOLD`, WHEN `FOOTSTEP_INTERVAL_SEC` elapses, THEN `audio_system.play_event()` called exactly once with arg matching one of `[&"sfx_fayde_footstep_a", &"sfx_fayde_footstep_b", &"sfx_fayde_footstep_c"]`. *(AudioSystem mock via `audio_system` property.)*
- [ ] **AC-PC-16** — GIVEN `velocity.length() < FOOTSTEP_VELOCITY_THRESHOLD` (also: `== FOOTSTEP_VELOCITY_THRESHOLD` exact boundary), WHEN `FOOTSTEP_INTERVAL_SEC` elapses, THEN `audio_system.play_event()` NOT called with any footstep variant. *(Strict `>` condition — exact threshold does NOT fire.)*
- [ ] **AC-PC-17** — GIVEN `get_controller_state() == ENABLED` and dash cooldown expired, WHEN `dash` action pressed, THEN `audio_system.play_event(&"sfx_fayde_dash")` called exactly once.
- [ ] **AC-PC-20** — GIVEN `get_controller_state() == DASHING` and `velocity.length() > FOOTSTEP_VELOCITY_THRESHOLD`, WHEN `FOOTSTEP_INTERVAL_SEC` elapses, THEN `audio_system.play_event()` NOT called with any footstep variant. *(State guard required — `DASH_SPEED` exceeds velocity threshold.)*
- [ ] **AC-PC-21** — GIVEN `VELOCITY_SNAP_THRESHOLD` assigned value `>= FOOTSTEP_VELOCITY_THRESHOLD`, THEN `push_error()` emitted and value rejected. *(Setter guard.)*

---

## Implementation Notes

**AudioSystem injection (testable via property override):**
```gdscript
var audio_system: Node = null  # set in _ready(); overridable for tests

func _ready() -> void:
    # ... existing _ready code from Story 001 ...
    audio_system = AudioSystem  # Autoload reference
```

**Footstep state vars (add to class):**
```gdscript
var _footstep_timer: float = 0.0
var _footstep_bag: Array[StringName] = []
var _last_footstep_played: StringName = &""
```

**Footstep tick (add to `_physics_process`, after movement):**
```gdscript
# Footstep accumulator
_footstep_timer += delta
if _footstep_timer >= FOOTSTEP_INTERVAL_SEC:
    _footstep_timer -= FOOTSTEP_INTERVAL_SEC  # decrement, not reset to 0
    if _controller_state == ControllerState.ENABLED and velocity.length() > FOOTSTEP_VELOCITY_THRESHOLD:
        _fire_footstep()
    # timer continues accumulating during DASHING and idle (fires immediately on next re-entry)
```

**Footstep shuffle-bag:**
```gdscript
func _fire_footstep() -> void:
    if _footstep_bag.is_empty():
        _footstep_bag = [&"sfx_fayde_footstep_a", &"sfx_fayde_footstep_b", &"sfx_fayde_footstep_c"]
        _footstep_bag.shuffle()
        # Anti-consecutive-repeat: if first == last played, swap with a random other index
        if _footstep_bag[0] == _last_footstep_played and _footstep_bag.size() > 1:
            var swap_idx := randi_range(1, _footstep_bag.size() - 1)
            var tmp := _footstep_bag[0]
            _footstep_bag[0] = _footstep_bag[swap_idx]
            _footstep_bag[swap_idx] = tmp
    var variant: StringName = _footstep_bag.pop_front()
    _last_footstep_played = variant
    if audio_system != null:
        audio_system.play_event(variant)
```

**Dash audio (add to dash trigger in Story 003):**
```gdscript
# In dash trigger block (after state change):
if audio_system != null:
    audio_system.play_event(&"sfx_fayde_dash")
```

**Formula getter:**
```gdscript
func _compute_steps_per_second() -> float:
    return 1.0 / FOOTSTEP_INTERVAL_SEC
```

**Setter guard for VELOCITY_SNAP_THRESHOLD (AC-PC-21):**
```gdscript
# Add @export or setter if VELOCITY_SNAP_THRESHOLD is not a const:
# Since it's a const, this guard runs in _ready() startup assert:
func _ready() -> void:
    if VELOCITY_SNAP_THRESHOLD >= FOOTSTEP_VELOCITY_THRESHOLD:
        push_error("VELOCITY_SNAP_THRESHOLD (%f) must be < FOOTSTEP_VELOCITY_THRESHOLD (%f)" % [
            VELOCITY_SNAP_THRESHOLD, FOOTSTEP_VELOCITY_THRESHOLD])
    # ... rest of _ready
```

**AudioSystem mock for tests**: Create a `MockAudioSystem` inner class or standalone GDScript that exposes a `play_event(event_name: StringName)` method and tracks call history. Assign to `player_controller.audio_system = mock` before running footstep tests.

---

## Out of Scope

- Story 003: Dash trigger that calls `play_event(&"sfx_fayde_dash")` — wired here
- AudioSystem epic: routing `sfx_fayde_footstep_*` events through a dedicated non-pooled player
- TR-PC-007 (`cast_hit_started` → CAST_LOCKED sub-state): stubbed here as empty handler; full behavior validated in SpellCastingEffects epic

---

## QA Test Cases

**AC-PC-14 — Steps per second formula**
- Given: `FOOTSTEP_INTERVAL_SEC = 0.38`
- When: `_compute_steps_per_second()` called
- Then: `abs(result - 2.63) <= 0.01`

**AC-PC-15 — Footstep fires during movement**
- Given: `_controller_state = ENABLED`; `velocity = Vector2(100, 0)` (> threshold 10); `audio_system = MockAudioSystem()`
- When: Call `_physics_process(1.0/60.0)` for `ceil(0.38 * 60) + 1` = 24 frames
- Then: `audio_system.play_event()` called once; arg is one of `[&"sfx_fayde_footstep_a", &"sfx_fayde_footstep_b", &"sfx_fayde_footstep_c"]`

**AC-PC-16 — No footstep below threshold (including exact threshold)**
- Given: `_controller_state = ENABLED`; `velocity = Vector2(FOOTSTEP_VELOCITY_THRESHOLD, 0)` (= 10.0 exactly); `audio_system = MockAudioSystem()`
- When: Call `_physics_process(1.0/60.0)` for 24+ frames
- Then: `audio_system.play_event()` NOT called with any footstep variant
- Edge cases: Also test `velocity = Vector2(5, 0)` (< threshold) — same assertion

**AC-PC-17 — Dash audio fires exactly once on dash**
- Given: `_controller_state = ENABLED`; cooldown expired; `audio_system = MockAudioSystem()`
- When: Simulate `dash` action press; call `_physics_process(1.0/60.0)` once
- Then: `audio_system.play_event.call_count(&"sfx_fayde_dash") == 1`

**AC-PC-20 — No footstep during DASHING despite high velocity**
- Given: `_controller_state = DASHING`; `velocity = Vector2(DASH_SPEED, 0)` (= 400 >> threshold); `audio_system = MockAudioSystem()`
- When: Call `_physics_process(1.0/60.0)` for 24+ frames
- Then: `audio_system.play_event()` NOT called with any footstep variant

**AC-PC-21 — Setter guard rejects VELOCITY_SNAP_THRESHOLD >= FOOTSTEP_VELOCITY_THRESHOLD**
- Given: `VELOCITY_SNAP_THRESHOLD` is being validated in `_ready()`
- When: Default constants are `VELOCITY_SNAP_THRESHOLD=8` and `FOOTSTEP_VELOCITY_THRESHOLD=10`
- Then: No `push_error()` fired (8 < 10 passes)
- Edge cases: Test by temporarily setting to equal values (8, 8) → assert `push_error()` fires

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/player-controller/footstep_audio_test.gd` — must pass headless

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (dash trigger block exists — dash audio is added here)
- Unlocks: PlayerController epic COMPLETE. All TR-PC-001–009 covered across Stories 001–004.
