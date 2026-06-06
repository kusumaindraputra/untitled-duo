# Story 002: Cast Input, Float Accumulators, and Chain Timing

> **Epic**: Spell Casting & Effects
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: ~2 hours
> **Manifest Version**: 2026-06-03
> **Last Updated**: —

## Context

**GDD**: `design/gdd/spell-casting-effects.md`
**Requirement**: `TR-SC-002`, `TR-SC-006`, `TR-SC-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Float Accumulator Timer Pattern (primary)
**ADR Decision Summary**: All in-game timing uses float delta accumulators in `_process(delta)`. Decrement by `tick_rate`, never reset to 0.0 — preserves sub-frame precision. `PROCESS_MODE_PAUSABLE` ensures timers halt on tree pause.

**Secondary ADRs**: ADR-0003 (cast_hit_started and chain_index_changed are signals emitted per ADR-0003 Pattern 1)

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Input.is_action_just_pressed()` works in headless tests only via `InputMap.action_press()` + `_input()` synthetic injection. Use `Input.action_press(&"cast")` / `Input.action_release(&"cast")` in `before_test()`/`after_test()` to simulate cast presses headlessly (established pattern from PlayerController Story 002).

**Control Manifest Rules (Core Layer)**:
- Required: All in-game timing via float accumulators in `_process(delta)` — no Timer nodes, no SceneTree.create_timer()
- Required: Decrement accumulator by tick_rate, never reset to 0.0
- Required: `process_mode = PROCESS_MODE_PAUSABLE` (set in Story 001 skeleton)
- Required: `cast_hit_started(lock_duration: float)` signal emitted after each hit
- Required: `chain_index_changed(combo_index: int, combo_attack_count: int)` emitted on every _combo_index change

---

## Acceptance Criteria

*From GDD `design/gdd/spell-casting-effects.md`, scoped to this story:*

- [ ] **AC-SC-02** — Cast input rejected when `_state == IDLE`: `apply_damage` never called; `_combo_index` remains 0
- [ ] **AC-SC-03** — Cast input rejected when `_cast_lock_timer > 0`: no attack; `_combo_index` unchanged
- [ ] **AC-SC-04** — `_combo_index` advances on successive casts within window: Deepfrost T3 (combo_attack_count=3), cast fires → lock expires via `_process(0.13)` → cast fires again → `_combo_index == 2`
- [ ] **AC-SC-05** — Chain resets to READY when `combo_continuation_window` (2.0s) expires without a cast: `_combo_index == 0`, `_state == READY`
- [ ] **AC-SC-10** — Cast lock durations: Voidblue T1 → `cast_hit_started` emits with `lock_duration == 0.12`; Ashfire T1 → `cast_hit_started` emits with `lock_duration == 0.20`

---

## Implementation Notes

*Derived from ADR-0004, ADR-0003:*

**Constants** (data-driven values; define as class constants):
```gdscript
const CAST_LOCK_DURATION: float = 0.12        ## Default cast lock (all types except Ashfire)
const ASHFIRE_CAST_LOCK_DURATION: float = 0.20 ## Extended lock for Ashfire dance identity
const COMBO_CONTINUATION_WINDOW: float = 2.0   ## Seconds player has to press next chain attack
```

**Private state additions** (to existing skeleton vars):
```gdscript
var _cast_lock_timer: float = 0.0        ## Counts down after each hit; blocks cast input when > 0
var _combo_window_timer: float = 0.0     ## Counts down between chain presses; resets on each cast
```

**`_process(delta)` body** (float accumulator pattern per ADR-0004):
```gdscript
func _process(delta: float) -> void:
    if _cast_lock_timer > 0.0:
        _cast_lock_timer -= delta
        if _cast_lock_timer <= 0.0:
            _cast_lock_timer = 0.0
            if _state == SCEState.CAST_LOCKED:
                _state = SCEState.CHAINING if _combo_index > 0 else SCEState.READY

    if _state == SCEState.CHAINING:
        _combo_window_timer -= delta
        if _combo_window_timer <= 0.0:
            # Combo window expired — reset chain to READY
            _combo_index = 0
            _state = SCEState.READY
            chain_index_changed.emit(0, _current_spell_effect.combo_attack_count if _current_spell_effect else 0)

    if (_state == SCEState.READY or _state == SCEState.CHAINING) and _cast_lock_timer <= 0.0:
        if Input.is_action_just_pressed(&"cast"):
            _trigger_cast()
```

