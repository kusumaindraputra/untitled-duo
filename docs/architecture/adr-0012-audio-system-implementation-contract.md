# ADR-0012: AudioSystem Implementation Contract

## Status
Accepted

## Date
2026-05-29

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Audio |
| **Knowledge Risk** | LOW — No audio-specific breaking changes in Godot 4.4, 4.5, or 4.6. `AudioStreamPlayer`, `AudioServer`, and `Tween` APIs unchanged since ~4.3. |
| **References Consulted** | `docs/engine-reference/godot/modules/audio.md`, `docs/engine-reference/godot/breaking-changes.md` |
| **Post-Cutoff APIs Used** | `Time.get_ticks_msec()` (preferred over deprecated `OS.get_ticks_msec()`) — stable in 4.6. `Tween.set_parallel(true)` — stable. `Object.CONNECT_ONE_SHOT` — stable. |
| **Verification Required** | Manual QA only: crossfade audibility test in-editor before shipping any music cue. No API verification required — all audio APIs confirmed stable. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Autoload Architecture — AudioSystem is Autoload #5, registered after GameStateManager at position 3) |
| **Depends On** | ADR-0003 (Signal-Driven Architecture — AudioSystem subscribes to `GameStateManager` signals in `_ready()`; must not poll state) |
| **Enables** | All systems that call `AudioSystem.play_event()`: HealthAndDamage, StatusEffectsManager, SpellCastingEffects, EnemyInstance, all UI systems, Save/Load |
| **Blocks** | Any implementation sprint that plays audio — no system may instantiate `AudioStreamPlayer` nodes directly until this ADR is Accepted |
| **Ordering Note** | `src/audio/audio_system.gd`, `AudioEventData`, and `AudioEventRegistry` resource classes must exist before any system calls `play_event()`. Bus layout must be configured in Project Settings before first play. |

## Context

### Problem Statement

AudioSystem is Autoload #5 (ADR-0002) and the sole audio service for all gameplay systems. Without a binding ADR, 12 TR IDs from `audio-system.md` are uncovered — leaving no architectural contract on which API callers must use, how the SFX pool manages concurrent sounds, what the music state machine responds to, and which patterns are explicitly forbidden. Any system could instantiate `AudioStreamPlayer` nodes directly, bypassing bus volume control and making player-facing audio settings non-functional.

### Constraints

- AudioSystem must survive all scene transitions — Autoload lifecycle fulfills this (ADR-0002)
- No 3D spatial audio at MVP — all sounds non-positional (top-down 2D)
- SFX must stop during pause; music, ambient, UI, and stinger audio must continue during pause
- `AudioSystem._ready()` connects to GameStateManager signals — position 5 (after GSM at position 3) guarantees safe connection
- No circular Autoload subscriptions (ADR-0003): AudioSystem connects TO GameStateManager; GameStateManager must NOT connect back to AudioSystem
- `set_music_volume()` upper bound: −3.0 dB — architectural invariant ensuring Prana SFX headroom over music at all supported settings
- `set_amb_volume()` upper bound: −10.0 dB — sonic identity invariant ("world breathes softly; magic screams")
- `assert()` is stripped in Godot 4 release builds — all startup guards must use `push_error()` to fire in both debug and release

### Requirements

- All audio interaction from external systems goes through `AudioSystem.play_event()` — no direct node creation
- Independent volume control per category: Master, Music, SFX, UI, AMB
- Up to ~20 simultaneous SFX events under worst-case peak (full 3×3 combo + Cluster swarm); pool must not evict under this scenario
- Music crossfades driven exclusively by GameStateManager signals — no polling
- `AudioEventRegistry` resource loaded from `.tres` at startup; zero hardcoded event data in GDScript
- All audio errors degrade gracefully (`push_error()` + continue) — a missing audio file must never crash the game

## Decision

AudioSystem is implemented as a Godot Autoload singleton (`class_name AudioSystem extends Node`) at project position 5. It owns four subsystems: the **bus layer**, the **SFX dispatcher**, the **ambient layer**, and the **music state machine**. All external audio interaction goes through the public API defined below.

### Bus Architecture

Four buses under Master, defined as `StringName` constants internal to AudioSystem. No other file may define these bus names independently.

