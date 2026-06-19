# Story 004: DYING State + END Auto-Transition

> **Epic**: Audio System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3h
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-19

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: `TR-AS-008`, `TR-AS-009`

**ADR Governing Implementation**: ADR-0012: Audio System Implementation Contract
**ADR Decision Summary**: `DYING` is intentional silence — no cue, both music players tween to −80 dB. `DYING_MIN_HOLD_SEC = 1.5s` guards against `run_ended(false)` arriving before the moment "breathes". `END_*` cues use `Object.CONNECT_ONE_SHOT` connected at crossfade initiation (not in tween callback) — a short cue can fire `finished` before tween completes. END→MAIN_MENU auto-transition has a state guard against stale connections.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Object.CONNECT_ONE_SHOT` — stable in Godot 4.6. `Tween.custom_step()` does not exist — real-time timer injection via `_set_dying_elapsed()` is the only way to test the hold guard without `await`. `AudioStreamPlayer.finished` is NOT emitted for looping streams — END cues must be non-looping at the asset level.

**Control Manifest Rules (Foundation layer)**:
- Required: `END_VICTORY` and `END_DEFEAT` `AudioStream` assets must be non-looping
- Required: `finished` signal connected via `Object.CONNECT_ONE_SHOT` at crossfade initiation

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`:*

- [ ] **AC-AS-28** — `_on_death_started()` transitions to `MusicState.DYING` and creates a fade tween (both music players fade to −80 dB). `_active_tween` is non-null after call.
- [ ] **AC-AS-29** — DYING hold guard:
  - Test A (early): `_on_death_started()` → immediately `_on_run_ended(false)` → assert state is still `MusicState.DYING` (hold guard active); `_pending_defeat_transition == true`.
  - Test B (delayed): Same setup → advance `_dying_elapsed` past `DYING_MIN_HOLD_SEC` via `_set_dying_elapsed()` → assert `_music_state == MusicState.END_DEFEAT` (queued transition fired).
- [ ] **AC-AS-26** — END auto-transition: trigger crossfade to `END_DEFEAT` via `_on_run_ended(false)` from PREPARATION; capture incoming player; emit `finished` directly → assert `_music_state == MusicState.MAIN_MENU`.
- [ ] **AC-AS-27** — After END auto-transition reaches MAIN_MENU: `_on_run_started()` → `_music_state == MusicState.PREPARATION`.

---

## Implementation Notes

*Derived from ADR-0012:*

### DYING entry

```gdscript
func _on_death_started() -> void:
    if _music_state in [MusicState.END_VICTORY, MusicState.END_DEFEAT]:
        return  # non-interruptible
    _music_state = MusicState.DYING
    _dying_elapsed = 0.0
    _pending_defeat_transition = false
    # Fade both music players to silence simultaneously
    if _active_tween != null:
        _active_tween.kill()
    _active_tween = create_tween()
    _active_tween.set_parallel(true)
    _active_tween.tween_property(_music_players[0], "volume_db", -80.0, CROSSFADE_DURATION_TO_DYING)\
        .from(_music_players[0].volume_db)
    _active_tween.tween_property(_music_players[1], "volume_db", -80.0, CROSSFADE_DURATION_TO_DYING)\
        .from(_music_players[1].volume_db)
```

### DYING hold guard

```gdscript
var _pending_defeat_transition: bool = false
var _dying_elapsed: float = 0.0

const DYING_MIN_HOLD_SEC: float = 1.5

func _process(delta: float) -> void:
    if _music_state == MusicState.DYING:
        _dying_elapsed += delta
        if _pending_defeat_transition and _dying_elapsed >= DYING_MIN_HOLD_SEC:
            _pending_defeat_transition = false
            _crossfade_to(MusicState.END_DEFEAT, CROSSFADE_DURATION_TO_END)
            _connect_end_finished_signal()

func _on_run_ended(win: bool) -> void:
    if _music_state in [MusicState.END_VICTORY, MusicState.END_DEFEAT]:
        return
    if win:
        _crossfade_to(MusicState.END_VICTORY, CROSSFADE_DURATION_TO_END)
        _connect_end_finished_signal()
    else:
        if _music_state == MusicState.DYING:
            if _dying_elapsed >= DYING_MIN_HOLD_SEC:
                _crossfade_to(MusicState.END_DEFEAT, CROSSFADE_DURATION_TO_END)
                _connect_end_finished_signal()
            else:
                _pending_defeat_transition = true
        else:
            _crossfade_to(MusicState.END_DEFEAT, CROSSFADE_DURATION_TO_END)
            _connect_end_finished_signal()
```

