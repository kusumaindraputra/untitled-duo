# Story 007: Volume Control + Formula 2

> **Epic**: Audio System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2h
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-18

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: `TR-AS-006`, `TR-AS-007`

**ADR Governing Implementation**: ADR-0012: Audio System Implementation Contract
**ADR Decision Summary**: `set_*_volume()` writes directly to `AudioServer`. Clamped −80.0–0.0 dB for all buses, except Music upper bound = −3.0 dB and AMB upper bound = −10.0 dB (architectural invariants). `get_*_volume()` reads from `AudioServer.get_bus_volume_db()` directly — not from cached class variables. `_slider_to_db()` uses `float(slider_value) / 100.0` (float divisor mandatory — int/int = integer division → wrong results).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: All `AudioServer` bus volume APIs stable since Godot 4.0. `is_equal_approx()` available for float comparisons.

**Control Manifest Rules (Foundation layer)**:
- Required: All startup guards use `push_error()`, not `assert()`

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`:*

- [ ] **AC-AS-17** — `set_music_volume(-20.0)` → `AudioServer.get_bus_volume_db(music_idx) == -20.0` (within `is_equal_approx` tolerance).
- [ ] **AC-AS-18** — `set_sfx_volume(-200.0)` (below −80.0) → bus clamped to −80.0.
- [ ] **AC-AS-19** — `set_master_volume(10.0)` (above 0.0) → bus clamped to 0.0.
- [ ] **AC-AS-30** — `set_ui_volume(-200.0)` → −80.0; `set_amb_volume(-200.0)` → −80.0.
- [ ] **AC-AS-37** — `set_music_volume()` upper bound: −3.0 dB.
  - `set_music_volume(-3.0)` → bus at −3.0 (at boundary — allowed)
  - `set_music_volume(-1.0)` → bus clamped to −3.0
  - `set_music_volume(10.0)` → bus clamped to −3.0 (not 0.0)
- [ ] **AC-AS-38** — `set_amb_volume()` upper bound: −10.0 dB.
  - `set_amb_volume(-10.0)` → bus at −10.0 (boundary)
  - `set_amb_volume(-5.0)` → clamped to −10.0
  - `set_amb_volume(0.0)` → clamped to −10.0
- [ ] **AC-AS-20** — `get_music_volume()` round-trip:
  - −6.0 (in-range) → getter returns −6.0
  - −80.0 (lower boundary) → returns −80.0
  - −100.0 (out-of-range) → returns −80.0 (clamped)
- [ ] **AC-AS-31** — `_slider_to_db(50)` within ±0.01 of −40.0; `_slider_to_db(0)` = −80.0; `_slider_to_db(100)` = 0.0.

---

## Implementation Notes

*Derived from ADR-0012:*

### Volume setters pattern

```gdscript
func set_music_volume(db: float) -> void:
    # Music upper bound is -3.0 dB (SFX headroom invariant — see ADR-0012)
    var clamped: float = clampf(db, -80.0, -3.0)
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_MUSIC), clamped)

func set_amb_volume(db: float) -> void:
    # AMB upper bound is -10.0 dB (sonic identity invariant — see ADR-0012)
    var clamped: float = clampf(db, -80.0, -10.0)
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_AMB), clamped)

func set_master_volume(db: float) -> void:
    AudioServer.set_bus_volume_db(
        AudioServer.get_bus_index(&"Master"), clampf(db, -80.0, 0.0))

func set_sfx_volume(db: float) -> void:
    AudioServer.set_bus_volume_db(
        AudioServer.get_bus_index(BUS_SFX), clampf(db, -80.0, 0.0))

func set_ui_volume(db: float) -> void:
    AudioServer.set_bus_volume_db(
        AudioServer.get_bus_index(BUS_UI), clampf(db, -80.0, 0.0))
```

### Volume getters — read from AudioServer directly (not cached)

```gdscript
func get_music_volume() -> float:
    return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(BUS_MUSIC))

func get_sfx_volume() -> float:
    return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(BUS_SFX))

func get_master_volume() -> float:
    return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Master"))

func get_ui_volume() -> float:
    return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(BUS_UI))

func get_amb_volume() -> float:
    return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(BUS_AMB))
```

### Formula 2 — slider → dB (test-accessible pure function)

```gdscript
func _slider_to_db(slider_value: int) -> float:
    # float() cast is mandatory — int/int would produce 0 for all values 0-99
    return lerpf(-80.0, 0.0, float(slider_value) / 100.0)
```

### Test teardown requirement (GDD §Acceptance Criteria preamble)

All integration tests covering volume must include `after_each` teardown:
1. `AudioSystem.set_music_volume(-6.0)` (not 0.0 — Music max is −3.0)
2. `AudioSystem.set_sfx_volume(0.0)`
3. `AudioSystem.set_ui_volume(-3.0)`
4. `AudioSystem.set_amb_volume(-12.0)`
5. `AudioSystem.set_master_volume(0.0)`

Failure to reset leaves Music bus above −3.0 dB for subsequent tests.

---

## Out of Scope

- Persistence (Save/Load calls these setters on load — owned by Save/Load epic)
- Slider UI debounce (owned by Pause Menu / Settings GDD)
- Perceptual volume curve fix (deferred post-MVP per GDD Open Question 8)

---

## QA Test Cases

**AC-AS-17**: In-range set/get round-trip
- Given: AudioSystem ready
- When: `set_music_volume(-20.0)` called
- Then: `AudioServer.get_bus_volume_db(music_idx)` within `is_equal_approx` tolerance of −20.0
- Edge cases: Verify getter reads AudioServer directly (not a stale cached value)

**AC-AS-18**: Lower-bound clamp (SFX)
- When: `set_sfx_volume(-200.0)`
- Then: `AudioServer.get_bus_volume_db(sfx_idx) == -80.0`

**AC-AS-19**: Upper-bound clamp (Master)
- When: `set_master_volume(10.0)`
- Then: `AudioServer.get_bus_volume_db(master_idx) == 0.0`

**AC-AS-30**: Lower-bound clamp (UI + AMB)
- When: `set_ui_volume(-200.0)` → assert −80.0; `set_amb_volume(-200.0)` → assert −80.0

**AC-AS-37**: Music upper bound at −3.0 dB
- `set_music_volume(-3.0)` → assert −3.0 (boundary allowed)
- `set_music_volume(-1.0)` → assert −3.0 (clamped)
- `set_music_volume(10.0)` → assert −3.0 (not 0.0)

**AC-AS-38**: AMB upper bound at −10.0 dB
- `set_amb_volume(-10.0)` → assert −10.0; `set_amb_volume(-5.0)` → assert −10.0; `set_amb_volume(0.0)` → assert −10.0

**AC-AS-20**: get_music_volume() round-trip
- After `set_music_volume(-6.0)` → `get_music_volume() == -6.0`
- After `set_music_volume(-80.0)` → `get_music_volume() == -80.0`
- After `set_music_volume(-100.0)` → `get_music_volume() == -80.0` (clamped)

**AC-AS-31**: _slider_to_db() formula
- `_slider_to_db(50)` within ±0.01 of −40.0
- `_slider_to_db(0) == -80.0`
- `_slider_to_db(100) == 0.0`
- Edge case: `_slider_to_db(1)` is between −80.0 and −79.0 (not 0.0 — float divisor confirmed)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/audio/volume_control_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (AudioSystem scaffold, buses configured in Project Settings)
- Unlocks: None — volume control is self-contained
