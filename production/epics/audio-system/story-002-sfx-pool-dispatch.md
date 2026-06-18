# Story 002: SFX Pool + play_event() Dispatch

> **Epic**: Audio System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3h
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-19

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: `TR-AS-002`, `TR-AS-004`, `TR-AS-012`

**ADR Governing Implementation**: ADR-0012: Audio System Implementation Contract
**ADR Decision Summary**: 24-slot SFX pool with timestamp-based oldest-first eviction. `play_event()` routes by `AudioEventData.bus`: SFX → pool, UI → dedicated player (ALWAYS), AMB → `push_error()`. Priority tiers: LOW=0 evicted first, NORMAL=1 second, HIGH=2 never unless all HIGH. "Oldest" = smallest `Time.get_ticks_msec()` timestamp.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Use `Time.get_ticks_msec()` (not deprecated `OS.get_ticks_msec()`). `AudioStreamPlayer.playing` is unreliable in headless GUT — assert `stream` assignment, not `playing == true`.

**Control Manifest Rules (Foundation layer)**:
- Required: All audio from external systems goes through `AudioSystem.play_event(event_name: StringName)`
- Required: Dynamic `play_event()` keys built from variables must be wrapped: `StringName(variable)`
- Forbidden: No system may instantiate `AudioStreamPlayer` nodes directly

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`:*

- [ ] **AC-AS-03** — On startup, pool has exactly 24 nodes: each is `AudioStreamPlayer`, each has `process_mode == PROCESS_MODE_PAUSABLE`, all 24 `_timestamps[i] == 0`.
- [ ] **AC-AS-04** — `play_event("registered_sfx_event")` with a free slot assigns it correctly: exactly one pool slot gets `stream == registered dummy stream`; all other slots unchanged. (`playing == true` is NOT asserted — unreliable in headless GUT.)
- [ ] **AC-AS-05** — `play_event("unregistered_event")` logs `push_error()` and does not alter any pool slot state.
- [ ] **AC-AS-06** — Pool eviction respects priority. Four sub-cases:
  - **Test A (LOW eviction)**: 24 LOW slots; slot 2 has timestamp 100 (oldest). Assert slot 2 evicted on 25th call.
  - **Test B (NORMAL eviction)**: 24 NORMAL slots; oldest NORMAL slot evicted.
  - **Test C (HIGH protection)**: 23 LOW + 1 HIGH (slot 5, timestamp 0). Assert slot 5 NOT evicted — a LOW slot is evicted instead.
  - **Test D (all HIGH)**: 24 HIGH slots; slot 3 has timestamp 0. Assert slot 3 evicted (oldest HIGH).
- [ ] **AC-AS-07** — UI-bus event routes to dedicated UI player (not pool): zero pool slots change stream; UI player `stream == registered dummy stream`; UI player `process_mode == PROCESS_MODE_ALWAYS`.
- [ ] **AC-AS-34** — AMB-bus event via `play_event()` logs `push_error()`: all 24 pool slots unchanged; UI player unchanged; both ambient players unchanged.

---

## Implementation Notes

*Derived from ADR-0012:*

### validate-on-register (called in _ready after loading .tres)

```gdscript
_registry = load("res://assets/data/audio_event_registry.tres")
if _registry == null:
    push_error("AudioSystem: AudioEventRegistry not found. All play_event() calls will be no-ops.")
    return
for key: StringName in _registry.events:
    if not _registry.events[key] is AudioEventData:
        push_error("AudioSystem: Registry entry '%s' is not AudioEventData — skipped." % key)
        continue
    var entry := _registry.events[key] as AudioEventData
    if entry.priority not in [0, 1, 2]:
        push_error("AudioSystem: Entry '%s' priority %d invalid — clamped to NORMAL." % [key, entry.priority])
        entry.priority = 1
    if entry.stinger_priority not in [0, 1]:
        push_error("AudioSystem: Entry '%s' stinger_priority %d invalid — clamped to COMBAT." % [key, entry.stinger_priority])
        entry.stinger_priority = 0
    _validated_events[key] = entry
```

### play_event() routing

```gdscript
func play_event(event_name: StringName) -> void:
    if not _validated_events.has(event_name):
        push_error("AudioSystem: No event registered for key '%s'." % event_name)
        return
    var event: AudioEventData = _validated_events[event_name]
    match event.bus:
        BUS_SFX:
            _assign_sfx_pool_slot(event)
        BUS_UI:
            _ui_player.stream = event.stream
            _ui_player.play()
        BUS_AMB:
            push_error("AudioSystem: play_event() called with AMB-bus event '%s'. Use play_ambient() instead." % event_name)
        _:
            push_error("AudioSystem: Unknown bus '%s' for event '%s'." % [event.bus, event_name])
```

### Pool slot assignment + eviction

```gdscript
func _assign_sfx_pool_slot(event: AudioEventData) -> void:
    # Step 1: find first non-playing slot
    for i: int in range(SFX_POOL_SIZE):
        if not _sfx_pool[i].playing:
            _sfx_pool[i].stream = event.stream
            _sfx_pool[i].play()
            _timestamps[i] = Time.get_ticks_msec()
            return
    # Step 2: all slots occupied — evict by priority tier
    var target: int = _find_eviction_target(event.priority)
    _sfx_pool[target].stop()
    _sfx_pool[target].stream = event.stream
    _sfx_pool[target].play()
    _timestamps[target] = Time.get_ticks_msec()