**`_trigger_cast()` (no damage logic yet — placeholder for Story 003)**:
```gdscript
func _trigger_cast() -> void:
    if _current_spell_effect == null:
        return
    var combo_count: int = _current_spell_effect.combo_attack_count
    # Story 003 will implement _fire_attack() here
    # For Story 002: advance state only; no apply_damage yet
    _combo_index += 1
    chain_index_changed.emit(_combo_index, combo_count)

    var lock_dur: float = ASHFIRE_CAST_LOCK_DURATION if _current_spell_effect.primary_type == 0 \
        else CAST_LOCK_DURATION
    cast_hit_started.emit(lock_dur)
    _cast_lock_timer = lock_dur
    _state = SCEState.CAST_LOCKED
    _combo_window_timer = COMBO_CONTINUATION_WINDOW

    if _combo_index >= combo_count:
        # Final attack in chain — Story 003 handles reset after lock expires
        pass
```

**Note on cast action**: Ensure `cast` action is registered in InputMap. Add in `_ready()` if not already present:
```gdscript
if not InputMap.has_action(&"cast"):
    InputMap.add_action(&"cast")
    var ev := InputEventKey.new()
    ev.keycode = KEY_SPACE
    InputMap.action_add_event(&"cast", ev)
```

**_on_preparation_started() addition**: reset both timers:
```gdscript
_cast_lock_timer = 0.0
_combo_window_timer = 0.0
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: State machine skeleton, SpellEffect Resource, Autoload registration
- [Story 003]: _fire_attack(), apply_damage, spell_hit_element, damage formula, status stubs
- [Story 004]: Integration test

---

## QA Test Cases

*From qa-plan-sprint-3-2026-06-03.md (S3-08 section). Implement against these.*

**Test file**: `tests/unit/spell-casting-effects/cast_chain_test.gd`

- **AC-SC-02**: Cast rejected in IDLE
  - Given: SC&E in IDLE state (no combo_resolved received)
  - When: cast action pressed (via `Input.action_press(&"cast")` + `_input()` call)
  - Then: `apply_damage` never called; `_combo_index == 0`

- **AC-SC-03**: Cast rejected when cast-locked
  - Given: SC&E in READY state with valid SpellEffect; `_cast_lock_timer = 0.05`
  - When: cast action fires
  - Then: no attack; `_combo_index` unchanged (still 0)

- **AC-SC-04**: _combo_index advances
  - Given: Deepfrost T3 SpellEffect (combo_attack_count=3) cached; SC&E in READY state
  - When: cast fires; `_process(0.13)` called (lock expires); cast fires again
  - Then: `_combo_index == 2` after second press

- **AC-SC-05**: Chain resets on window expiry
  - Given: SC&E in CHAINING state with `_combo_index=1`, `_combo_window_timer=2.0`
  - When: `_process(delta)` called with cumulative delta ≥ 2.0s without cast press
  - Then: `_combo_index == 0`; `_state == READY`; `chain_index_changed(0, combo_count)` emitted

- **AC-SC-10**: Cast lock durations
  - Given (a): SC&E in READY with Voidblue T1 SpellEffect (primary_type=1); valid target injected
  - When: cast fires
  - Then: `cast_hit_started` emits with `lock_duration == 0.12`
  - Given (b): SC&E in READY with Ashfire T1 SpellEffect (primary_type=0)
  - When: cast fires
  - Then: `cast_hit_started` emits with `lock_duration == 0.20`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/spell-casting-effects/cast_chain_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 DONE (state machine skeleton, _state enum, _current_spell_effect)
- Unlocks: Story 003 (needs _trigger_cast() hook to inject _fire_attack() into)