| Bus | Parent | Node(s) | `process_mode` |
|-----|--------|---------|----------------|
| `&"Music"` | Master | 2 dedicated A/B `AudioStreamPlayer` nodes | `PROCESS_MODE_ALWAYS` |
| `&"SFX"` | Master | 24-slot pool of `AudioStreamPlayer` nodes | `PROCESS_MODE_PAUSABLE` |
| `&"UI"` | Master | 1 dedicated `AudioStreamPlayer` node | `PROCESS_MODE_ALWAYS` |
| `&"AMB"` | Master | 2 dedicated A/B `AudioStreamPlayer` nodes | `PROCESS_MODE_ALWAYS` |

One additional non-pooled stinger `AudioStreamPlayer` (`process_mode = PROCESS_MODE_ALWAYS`, routed to `&"SFX"`). Total managed nodes: **30** (2 music + 24 SFX pool + 2 ambient + 1 UI + 1 stinger).

### SFX Pool

24 `AudioStreamPlayer` nodes (`process_mode = PROCESS_MODE_PAUSABLE`) pre-instantiated at `_ready()`. All 24 slot timestamps initialize to `0`.

Slot assignment on `play_event()`:
1. First non-playing slot → assign and play.
2. All slots occupied → evict using priority tier: oldest LOW-priority slot first; if none, oldest NORMAL-priority slot; never evict HIGH unless all slots are HIGH; if all slots are HIGH, evict oldest HIGH.
3. **"Oldest" = slot with the smallest stored `Time.get_ticks_msec()` timestamp** (played least recently). Initial timestamp `0` makes never-played slots appear oldest — evicted before any active slot. Tiebreaker: lowest slot index.

Priority tiers from `AudioEventData.priority`: `0` = LOW, `1` = NORMAL, `2` = HIGH. Out-of-range priorities are clamped to NORMAL at registration time with a `push_error()`.

### Music State Machine

Six states, driven exclusively by GameStateManager signals. AudioSystem never polls or infers game state.

```
(startup)      → MAIN_MENU       initial state
MAIN_MENU      → PREPARATION     run_started signal
PREPARATION    → COMBAT          combat_started signal
COMBAT         → PREPARATION     preparation_started signal (NOT wave_ended)
COMBAT/PREP    → DYING           death_started signal
DYING          → END_DEFEAT      run_ended(win:false) — after DYING_MIN_HOLD_SEC = 1.5s
COMBAT/PREP    → END_VICTORY     run_ended(win:true)
COMBAT/PREP    → END_DEFEAT      run_ended(win:false) — defensive fallback
END_*          → MAIN_MENU       incoming cue's finished signal (auto-transition)
```

`wave_ended` is NOT connected to the music state machine. `preparation_started` is the sole authoritative trigger for COMBAT → PREPARATION.

`DYING` is intentional silence — no registered cue. `DYING_MIN_HOLD_SEC = 1.5s` guarantees the "moment breathes" claim regardless of animation duration; `run_ended(win:false)` arriving early is queued and fires at the 1.5s mark.

`END_VICTORY` and `END_DEFEAT` are non-interruptible by game signals. After the cue's `finished` signal fires, auto-transition to `MAIN_MENU`. `finished` is connected at crossfade initiation via `Object.CONNECT_ONE_SHOT` — not in a tween callback.

**END cue format constraint (non-negotiable):** END_VICTORY and END_DEFEAT `AudioStream` assets must be non-looping. `AudioStreamPlayer.finished` is not emitted for looping streams; a looping END cue silently prevents the auto-transition from firing.

### Crossfade Implementation

All state transitions use simultaneous tween crossfades:

```gdscript
if _active_tween != null:
    _active_tween.kill()
incoming_player.volume_db = -80.0       # pre-set BEFORE play() — prevents single-frame pop
incoming_player.play()
_active_tween = create_tween()
_active_tween.set_parallel(true)        # both tweens run simultaneously — no silence gap
_active_tween.tween_property(outgoing_player, "volume_db", -80.0, fade_duration)\
    .from(outgoing_player.volume_db)
_active_tween.tween_property(incoming_player, "volume_db", 0.0, fade_duration)
```

`CROSSFADE_TO_COMBAT` (0.1s): linear curve — combat music cuts in fast ("punches in").
`CROSSFADE_TO_END` (2.0s): `Tween.TRANS_SINE` — constant-power sinusoidal curve prevents the perceptible ~3 dB midpoint dip present on a long linear crossfade.
All other crossfades: default linear curve.