func _find_eviction_target(incoming_priority: int) -> int:
    # Try LOW (0), then NORMAL (1), then HIGH (2)
    for tier: int in [0, 1, 2]:
        var oldest_idx: int = -1
        var oldest_ts: int = INF
        for i: int in range(SFX_POOL_SIZE):
            if _slot_priorities[i] == tier and _timestamps[i] < oldest_ts:
                oldest_ts = _timestamps[i]
                oldest_idx = i
        if oldest_idx >= 0:
            return oldest_idx
    return 0  # fallback (should never reach)
```

### Test accessor (required for AC-AS-06 determinism)

```gdscript
func _set_slot_timestamp(idx: int, ticks: int) -> void:
    _timestamps[idx] = ticks
```

This method is named with underscore prefix but must be callable from test scripts.

### Priority tracking

When a slot is assigned, store the event's priority so eviction knows each slot's tier:
```gdscript
var _slot_priorities: Array[int] = []  # parallel to _sfx_pool
# initialized to 0 (LOW) for all slots in _ready()
```
Update `_slot_priorities[idx] = event.priority` alongside `_timestamps[idx]`.

---

## Out of Scope

- Story 001: Node creation, process mode setup
- Story 003: Music FSM, crossfade, GSM signal connections
- Story 005: `play_ambient()` routing (AMB bus — separate story)
- Story 006: `play_stinger()` — stinger uses dedicated non-pooled node

---

## QA Test Cases

**AC-AS-03**: Pool pre-created with correct size and timestamps
- Given: AudioSystem `_ready()` complete
- When: Pool size and slot properties inspected
- Then: `_sfx_pool.size() == 24`; each slot is `AudioStreamPlayer`; each `process_mode == PROCESS_MODE_PAUSABLE`; all `_timestamps[i] == 0`
- Edge cases: SFX_POOL_SIZE constant changed → pool size changes with it

**AC-AS-04**: Free slot assignment (no eviction)
- Given: All 24 slots non-playing; a dummy SFX event registered in `_validated_events`
- When: `play_event("dummy_sfx")` called
- Then: Exactly one pool slot has `stream == dummy_sfx.stream`; all others unchanged
- Edge cases: Stream is null → slot assigned with null stream; play() no-ops silently

**AC-AS-05**: Unregistered event
- Given: Snapshot all 24 pool slot streams
- When: `play_event("nonexistent")` called
- Then: All 24 slots unchanged; a `push_error()` was emitted
- Edge cases: Called multiple times in succession — each call emits push_error, no cumulative state

**AC-AS-06 (A)**: LOW eviction — oldest slot picked
- Given: 24 LOW-priority slots filled; `_set_slot_timestamp(2, 100)` (oldest); all others set to 5000+
- When: `play_event("new_sfx")` called (25th)
- Then: Slot 2 `stream` reassigned to new event's stream
- Edge cases: Two slots at same timestamp → lowest index wins

**AC-AS-06 (B)**: NORMAL eviction when no LOW
- Given: 24 NORMAL slots; one designated oldest via `_set_slot_timestamp`
- When: `play_event()` called
- Then: Designated oldest NORMAL slot evicted

**AC-AS-06 (C)**: HIGH protection
- Given: 23 LOW + slot 5 HIGH with `_set_slot_timestamp(5, 0)` (would be oldest if no protection)
- When: `play_event()` called
- Then: Slot 5 NOT evicted; a LOW slot is evicted

**AC-AS-06 (D)**: All HIGH — oldest HIGH evicted
- Given: 24 HIGH slots; `_set_slot_timestamp(3, 0)` (oldest)
- When: `play_event()` called
- Then: Slot 3 evicted (only valid candidate when all slots are HIGH)

**AC-AS-07**: UI-bus routing bypasses pool
- Given: A dummy event registered with `bus = &"UI"`
- When: `play_event("dummy_ui")` called
- Then: Zero pool slots changed stream; `_ui_player.stream == dummy_ui.stream`; `_ui_player.process_mode == PROCESS_MODE_ALWAYS`

**AC-AS-34**: AMB-bus guard
- Given: A dummy event registered with `bus = &"AMB"`; snapshot pool, UI player, ambient players
- When: `play_event("dummy_amb")` called
- Then: All 24 pool slots unchanged; UI player unchanged; both ambient players unchanged; `push_error()` logged

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/audio/sfx_pool_test.gd` — must exist and pass

**Status**: [x] `tests/unit/audio/sfx_pool_test.gd` — 747 tests total, 0 failures (2026-06-19)

---

## Dependencies

- Depends on: Story 001 (AudioSystem scaffold + `_sfx_pool`, `_validated_events` must exist)
- Unlocks: Story 007 (volume control needs `play_event()` stable for integration coverage)
