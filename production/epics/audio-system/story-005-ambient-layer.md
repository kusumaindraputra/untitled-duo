# Story 005: Ambient Layer

> **Epic**: Audio System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2h
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-19

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: `TR-AS-001` (AMB A/B players), `TR-AS-005` (ALWAYS process mode)

**ADR Governing Implementation**: ADR-0012: Audio System Implementation Contract
**ADR Decision Summary**: Two dedicated AMB-bus `AudioStreamPlayer` nodes (A/B) created in `_ready()`, both `PROCESS_MODE_ALWAYS`. A/B ping-pong: each `play_ambient()` call swaps the active/inactive roles, enabling true simultaneous crossfades (one fading out, one fading in) with no silence gap. Kill prior tween before new crossfade. `stop_ambient()` fades only the active player (single tween, not simultaneous).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Tween.set_parallel(true)` confirmed stable. `Tween.custom_step()` does not exist — mid-fade volume assertions not possible in headless GUT without running the scene tree.

**Control Manifest Rules (Foundation layer)**:
- Required: All audio from external systems goes through AudioSystem API — `play_ambient()` for ambient, never direct `AudioStreamPlayer` access

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`:*

- [ ] **AC-AS-23** — `play_ambient("registered_amb_event")`: Ambient A gets `stream == registered dummy stream`; Ambient A has `bus == &"AMB"`; all 24 SFX pool slots have unchanged stream.
- [ ] **AC-AS-24** — `stop_ambient()`: `_active_ambient_tween` is non-null after call (fade tween created). Manual QA: ambient fades to silence over `CROSSFADE_DURATION_AMBIENT_OUT`.
- [ ] **AC-AS-25** — `play_ambient("amb_b")` while "amb_a" playing: `_active_ambient_tween` is a different object than prior tween; incoming player `stream == amb_b stream`; outgoing player `stream == amb_a stream` at time of assertion.

---

## Implementation Notes

*Derived from ADR-0012:*

### State tracking

```gdscript
var _active_ambient_idx: int = 0     # 0 = A, 1 = B
var _active_ambient_tween: Tween = null
```

### play_ambient()

```gdscript
func play_ambient(event_name: StringName) -> void:
    if not _validated_events.has(event_name):
        push_error("AudioSystem: No ambient event registered for '%s'." % event_name)
        return
    var event: AudioEventData = _validated_events[event_name]
    if event.bus != BUS_AMB:
        push_error("AudioSystem: play_ambient() called with non-AMB event '%s'." % event_name)
        return
    # Kill prior ambient tween (Edge Case 12)
    if _active_ambient_tween != null:
        _active_ambient_tween.kill()
    var incoming_idx: int = 1 - _active_ambient_idx
    var incoming: AudioStreamPlayer = _ambient_players[incoming_idx]
    var outgoing: AudioStreamPlayer = _ambient_players[_active_ambient_idx]
    incoming.stream = event.stream
    incoming.volume_db = -80.0
    incoming.play()
    # Simultaneous crossfade
    _active_ambient_tween = create_tween()
    _active_ambient_tween.set_parallel(true)
    _active_ambient_tween.tween_property(outgoing, "volume_db", -80.0, CROSSFADE_DURATION_AMBIENT_OUT)\
        .from(outgoing.volume_db)
    _active_ambient_tween.tween_property(incoming, "volume_db", 0.0, CROSSFADE_DURATION_AMBIENT_OUT)
    # Swap A/B ownership
    _active_ambient_idx = incoming_idx

const CROSSFADE_DURATION_AMBIENT_OUT: float = 0.5
```

### stop_ambient()

```gdscript
func stop_ambient() -> void:
    if _active_ambient_tween != null:
        _active_ambient_tween.kill()
    var active: AudioStreamPlayer = _ambient_players[_active_ambient_idx]
    _active_ambient_tween = create_tween()
    _active_ambient_tween.tween_property(active, "volume_db", -80.0, CROSSFADE_DURATION_AMBIENT_OUT)\
        .from(active.volume_db)
```

Note: `stop_ambient()` fades only the active player — it is a single tween, not `set_parallel(true)`. This is distinct from `play_ambient()` which uses two simultaneous tweens.

---

## Out of Scope

- Story 002: `play_event()` routing for SFX/UI
- Story 003: Music FSM crossfades (separate tween + separate players)
- Story 006: `play_stinger()` (stinger uses SFX bus, not AMB)

---

## QA Test Cases

**AC-AS-23**: play_ambient assigns stream to active ambient player
- Given: A dummy ambient event registered with `bus = &"AMB"`; snapshot 24 SFX pool slot streams
- When: `play_ambient("dummy_amb")` called
- Then: `_ambient_players[0].stream == dummy_amb.stream`; `_ambient_players[0].bus == &"AMB"`; all 24 SFX pool slots unchanged
- Edge cases: Unregistered event key → `push_error()`, no player changed

**AC-AS-24**: stop_ambient creates fade tween
- Given: `play_ambient()` called to make ambient active
- When: `stop_ambient()` called
- Then: `_active_ambient_tween` non-null (a fade tween was created)
- Manual QA: Wait `CROSSFADE_DURATION_AMBIENT_OUT`; ambient volume is near −80.0 dB
- Edge cases: `stop_ambient()` called when no ambient is playing → tween still created (fades silent player from -80, no audible effect)

**AC-AS-25**: play_ambient while playing crossfades without silence
- Given: `play_ambient("amb_a")` called; capture `_active_ambient_tween` as `tween_1`
- When: `play_ambient("amb_b")` called immediately
- Then: `_active_ambient_tween != tween_1` (new tween); incoming player `stream == amb_b stream`; outgoing player `stream == amb_a stream`
- Manual QA: Two different ambient events played back-to-back; no audible silence gap between them
- Edge cases: `play_ambient()` mid-crossfade → prior tween killed, new crossfade from current volume values

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/audio/ambient_layer_test.gd` — must exist and pass

**Status**: [x] `tests/unit/audio/ambient_layer_test.gd` — 783 tests total, 0 failures (2026-06-19)

---

## Dependencies

- Depends on: Story 001 (ambient A/B players created in scaffold; `_validated_events` available)
- Unlocks: None — ambient layer is self-contained