If `fade_duration <= 0.0`: skip the tween, set volumes directly (instant cut — valid for testing and specific transitions).

### Public API

```gdscript
# SFX / UI dispatch — the only external audio API for SFX and UI events
AudioSystem.play_event(event_name: StringName) -> void

# Ambient layer
AudioSystem.play_ambient(event_name: StringName) -> void
AudioSystem.stop_ambient() -> void

# Stingers (narrative/combat one-shots with music ducking)
AudioSystem.play_stinger(event_name: StringName) -> void
AudioSystem.stop_stinger() -> void

# Volume control (all dB, clamped −80.0 to 0.0 unless noted)
AudioSystem.set_master_volume(db: float) -> void
AudioSystem.set_music_volume(db: float) -> void   # upper bound clamped to −3.0 dB
AudioSystem.set_sfx_volume(db: float) -> void
AudioSystem.set_ui_volume(db: float) -> void
AudioSystem.set_amb_volume(db: float) -> void     # upper bound clamped to −10.0 dB
AudioSystem.get_master_volume() -> float
AudioSystem.get_music_volume() -> float
AudioSystem.get_sfx_volume() -> float
AudioSystem.get_ui_volume() -> float
AudioSystem.get_amb_volume() -> float
```

`play_event()` routes by `AudioEventData.bus`:
- `&"UI"` → dedicated UI player (PROCESS_MODE_ALWAYS — plays during pause)
- `&"SFX"` → SFX pool (PROCESS_MODE_PAUSABLE — silent during pause)
- `&"AMB"` → `push_error()`, return — callers must use `play_ambient()`
- Unregistered key → `push_error()`, return

### AudioEventRegistry

```gdscript
class_name AudioEventRegistry
extends Resource

@export var events: Dictionary[StringName, AudioEventData]
```

Loaded from `res://assets/data/audio_event_registry.tres` at startup. AudioSystem checks for null after `load()`, then validates all entries (priority range, stinger_priority range, type check) and routes all `play_event()` / `play_stinger()` calls through `_validated_events` — never the raw loaded dictionary. Validation errors are `push_error()` at startup; invalid entries are skipped or clamped, not silently accepted.

**StringName key requirement:** Callers who build dynamic event keys from variables must wrap in `StringName(...)`. In Godot 4 typed `Dictionary[StringName, ...]`, a `String` key will not match a `StringName` entry.

### AutoLoad Order Guard

```gdscript
func _ready() -> void:
    if not is_instance_valid(GameStateManager):
        push_error("AudioSystem: GameStateManager must be initialized before AudioSystem.")
        return
    # connect signals...
```

`push_error()` (not `assert()`) — fires in both debug and release builds.

### Forbidden Patterns

```gdscript
# FORBIDDEN: Direct AudioStreamPlayer instantiation outside AudioSystem
var player := AudioStreamPlayer.new()   # FORBIDDEN — bypasses bus volume control
add_child(AudioStreamPlayer.new())      # FORBIDDEN

# FORBIDDEN: Using play_event() with AMB-bus events (use play_ambient() instead)
AudioSystem.play_event("amb_arena_hum")  # FORBIDDEN — logs push_error(), no audio plays

# FORBIDDEN: wave_ended as a music state trigger
# AudioSystem does NOT connect to wave_ended — preparation_started is the authoritative trigger
```

## Alternatives Considered

### Alternative B: Scene-Local Audio Managers per Room

- **Description**: Each room scene owns its own `AudioStreamPlayer` nodes; there is no singleton. Rooms create players as needed and destroy them on unload.
- **Pros**: Local ownership — each scene manages its own audio; no global singleton to initialize
- **Cons**: Volume sliders (Music, SFX) would require iterating every active player in the tree on every slider change; music crossfades across scene transitions are impossible (both players need to coexist during the transition); SFX priority eviction across simultaneous systems is unimplementable without a global coordinator
- **Rejection Reason**: Incompatible with bus-level volume control and cross-scene music continuity. Eliminated by the Autoload architecture decision (ADR-0002) which mandates AudioSystem as a persistent global.

### Alternative C: Signal-Brokered Audio (Event Bus Pattern)

