# Story 001: Foundation — Resource Classes + AudioSystem Scaffold

> **Epic**: Audio System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3h
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-18

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: `TR-AS-001`, `TR-AS-005`, `TR-AS-010`, `TR-AS-011`

**ADR Governing Implementation**: ADR-0012: Audio System Implementation Contract
**ADR Decision Summary**: AudioSystem is Autoload #5 (after GameStateManager #3). All 30 managed nodes created in `_ready()` with strict process mode assignments. validate-on-register at startup. `push_error()` guards everywhere — no `assert()` (stripped in release builds).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `AudioStreamPlayer`, `AudioServer`, `Tween.set_parallel()` all stable since ~4.3. `Time.get_ticks_msec()` preferred over deprecated `OS.get_ticks_msec()`.

**Control Manifest Rules (Foundation layer)**:
- Required: Register AudioSystem at Autoload position 5 — after GameStateManager (#3), before HealthAndDamage (#6)
- Required: `AudioSystem._ready()` validates `is_instance_valid(GameStateManager)` with `push_error()` before connecting any signals
- Required: `AudioEventRegistry` loaded from `res://assets/data/audio_event_registry.tres` at startup — no hardcoded event data in GDScript
- Required: All startup guards use `push_error()`, not `assert()`
- Forbidden: Never access Autoloads in `_init()`, `@export` default expressions, or static initializers

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`:*

- [ ] **AC-AS-01** — On startup, AudioSystem verifies exactly 5 audio buses: `Master`, `Music`, `SFX`, `UI`, `AMB`. `AudioServer.get_bus_index()` for each returns ≥ 0; `AudioServer.get_bus_count() == 5`.
- [ ] **AC-AS-02** — `Music`, `SFX`, `UI`, `AMB` buses have `Master` as parent. `AudioServer.get_bus_send(bus_idx)` returns `&"Master"` for each of the four; Master's send returns `&""`.
- [ ] **AC-AS-21** — `AudioSystem.play_event()` is callable from any GDScript node without explicit reference — no null-reference error, and a pool slot changes state.
- [ ] **AC-AS-32** — Process modes correct on all 30 managed nodes: Music A + B → `ALWAYS`; Ambient A + B → `ALWAYS`; UI player → `ALWAYS`; Stinger player → `ALWAYS`; all 24 SFX pool nodes → `PAUSABLE`.

---

## Implementation Notes

*Derived from ADR-0012:*

### Files to Create

```
src/audio/audio_event_data.gd        # Custom Resource: stream, bus, priority, duck params
src/audio/audio_event_registry.gd    # Custom Resource: events Dictionary[StringName, AudioEventData]
src/audio/audio_system.gd            # Autoload Node — the full AudioSystem singleton
assets/data/audio_event_registry.tres  # Empty placeholder (populated by audio-director later)
```

### AudioEventData schema

```gdscript
class_name AudioEventData
extends Resource

@export var stream: AudioStream
@export var bus: StringName = &"SFX"
@export var priority: int = 1       # 0=LOW, 1=NORMAL, 2=HIGH
@export var duck_depth_db: float = -6.0
@export var restore_duration_sec: float = 0.5
@export var stinger_priority: int = 0  # 0=COMBAT, 1=NARRATIVE
```

### AudioEventRegistry schema

```gdscript
class_name AudioEventRegistry
extends Resource

@export var events: Dictionary[StringName, AudioEventData]
```

### AudioSystem skeleton structure

```gdscript
class_name AudioSystem
extends Node

# Bus name constants — only place in the codebase that defines these
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const BUS_UI: StringName = &"UI"
const BUS_AMB: StringName = &"AMB"

const SFX_POOL_SIZE: int = 24

# Managed nodes (all created in _ready — never scene-wired)
var _music_players: Array[AudioStreamPlayer] = []   # [A, B]
var _ambient_players: Array[AudioStreamPlayer] = [] # [A, B]
var _ui_player: AudioStreamPlayer
var _stinger_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []

var _validated_events: Dictionary[StringName, AudioEventData] = {}
```

### _ready() order

1. Guard: `is_instance_valid(GameStateManager)` → `push_error()` + return if fails
2. Create 2 Music players (A/B) — `process_mode = PROCESS_MODE_ALWAYS`, bus = BUS_MUSIC
3. Create 2 Ambient players (A/B) — `process_mode = PROCESS_MODE_ALWAYS`, bus = BUS_AMB
4. Create 1 UI player — `process_mode = PROCESS_MODE_ALWAYS`, bus = BUS_UI
5. Create 1 Stinger player — `process_mode = PROCESS_MODE_ALWAYS`, bus = BUS_SFX
6. Create 24 SFX pool nodes — `process_mode = PROCESS_MODE_PAUSABLE`, bus = BUS_SFX
7. Load and validate AudioEventRegistry (see Story 002 for full validate-on-register)
8. Connect GSM signals (see Story 003)

All nodes use `call_deferred("add_child", node)` per ADR-0002.

### Project Settings config

5 buses must be configured in Project Settings → Audio → Buses:
- `Master` (default, always exists)
- `Music` → send to `Master`
- `SFX` → send to `Master`
- `UI` → send to `Master`
- `AMB` → send to `Master`

This is an editor-side configuration step, not code. Document in test setup.

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 002: Pool slot assignment, eviction algorithm, `play_event()` routing
- Story 003: Music FSM states, GSM signal connections, crossfade logic
- Story 004: DYING state, DYING hold guard, END auto-transition
- Story 005: `play_ambient()` / `stop_ambient()`
- Story 006: `play_stinger()` / `stop_stinger()`
- Story 007: `set_*_volume()` / `get_*_volume()`, clamping, Formula 2

---

## QA Test Cases

**AC-AS-01**: 5 buses exist with canonical names
- Given: AudioSystem has completed `_ready()`
- When: `AudioServer.get_bus_index()` called for each of `Master`, `Music`, `SFX`, `UI`, `AMB`
- Then: All 5 return ≥ 0; `AudioServer.get_bus_count() == 5`
- Edge cases: Bus configured with wrong capitalisation → index returns -1, test fails (correct — bus name must match exactly)

**AC-AS-02**: Bus parent routing correct
- Given: AudioSystem ready
- When: `AudioServer.get_bus_send(idx)` called for Music, SFX, UI, AMB bus indices
- Then: All 4 return `&"Master"`; `AudioServer.get_bus_send(master_idx) == &""`
- Edge cases: Project Settings not configured → bus not found, AC-AS-01 fails first

**AC-AS-21**: Callable from any node
- Given: A standalone test node (not AudioSystem itself)
- When: `AudioSystem.play_event(&"dummy_sfx")` called with a registered dummy event
- Then: No null-reference error; a pool slot changes stream state
- Edge cases: AudioSystem not in AutoLoad order → global name not available, push_error fires

**AC-AS-32**: All 30 nodes have correct process modes
- Given: AudioSystem ready
- When: Process mode queried on each of 30 managed nodes
- Then: `_music_players[0,1]` → `PROCESS_MODE_ALWAYS`; `_ambient_players[0,1]` → `PROCESS_MODE_ALWAYS`; `_ui_player` → `PROCESS_MODE_ALWAYS`; `_stinger_player` → `PROCESS_MODE_ALWAYS`; all 24 `_sfx_pool` nodes → `PROCESS_MODE_PAUSABLE`
- Edge cases: Node created but not added to tree → process mode still assertable on the object

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/audio/audio_system_foundation_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None — this is the foundation story; implement first
- Unlocks: Story 002 (needs `_sfx_pool` and `_validated_events` to exist)
