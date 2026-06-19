# Story 006: Stinger API + Music Ducking

> **Epic**: Audio System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3h
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-19

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: `TR-AS-011`

**ADR Governing Implementation**: ADR-0012: Audio System Implementation Contract
**ADR Decision Summary**: One dedicated non-pooled stinger `AudioStreamPlayer` (`PROCESS_MODE_ALWAYS`, `&"SFX"` bus). `play_stinger()` evaluates NARRATIVE/COMBAT priority — NARRATIVE blocks COMBAT, NARRATIVE interrupts COMBAT, same-priority = last-caller-wins. Music bus ducked by `event.duck_depth_db` (0.1s fade-in). `_music_pre_stinger_volume` captured once at first `play_stinger()` and RETAINED on interrupt — re-capturing the ducked value causes compounding drift. DYING exception: suppress duck tween when `_music_state == DYING`. Disconnect prior `finished` before reconnecting.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Object.CONNECT_ONE_SHOT` — stable. `AudioStreamPlayer.playing` unreliable in headless GUT — assert `stream` assignment and tween non-null, not `playing == false`.

**Control Manifest Rules (Foundation layer)**:
- Required: All audio goes through `AudioSystem.play_event()` or `AudioSystem.play_stinger()` — no direct node access

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`:*

- [ ] **AC-AS-35** — `play_stinger("dummy_stinger")` (bus=`&"SFX"`, duck_depth_db=−6.0, stinger_priority=0):
  - All 24 SFX pool slots have unchanged `stream` (stinger is non-pooled)
  - `_stinger_player.stream == dummy stinger stream`
  - `AudioServer.get_bus_volume_db(music_bus_idx)` within ±0.01 dB of `(prior_music_volume_db + duck_depth_db)` — Music bus ducked by `duck_depth_db`
- [ ] **AC-AS-36** — `stop_stinger()` after active stinger:
  - `_active_stinger_tween` non-null (restore tween created)
  - Manual QA: Wait `restore_duration_sec`; Music bus volume ≈ `prior_music_volume_db` (fully restored)

---

## Implementation Notes

*Derived from ADR-0012:*

### State tracking

```gdscript
var _active_stinger_tween: Tween = null
var _music_pre_stinger_volume: float = 0.0   # captured ONCE; retained on interrupt — never re-captured
var _current_stinger_priority: int = -1       # -1 = no stinger playing
```

Priority constants:
```gdscript
const STINGER_PRIORITY_COMBAT: int = 0
const STINGER_PRIORITY_NARRATIVE: int = 1
const STINGER_DUCK_FADE_IN_SEC: float = 0.1
```

### play_stinger()

```gdscript
func play_stinger(event_name: StringName) -> void:
    if not _validated_events.has(event_name):
        push_error("AudioSystem: No stinger event registered for '%s'." % event_name)
        return
    var event: AudioEventData = _validated_events[event_name]
    if event.bus not in [BUS_SFX, BUS_UI]:
        push_error("AudioSystem: play_stinger() event '%s' must use SFX or UI bus." % event_name)
        return
    # Priority policy
    if _current_stinger_priority == STINGER_PRIORITY_NARRATIVE \
       and event.stinger_priority == STINGER_PRIORITY_COMBAT:
        return  # NARRATIVE blocks COMBAT — silently ignored
    # New stinger proceeds — disconnect prior finished connection
    if _stinger_player.finished.is_connected(_on_stinger_finished):
        _stinger_player.finished.disconnect(_on_stinger_finished)
    # Capture pre-stinger Music volume ONLY if no stinger currently playing
    if _current_stinger_priority == -1:
        _music_pre_stinger_volume = AudioServer.get_bus_volume_db(
            AudioServer.get_bus_index(BUS_MUSIC))
    # (If stinger IS playing, retain existing _music_pre_stinger_volume — prevents drift)
    _current_stinger_priority = event.stinger_priority
    _stinger_player.stream = event.stream
    _stinger_player.play()
    _stinger_player.finished.connect(_on_stinger_finished, Object.CONNECT_ONE_SHOT)
    # Music duck (suppressed in DYING state)
    if _music_state != MusicState.DYING:
        var target_db: float = _music_pre_stinger_volume + event.duck_depth_db
        if _active_stinger_tween != null:
            _active_stinger_tween.kill()
        _active_stinger_tween = create_tween()
        _active_stinger_tween.tween_property(
            AudioServer, "bus_volume_db/" + BUS_MUSIC,   # Note: see Godot audio API
            target_db, STINGER_DUCK_FADE_IN_SEC
        ).from(_music_pre_stinger_volume)
```