### Test accessor for DYING hold (required for AC-AS-29 Test B)

```gdscript
func _set_dying_elapsed(sec: float) -> void:
    _dying_elapsed = sec
```

### END finished signal connection (connected at crossfade initiation)

```gdscript
func _connect_end_finished_signal() -> void:
    var incoming: AudioStreamPlayer = _music_players[_active_music_idx]
    incoming.finished.connect(_on_end_cue_finished, Object.CONNECT_ONE_SHOT)

func _on_end_cue_finished() -> void:
    # State guard — discard if stale or out-of-sequence
    if _music_state != MusicState.END_VICTORY and _music_state != MusicState.END_DEFEAT:
        return
    _crossfade_to(MusicState.MAIN_MENU, CROSSFADE_DURATION_TO_MAIN_MENU)
```

`Object.CONNECT_ONE_SHOT` prevents double-firing. The state guard handles stale signals (e.g., if a second `finished` fires after auto-transition already ran).

**Critical**: Connect `finished` AFTER `play()` is called in `_crossfade_to()` — the signal must be connected to the incoming player after it has started playing.

---

## Out of Scope

- Story 003: Core FSM transitions (MAIN_MENU, PREPARATION, COMBAT, END non-interruptible)
- Story 005: Ambient layer
- Story 006: Stinger API

---

## QA Test Cases

**AC-AS-28**: death_started → DYING + fade tween
- Given: State = COMBAT
- When: `AudioSystem._on_death_started()` called
- Then: `_music_state == MusicState.DYING`; `_active_tween` non-null
- Edge cases: `death_started` in END state → no-op (non-interruptible guard applies)

**AC-AS-29 Test A**: Early run_ended queued
- Given: `_on_death_started()` called (DYING); immediately call `_on_run_ended(false)`
- Then: `_music_state == MusicState.DYING`; `_pending_defeat_transition == true`
- Edge cases: `_on_run_ended(true)` in DYING — should not queue (victory transition not gated by DYING hold)

**AC-AS-29 Test B**: Queued transition fires after hold
- Given: Follow Test A setup; then `_set_dying_elapsed(DYING_MIN_HOLD_SEC + 0.1)`; trigger `_process(0.0)` or call the hold check directly
- Then: `_music_state == MusicState.END_DEFEAT`; `_pending_defeat_transition == false`
- Edge cases: `_set_dying_elapsed(DYING_MIN_HOLD_SEC - 0.01)` → still in DYING (not yet elapsed)

**AC-AS-26**: END auto-transition via finished signal
- Given: State = PREPARATION
- When: `_on_run_ended(false)` called → crossfade to END_DEFEAT initiated; capture incoming player; emit `incoming.finished.emit()`
- Then: `_music_state == MusicState.MAIN_MENU`
- Edge cases: `finished.emit()` without prior crossfade initiation → no handler connected → state unchanged (test must trigger crossfade first)

**AC-AS-27**: MAIN_MENU → PREPARATION after auto-transition
- Given: Follow AC-AS-26 to reach MAIN_MENU
- When: `_on_run_started()` called
- Then: `_music_state == MusicState.PREPARATION`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/audio/music_fsm_dying_test.gd` — must exist and pass

**Status**: [x] `tests/unit/audio/music_fsm_dying_test.gd` — 774 tests total, 0 failures (2026-06-19)

---

## Dependencies

- Depends on: Story 003 (Music FSM core, `_crossfade_to()`, A/B players must exist)
- Unlocks: None — this completes the music FSM