- **Description**: Systems emit `audio_requested(event_name)` signals on a shared bus; AudioSystem listens and dispatches. No direct `play_event()` calls.
- **Pros**: Further decouples callers from AudioSystem implementation
- **Cons**: Adds one indirection layer with no benefit — callers already use string event keys, so the API surface to consumers is identical. Signal emission is asynchronous in practice for this use case (fire-and-forget), adding latency to time-sensitive audio triggers (e.g., hit confirmation sounds)
- **Rejection Reason**: No advantage over direct call for a fire-and-forget audio service. Unnecessarily indirects what is already a clean unidirectional dependency.

### Alternative D: Pooled at Scene Level (AudioStreamPlayer as Scene Child)

- **Description**: Each gameplay scene embeds its SFX pool as scene children rather than in the Autoload singleton.
- **Pros**: Nodes are co-located with the scene that uses them
- **Cons**: Each scene would manage its own pool sizing, priority logic, and bus routing — duplicated across every scene; SFX from one scene cannot play after scene transition begins; volume control requires finding pool nodes across the tree
- **Rejection Reason**: All the complexity of a pool with none of the sharing benefit. The Autoload pattern (ADR-0002) exists precisely to handle this.

## Consequences

### Positive

- All systems call one API (`play_event()`) — no audio node management in gameplay code
- Bus architecture enables independent volume sliders that work from a single write to `AudioServer`
- 24-slot pool with priority eviction handles the worst-case simultaneous event count (≈20) with 4 slots of headroom
- Music transitions are testable in isolation via `AudioSystem._on_*` direct calls — no signal emission required in unit tests
- Validate-on-register surfaces audio authoring errors at startup in both debug and release builds

### Negative

- AudioSystem `_ready()` creates 30 `AudioStreamPlayer` nodes — small startup cost (~0.1ms estimated)
- `AudioEventRegistry.tres` is a single authoring bottleneck for the audio-director; merge conflicts are possible on the file during parallel content production
- Music state machine has no BOSS state at MVP — boss spawn uses the same COMBAT cue; a BOSS state requires a GDD revision and new ADR update at Vertical Slice

### Risks

- **Risk**: Developer misorders AutoLoad entries — AudioSystem `_ready()` fires before GameStateManager, signal connections silently fail.
  **Mitigation**: `is_instance_valid(GameStateManager)` guard in `_ready()` emits `push_error()` in release builds. AC-0002-01 verifies AutoLoad order at setup.
- **Risk**: `AudioEventRegistry.tres` not found at startup — all `play_event()` calls become no-ops, game launches silently.
  **Mitigation**: Null check after `load()` with `push_error()`. The game continues without audio rather than crashing. Startup smoke test AC-AS-01 validates bus presence.
- **Risk**: END cue delivered as a looping stream — auto-transition to `MAIN_MENU` never fires, music is stuck after run-end.
  **Mitigation**: Document as non-negotiable asset delivery constraint (GDD + ADR). Content review checklist: verify END cue loop mode is disabled before integration. AC-AS-26 covers the auto-transition via direct `finished.emit()`.
- **Risk**: Caller builds a dynamic event key as `String` instead of `StringName` — key lookup silently fails in the typed `Dictionary[StringName, AudioEventData]`.
  **Mitigation**: Documented in Public API section and GDD. Code review checklist: any dynamic `play_event()` call must wrap the key in `StringName(...)`.
- **Risk**: `set_music_volume()` or `set_amb_volume()` upper bound clamp not implemented — bus exceeds architectural ceiling, breaking the SFX headroom invariant.
  **Mitigation**: AC-AS-37 and AC-AS-38 verify upper bound clamping at both boundary and above-boundary input values.

## GDD Requirements Addressed

