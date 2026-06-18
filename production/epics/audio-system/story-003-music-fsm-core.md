# Story 003: Music State Machine — Core Transitions + Crossfade

> **Epic**: Audio System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 4h
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-18

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: `TR-AS-003`, `TR-AS-008` (partial)

**ADR Governing Implementation**: ADR-0012: Audio System Implementation Contract
**ADR Decision Summary**: 6-state music FSM driven exclusively by GameStateManager signals (never polled). Crossfades use `Tween.set_parallel(true)` — simultaneous fade-out and fade-in, no silence gap. Incoming player pre-set to −80 dB BEFORE `play()` to prevent single-frame pop. `wave_ended` is NOT connected. `END_*` states are non-interruptible. `CROSSFADE_TO_END` uses `Tween.TRANS_SINE` (constant-power) — all others use linear.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Tween.is_valid()` returns `false` after `.kill()` — do NOT use `is_running()` (does not exist in Godot 4). `Tween.custom_step()` does not exist in Godot 4 — mid-fade volume assertions are not possible; `_compute_crossfade_volume()` is a pure function for formula testing only.

**Control Manifest Rules (Foundation layer)**:
- Required: Music state machine transitions driven exclusively by GameStateManager signals — no polling
- Required: `AudioSystem._ready()` validates `is_instance_valid(GameStateManager)` before connecting signals

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`:*

- [ ] **AC-AS-08** — Initial music state is `MusicState.MAIN_MENU` after `_ready()`.
- [ ] **AC-AS-09** — `_on_run_started()` transitions `MAIN_MENU → PREPARATION`.
- [ ] **AC-AS-10** — `_on_combat_started(false)` transitions `PREPARATION → COMBAT`.
- [ ] **AC-AS-11** — `preparation_started` → `PREPARATION`; `wave_ended` does NOT change music state (remains `COMBAT`).
- [ ] **AC-AS-33** — `wave_ended` + `preparation_started` produces exactly one crossfade tween (not two). Assert: `wave_ended` creates no tween; `preparation_started` creates exactly one.
- [ ] **AC-AS-12** — `run_ended(false)` transitions to `END_DEFEAT` from both `PREPARATION` and `COMBAT`.
- [ ] **AC-AS-13** — `run_ended(true)` transitions to `END_VICTORY` from both `PREPARATION` and `COMBAT`.
- [ ] **AC-AS-14** — A second state transition during an active crossfade cancels the prior tween: `tween_1` becomes invalid (`not tween_1.is_valid()`); new `_active_tween` is a different object.
- [ ] **AC-AS-15** — `END_VICTORY` and `END_DEFEAT` are non-interruptible by game signals (`_on_run_started`, `_on_combat_started`, `_on_wave_ended`, `_on_run_ended` all no-op).
- [ ] **AC-AS-16** — `_compute_crossfade_volume(start, target, t, duration)` pure function: midpoint at −43.0 dB (within ±0.01) for fade-out from −6 dB; −40.0 dB for fade-in; t=0 returns start; t=duration returns target.
- [ ] **AC-AS-22** — Null music cue for a target state: `push_error()` logged; `music_state` unchanged; no music player stream changed.

---

## Implementation Notes

*Derived from ADR-0012:*

### State enum

```gdscript
enum MusicState {
    MAIN_MENU = 0,
    PREPARATION = 1,
    COMBAT = 2,
    DYING = 3,
    END_VICTORY = 4,
    END_DEFEAT = 5,
}
var _music_state: MusicState = MusicState.MAIN_MENU
```

### GSM signal connections (in _ready, after is_instance_valid guard)

```gdscript
GameStateManager.run_started.connect(_on_run_started)
GameStateManager.combat_started.connect(_on_combat_started)
GameStateManager.preparation_started.connect(_on_preparation_started)
GameStateManager.death_started.connect(_on_death_started)   # Story 004
GameStateManager.run_ended.connect(_on_run_ended)
# wave_ended is intentionally NOT connected — preparation_started is the authoritative trigger
```

### Crossfade initiation (required order)

```gdscript
func _crossfade_to(new_state: MusicState, fade_duration: float) -> void:
    var cue: AudioStream = _get_cue_for_state(new_state)
    if cue == null:
        push_error("AudioSystem: No cue for state %d — transition blocked." % new_state)
        return
    _music_state = new_state
    var incoming: AudioStreamPlayer = _music_players[_inactive_music_idx]
    var outgoing: AudioStreamPlayer = _music_players[_active_music_idx]
    # Step 1: assign stream to incoming
    incoming.stream = cue
    # Step 2: pre-set to -80 BEFORE play() — prevents single-frame pop
    incoming.volume_db = -80.0
    # Step 3: start playback
    incoming.play()
    # Step 4: kill any in-progress tween
    if _active_tween != null:
        _active_tween.kill()
    # Step 5: simultaneous crossfade
    if fade_duration <= 0.0:
        outgoing.volume_db = -80.0
        incoming.volume_db = 0.0
    else:
        _active_tween = create_tween()
        _active_tween.set_parallel(true)
        if new_state in [MusicState.END_VICTORY, MusicState.END_DEFEAT]:
            _active_tween.set_trans(Tween.TRANS_SINE)  # constant-power for 2.0s fade
        _active_tween.tween_property(outgoing, "volume_db", -80.0, fade_duration)\
            .from(outgoing.volume_db)
        _active_tween.tween_property(incoming, "volume_db", 0.0, fade_duration)
    # Swap A/B ownership
    _inactive_music_idx = _active_music_idx
    _active_music_idx = 1 - _active_music_idx
```