**Note on AudioServer bus volume tween**: Godot 4 doesn't support tweening `AudioServer` properties directly via `tween_property`. Use a custom callable instead:
```gdscript
_active_stinger_tween.tween_method(
    func(db: float) -> void: AudioServer.set_bus_volume_db(music_bus_idx, db),
    _music_pre_stinger_volume, target_db, STINGER_DUCK_FADE_IN_SEC)
```

### stop_stinger()

```gdscript
func _on_stinger_finished() -> void:
    _restore_music_after_stinger()
    _current_stinger_priority = -1

func stop_stinger() -> void:
    if _stinger_player.finished.is_connected(_on_stinger_finished):
        _stinger_player.finished.disconnect(_on_stinger_finished)
    _stinger_player.stop()
    _stinger_player.stream = null
    _restore_music_after_stinger()
    _current_stinger_priority = -1

func _restore_music_after_stinger() -> void:
    if _music_state == MusicState.DYING:
        return  # DYING exception — music already at -80, do not restore
    var event: AudioEventData = # get last event for restore_duration_sec
    if _active_stinger_tween != null:
        _active_stinger_tween.kill()
    _active_stinger_tween = create_tween()
    _active_stinger_tween.tween_method(
        func(db: float) -> void: AudioServer.set_bus_volume_db(music_bus_idx, db),
        AudioServer.get_bus_volume_db(music_bus_idx),
        _music_pre_stinger_volume,
        event.restore_duration_sec)
```

Store last event reference for restore: `var _last_stinger_event: AudioEventData = null` — set in `play_stinger()`.

---

## Out of Scope

- Deferred stinger ACs (priority policy tests, DYING+stinger+finish, same-priority interrupt) — listed in GDD §"Deferred Acceptance Criteria"; not required for this story
- Story 002: SFX pool (stinger is non-pooled)
- Story 003/004: Music FSM (stinger reads `_music_state` but does not own it)

---

## QA Test Cases

**AC-AS-35**: play_stinger routes to stinger player + ducks Music
- Given: Snapshot all 24 SFX pool slot streams; capture `prior_music_volume_db = AudioServer.get_bus_volume_db(music_bus_idx)`; register dummy stinger (`bus=&"SFX"`, `duck_depth_db=-6.0`, `stinger_priority=0`)
- When: `AudioSystem.play_stinger("dummy_stinger")`
- Then: All 24 SFX pool slots unchanged; `_stinger_player.stream == dummy stream`; `AudioServer.get_bus_volume_db(music_bus_idx)` within ±0.01 dB of `(prior_music_volume_db - 6.0)`
- Edge cases: `bus = &"AMB"` or `bus = &"Music"` → `push_error()`, no stream change, no duck

**AC-AS-36**: stop_stinger creates restore tween
- Given: `play_stinger("dummy_stinger")` called; capture `prior_music_volume_db` and `post_duck_volume_db`
- When: `stop_stinger()` called
- Then: `_active_stinger_tween` non-null (restore tween created); do NOT assert `playing == false` (unreliable in headless)
- Manual QA: Play stinger mid-combat, call `stop_stinger()`, wait `restore_duration_sec` — `AudioServer.get_bus_volume_db(music_bus_idx) ≈ prior_music_volume_db`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/audio/stinger_test.gd` — must exist and pass

**Status**: [x] `tests/unit/audio/stinger_test.gd` — 791 tests total, 0 failures (2026-06-19)

---

## Dependencies

- Depends on: Story 001 (stinger player created in scaffold); Story 003 (music FSM state needed for DYING exception check)
- Unlocks: None — stinger is self-contained