| GDD System | TR ID | Requirement | How This ADR Addresses It |
|------------|-------|-------------|--------------------------|
| audio-system.md | TR-AS-001 | 4-bus architecture: Master, Music, SFX, UI, AMB — bus names as StringName constants | Decision: Bus Architecture section defines all 4 buses, node types, and process modes |
| audio-system.md | TR-AS-002 | SFX pool: 24 nodes; priority-based eviction: oldest LOW first, then NORMAL; HIGH protected | Decision: SFX Pool section; oldest = smallest `Time.get_ticks_msec()` timestamp |
| audio-system.md | TR-AS-003 | Music A/B crossfade via `Tween.set_parallel(true)` — simultaneous fade; no silence gap; kill prior tween first | Decision: Crossfade Implementation section |
| audio-system.md | TR-AS-004 | `play_event()` routes by `bus` field: `&"UI"` → dedicated ALWAYS player; `&"SFX"` → pool; `&"AMB"` → error | Decision: Public API + Forbidden Patterns sections |
| audio-system.md | TR-AS-005 | Process modes: Music/Ambient/UI/Stinger ALWAYS; SFX pool PAUSABLE | Decision: Bus Architecture table |
| audio-system.md | TR-AS-006 | `set_music_volume()` max −3.0 dB — Prana SFX headroom invariant | Decision: Public API section; enforced by clamping in setter |
| audio-system.md | TR-AS-007 | `set_amb_volume()` max −10.0 dB — "world breathes softly" invariant | Decision: Public API section; enforced by clamping in setter |
| audio-system.md | TR-AS-008 | END cues must be non-looping assets — `finished` signal not emitted for looping streams | Decision: Music State Machine section; flagged as non-negotiable format constraint |
| audio-system.md | TR-AS-009 | DYING min hold 1.5s (`DYING_MIN_HOLD_SEC`) — `run_ended(win:false)` queued if early | Decision: Music State Machine section |
| audio-system.md | TR-AS-010 | AudioSystem registered after GameStateManager in AutoLoad order (#5) | ADR Dependencies + AutoLoad Order Guard section |
| audio-system.md | TR-AS-011 | Stinger player: non-pooled, `PROCESS_MODE_ALWAYS`, `&"SFX"` bus, separate from pool | Decision: Bus Architecture table (1 stinger node, 30 total) |
| audio-system.md | TR-AS-012 | Pool timestamp init to 0; evict slot with smallest `Time.get_ticks_msec()` = least recently played | Decision: SFX Pool section |

## Performance Implications

- **CPU**: `play_event()` is O(pool_size) in the worst case (all slots occupied, must scan for eviction candidate) — 24 iterations maximum. Negligible at 60 fps.
- **Memory**: 30 `AudioStreamPlayer` nodes at root level (~negligible); `AudioEventRegistry` resource in memory during play (~size of audio asset metadata, not the audio data itself — audio streams are loaded on-demand by Godot's streaming system)
- **Load Time**: 30-node instantiation + `.tres` registry load + validation loop at startup — estimated < 1ms on target hardware
- **Rendering**: N/A

## Validation Criteria

1. **AC-0012-01**: `AudioSystem.play_event("test_sfx_event")` callable from any GDScript node without explicit reference — AC-AS-21 covers this
2. **AC-0012-02**: Exactly 30 managed `AudioStreamPlayer` nodes exist after `_ready()` — AC-AS-32 covers process mode and node count
3. **AC-0012-03**: `set_music_volume(0.0)` clamps to −3.0 dB; `set_amb_volume(0.0)` clamps to −10.0 dB — AC-AS-37, AC-AS-38
4. **AC-0012-04**: Pool eviction respects priority contract with deterministic timestamps — AC-AS-06 (Tests A–D)
5. **AC-0012-05**: `wave_ended` does NOT trigger a music state transition — AC-AS-11, AC-AS-33
6. **AC-0012-06**: END_DEFEAT → MAIN_MENU auto-transition fires when `finished` signal emitted — AC-AS-26
7. **AC-0012-07**: `play_event()` with AMB-bus event logs `push_error()` and changes no player state — AC-AS-34
8. **AC-0012-08**: Project Settings → AutoLoad lists AudioSystem at position 5, after GameStateManager at position 3 — verified by AC-0002-01

## Related Decisions

- [ADR-0002: Autoload Architecture](adr-0002-autoload-architecture.md) — defines AudioSystem as Autoload #5; establishes the initialization order that makes GSM signals safe to connect in `_ready()`
- [ADR-0003: Signal-Driven Architecture](adr-0003-signal-driven-architecture.md) — AudioSystem must react to GSM signals, not poll state; direct `play_event()` calls from consumers are inward direct calls (not cross-Autoload writes) and are permitted
- [ADR-0006: GameEnums Pure Container](adr-0006-game-enums-pure-container.md) — AudioSystem does not use `GameEnums` directly, but `AudioEventData` resources use `StringName` constants for bus routing, not enums; no dependency
- [design/gdd/audio-system.md](../../design/gdd/audio-system.md) — authoritative full specification: all pool sizing rationale, crossfade duration tuning knobs, stinger priority policy, ambient crossfade semantics, and acceptance criteria