### Crossfade duration constants

```gdscript
const CROSSFADE_DURATION_TO_COMBAT: float = 0.1
const CROSSFADE_DURATION_MENU_TO_PREPARATION: float = 1.0
const CROSSFADE_DURATION_COMBAT_TO_PREPARATION: float = 0.8
const CROSSFADE_DURATION_TO_END: float = 2.0
const CROSSFADE_DURATION_TO_MAIN_MENU: float = 0.5
const CROSSFADE_DURATION_TO_DYING: float = 0.1  # Story 004
```

### END states — non-interruptible

```gdscript
func _on_run_started() -> void:
    if _music_state in [MusicState.END_VICTORY, MusicState.END_DEFEAT]:
        return  # non-interruptible
    _crossfade_to(MusicState.PREPARATION, CROSSFADE_DURATION_MENU_TO_PREPARATION)
```
Apply the same guard to `_on_combat_started`, `_on_preparation_started`, `_on_run_ended`.

### _compute_crossfade_volume() — test-only pure function

```gdscript
func _compute_crossfade_volume(start_db: float, target_db: float, t: float, duration: float) -> float:
    if duration <= 0.0:
        return target_db
    return lerpf(start_db, target_db, t / duration)
```

This function is NEVER called from `_process()` or runtime paths — test-only.

---

## Out of Scope

- Story 004: `death_started` → DYING, DYING hold guard, END auto-transition (finished signal)
- Story 005: `play_ambient()` / `stop_ambient()`
- Story 006: `play_stinger()` / `stop_stinger()`

---

## QA Test Cases

**AC-AS-08**: Initial state
- Given: AudioSystem ready
- When: `_music_state` read
- Then: `== MusicState.MAIN_MENU`

**AC-AS-09**: run_started → PREPARATION
- Given: State is MAIN_MENU
- When: `AudioSystem._on_run_started()` called directly
- Then: `_music_state == MusicState.PREPARATION`; `_active_tween` non-null

**AC-AS-10**: combat_started → COMBAT
- Given: State set to PREPARATION
- When: `AudioSystem._on_combat_started(false)`
- Then: `_music_state == MusicState.COMBAT`

**AC-AS-11**: preparation_started → PREPARATION; wave_ended no-op
- Given: State set to COMBAT
- When A: `AudioSystem._on_wave_ended()` called → assert state remains `MusicState.COMBAT`
- When B: `AudioSystem._on_preparation_started()` called → assert `MusicState.PREPARATION`

**AC-AS-33**: wave_ended + preparation_started = exactly one tween
- Given: State is COMBAT; capture initial `_active_tween` (may be null)
- When: `_on_wave_ended()` → assert no new tween; `_on_preparation_started()` → assert `_active_tween` is non-null and distinct from initial

**AC-AS-12**: run_ended(false) → END_DEFEAT
- Given A: State = PREPARATION; When: `_on_run_ended(false)` → Then: `END_DEFEAT`
- Given B: State = COMBAT; When: `_on_run_ended(false)` → Then: `END_DEFEAT`

**AC-AS-13**: run_ended(true) → END_VICTORY (mirror of AC-AS-12)

**AC-AS-14**: Mid-crossfade re-transition cancels prior tween
- Given: Initiate PREPARATION→COMBAT (`_on_combat_started(false)`); capture `tween_1 = _active_tween`
- When: Immediately call `_on_run_ended(false)`
- Then: `not tween_1.is_valid()`; `_active_tween != tween_1`; `_music_state == END_DEFEAT`

**AC-AS-15**: END states block all signals
- Given: State = END_DEFEAT
- When: `_on_run_started()`, `_on_combat_started(false)`, `_on_wave_ended()`, `_on_run_ended(true)` all called
- Then: `_music_state` remains `END_DEFEAT` after all four

**AC-AS-16**: _compute_crossfade_volume formula
- `_compute_crossfade_volume(-6.0, -80.0, 0.5, 1.0)` within ±0.01 of −43.0
- `_compute_crossfade_volume(-80.0, 0.0, 0.5, 1.0)` within ±0.01 of −40.0
- `_compute_crossfade_volume(-6.0, -80.0, 0.0, 1.0) == -6.0`
- `_compute_crossfade_volume(-6.0, -80.0, 1.0, 1.0) == -80.0`

**AC-AS-22**: Null cue blocks transition
- Given: State = PREPARATION; set COMBAT cue to null
- When: `_on_combat_started(false)` called
- Then: `_music_state == MusicState.PREPARATION`; no player stream changed; `push_error()` logged

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/audio/music_fsm_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (AudioSystem scaffold, music A/B players must exist)
- Unlocks: Story 004 (DYING builds on the FSM and crossfade infrastructure)
