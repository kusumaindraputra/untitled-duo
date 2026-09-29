# Audio System

> **Status**: Approved
> **Author**: Kusuma Putra + Claude Code Game Studios
> **Last Updated**: 2026-05-26 (revision 4 — scope-down pass; 6 blockers fixed, 6 deferred as Open Questions)
> **Implements Pillar**: Infrastructure (enables Pillar 1, 3 — sonic feedback reinforces run variety and consequence)

## Overview

Audio System is the foundational audio management framework for The Last Cipher. It owns the audio bus hierarchy, the event-driven SFX dispatch system, ambient layer management, music state management, and all volume control interfaces. Every other system that produces sound — Game Feel / Juice, Spell Casting & Effects, Enemy AI, Health & Damage — calls into Audio System via an event API; they never instantiate audio nodes directly.

The system's four responsibilities are strictly separated: (1) the **bus layer** categorizes all audio into named buses (Music, SFX, UI, AMB) for independent volume control; (2) the **SFX dispatcher** maintains a pre-instantiated pool of `AudioStreamPlayer` nodes and assigns them on-demand to play registered sound events; (3) the **ambient layer** manages two dedicated non-pooled `AudioStreamPlayer` nodes (A/B crossfade pattern) routed to the AMB bus for continuous environmental texture with seamless transitions; (4) the **music manager** tracks the current game state and crossfades between registered music cues when the state transitions.

At MVP, no voice acting exists and no 3D spatial audio is needed (top-down 2D, all sounds non-positional). The bus architecture and event API must be stable before any other system implements audio feedback, making this a Foundation layer prerequisite for all sound design work. Specific cues, volumes, and music compositions are registered by the `audio-director` during content production — this GDD specifies the framework, not the content.

## Player Fantasy

Audio System is infrastructure the player never engages with directly. Its fantasy is experienced one layer up: the moment a Stormgold strike crackles and cuts through the room, or the ambient scrapyard hum drops into something tighter when the wave begins. The system that made that possible is invisible — which is the goal.

The design directive for this game's audio identity is: *"The world breathes softly; magic screams."* Audio System does not define what sounds exist — that is the audio-director's domain. It defines the scaffolding that makes the contrast possible: a Preparation cue that holds its breath before combat begins, a Combat cue that punches in fast, Prana effects that layer independently of ambient sound, combat feedback that doesn't fight with the music for headroom, and an AMB bus that carries the arena's environmental texture underneath everything. When the duo dies, music cuts to near-silence — the moment breathes before the run-end stinger plays.

A well-implemented Audio System should be unnoticeable to a player and indispensable to a developer. The test: any system author who needs to play a sound calls `AudioSystem.play_event("event_name")` and the rest is handled. No scene management. No `AudioStreamPlayer` nodes scattered across gameplay scripts.

## Detailed Design

### Core Rules

1. **Autoload singleton**: Audio System is implemented as a Godot Autoload (`AudioSystem`). All access is via the global name `AudioSystem`. No system instantiates `AudioStreamPlayer` nodes directly — all audio interaction goes through this singleton.

2. **Bus architecture** — four buses under Master:

   | Bus Name | Parent | Purpose |
   |----------|--------|---------|
   | `Master` | — | Root; controls overall output volume |
   | `Music` | Master | All music cues — crossfade-controlled |
   | `SFX` | Master | All gameplay sound effects — pool-routed |
   | `UI` | Master | Menu navigation and UI feedback — dedicated non-pooled player |
   | `AMB` | Master | Continuous looping ambient layers (environmental texture, room tone) — dedicated A/B players |

   Bus names are StringName constants defined in Audio System: `&"Music"`, `&"SFX"`, `&"UI"`, `&"AMB"`. No other file may define these names independently.

3. **SFX event system**: Audio System maintains an `AudioEventRegistry` — a typed dictionary (`Dictionary[StringName, AudioEventData]`) mapping StringName event keys to `AudioEventData` resources. Events are registered at startup from a `.tres` file populated by the audio-director. After `load()`, the result is checked for null before use (see Edge Case 11).

   `AudioEventData` resource schema:
   - `stream: AudioStream` — the audio stream to play
   - `bus: StringName` — target bus (`&"SFX"`, `&"UI"`, or `&"AMB"`); determines routing
   - `priority: int` — eviction tier: `0` = LOW, `1` = NORMAL, `2` = HIGH
   - `duck_depth_db: float` — default `−6.0`. How many dB the Music bus is ducked when this event is played via `play_stinger()`. Negative values only; `0.0` = no duck. Ignored by `play_event()`.
   - `restore_duration_sec: float` — default `0.5s`. Music bus restore duration after stinger finishes or `stop_stinger()` is called. Ignored by `play_event()`.
   - `stinger_priority: int` — `0` = COMBAT, `1` = NARRATIVE. Only evaluated by `play_stinger()`. A playing NARRATIVE stinger cannot be interrupted by a COMBAT stinger call. Any NARRATIVE stinger immediately interrupts a playing COMBAT stinger. Two stingers of the same priority follow Edge Case 15 (new-caller interrupts). Ignored by `play_event()`.

   `AudioSystem.play_event(event_name: StringName) -> void`

   This is the **only** public SFX and UI audio API. `play_event()` looks up the entry in `AudioEventRegistry` and routes based on the entry's `bus` field:
   - `bus == &"UI"` → dispatches to the dedicated UI player (PROCESS_MODE_ALWAYS; plays during pause)
   - `bus == &"SFX"` → assigns a pool slot (PROCESS_MODE_PAUSABLE; silent during pause)
   - `bus == &"AMB"` → reserved for internal ambient use; direct `play_event()` to AMB is not supported; use `play_ambient()` instead

   If no event is registered for the key, a no-op with a `push_error()` log.

   **Dynamic key construction note:** Callers who build event names from variables (e.g., `"sfx_prana_cast_" + prana_type_name`) must use `StringName("sfx_prana_cast_" + prana_type_name)`. In Godot 4 typed Dictionaries, `String` and `StringName` are not interchangeable for key lookup — a plain `String` key will not match a `StringName` registry entry.

4. **SFX pool**: 24 pre-instantiated `AudioStreamPlayer` nodes created at startup in `_ready()`. Pool nodes handle only `bus = &"SFX"` events; `bus = &"UI"` events bypass the pool entirely. All pool nodes have `process_mode = PROCESS_MODE_PAUSABLE` (SFX stops when the game is paused).

   **Worst-case sizing rationale:** Peak-of-peak scenario: a full 3×3 Prana combo (9 cast SFX, all NORMAL) during a Cluster swarm wave (5 Cluster enemies attacking simultaneously) produces: 9 Prana cast sounds + 5 enemy attack telegraphs + 5 hit-confirmation sounds + 1 the duo damage received (HIGH) = 20 simultaneous events minimum. Pool of 24 provides 4 slots of headroom for dash, status effects, and other concurrent feedback without any eviction under this worst-case scenario.

   **Pool timestamp initialization:** All 24 slots are initialized with timestamp `0` at startup (`_timestamps[i] = 0`). This makes all fresh (never-played) slots appear as oldest, ensuring they are evicted before any recently played slot. Tiebreaker for equal timestamps: lowest slot index wins (e.g., slot 0 is evicted before slot 1).

   When `play_event()` assigns to the pool:
   - Find the first non-playing slot → assign and play.
   - If all slots are playing → evict using priority: interrupt the oldest LOW-priority slot first; if none, the oldest NORMAL-priority slot; never interrupt a HIGH-priority slot unless only HIGH slots remain. If all slots are HIGH, evict the oldest HIGH.
   - **"Oldest" = the slot with the smallest stored `Time.get_ticks_msec()` timestamp value** — this is the slot played least recently. Do NOT find the slot with the largest timestamp (that would be the newest). To verify: if slots have timestamps [1000, 5000, 2000] and current time is 6000, elapsed times are [5000, 1000, 4000] — oldest is slot 0 (smallest timestamp 1000). Use `Time.get_ticks_msec()` (not `OS.get_ticks_msec()`, which is deprecated; not `get_playback_position()`, which wraps for looping audio). Store the current tick value when a slot begins playing.
   - The interrupted sound is dropped without fadeout.

5. **Ambient layer**: Two dedicated `AudioStreamPlayer` nodes (Ambient A and Ambient B) routed to the `AMB` bus, created at startup. Both have `process_mode = PROCESS_MODE_ALWAYS` (ambient continues during pause). The system alternates active ownership on each `play_ambient()` call — the same A/B ping-pong pattern used by the music players. This enables true simultaneous crossfades (one node fading out, the other fading in) with no silence gap.

   ```
   AudioSystem.play_ambient(event_name: StringName) -> void   # crossfades to new ambient
   AudioSystem.stop_ambient() -> void                          # fades out active ambient
   ```

   Both ambient fades run simultaneously via `_active_ambient_tween.set_parallel(true)`. Before creating any new ambient tween:
   ```gdscript
   if _active_ambient_tween != null:
       _active_ambient_tween.kill()
   ```

   Ambient events use the naming convention `"amb_[location]_[descriptor]"` (e.g., `"amb_arena_hum"`, `"amb_dungeon_drip"`). Ambient streams are registered in `AudioEventRegistry` with `bus = &"AMB"`.

6. **Music state machine**: 6 states — `MAIN_MENU`, `PREPARATION`, `COMBAT`, `DYING`, `END_VICTORY`, `END_DEFEAT`. Initial state at startup: `MAIN_MENU`. State transitions are driven exclusively by signals from Game State & Scene Flow — Audio System never polls or infers state from gameplay logic.

   **`DYING` state:** When the duo's death animation begins (`death_started` signal), music cuts to near-silence via `CROSSFADE_TO_DYING`. Both music players tween to −80 dB. The `DYING` state has no registered cue — it is intentional silence that lets the death moment breathe.

   **Minimum DYING hold time (1.5s):** Audio System will not act on `run_ended(win: false)` until at least 1.5 seconds have elapsed since entering `DYING`. If `run_ended` fires before the minimum elapses, Audio System queues the transition and fires it at the 1.5s mark. This guarantees the "moment breathes" claim in the Player Fantasy regardless of animation duration. The 1.5s constant is exposed as a tuning knob (`DYING_MIN_HOLD_SEC`). After the minimum elapses (or immediately if `run_ended` already fired), transition to `END_DEFEAT` normally.

   *Note: `combat_started(is_boss: true)` payload is received but not differentiated at MVP — boss combat uses the same `COMBAT` cue as regular waves. A `BOSS` music state is deferred to Vertical Slice scope and will require a GDD revision, a new registered cue, and a new signal payload contract.*

7. **Music transitions**: State changes use tween-based crossfade. Both tweens run **simultaneously**: the outgoing cue lerps from its current `volume_db` to −80 dB while the incoming cue lerps from −80 dB to 0 dB, both over the same fade duration.

   **Full crossfade initiation sequence (required order):**
   ```gdscript
   # 1. Assign the new stream to the incoming player
   incoming_player.stream = _get_cue_for_state(new_state)
   # 2. Pre-set incoming volume to -80.0 dB BEFORE play() — prevents a single-frame pop
   incoming_player.volume_db = -80.0
   # 3. Start playback
   incoming_player.play()
   # 4. Kill any in-progress tween before creating the new one
   if _active_tween != null:
       _active_tween.kill()
   # 5. Create the simultaneous crossfade
   _active_tween = create_tween()
   _active_tween.set_parallel(true)
   _active_tween.tween_property(outgoing_player, "volume_db", -80.0, fade_duration)\
       .from(outgoing_player.volume_db)
   _active_tween.tween_property(incoming_player, "volume_db", 0.0, fade_duration)\
       .from(-80.0)
   ```
   **Step 2 is mandatory.** If `incoming_player.volume_db` is not pre-set to −80.0 before `play()`, the AudioServer renders one buffer at 0.0 dB before the tween's first step — producing an audible pop at the start of every crossfade.

   `set_parallel(true)` is required — without it, Godot 4 executes `tween_property()` calls sequentially, producing a silence gap between states. The null guard on `_active_tween` prevents a crash on the first music transition (before any tween has ever been created).

   **`finished` signal connection for END states:** Connect `finished` **at crossfade initiation** — not in a tween-completion callback. A very short END cue can fire `finished` before the tween completes; connecting in a callback would miss this signal.
   ```gdscript
   # At crossfade initiation (after play() is called above):
   incoming_player.finished.connect(_on_end_cue_finished, Object.CONNECT_ONE_SHOT)

   # In the handler — always guard against stale connections:
   func _on_end_cue_finished() -> void:
       if _music_state != MusicState.END_VICTORY and _music_state != MusicState.END_DEFEAT:
           return  # Signal arrived late or out of sequence — discard
       _transition_to(MusicState.MAIN_MENU)
   ```
   The state guard is required. `Object.CONNECT_ONE_SHOT` prevents double-firing. Do not connect `finished` in a tween callback.

   Music requires **two dedicated `AudioStreamPlayer` nodes** (Player A and Player B), alternating ownership on each crossfade. Both are routed to the `Music` bus with `process_mode = PROCESS_MODE_ALWAYS` (music continues during pause). These are separate from and never shared with the SFX pool.

   `END_VICTORY` and `END_DEFEAT` states play their cue to completion (non-interruptible). After the cue's `finished` signal fires, the music auto-transitions to `MAIN_MENU`. No queuing — if a new `run_started` signal fires before the END cue finishes, it is ignored until the cue completes.

   **Dedicated UI player:** A single `AudioStreamPlayer` with `process_mode = PROCESS_MODE_ALWAYS`, routed to the `UI` bus, created at startup. `play_event()` routes events with `bus = &"UI"` to this node rather than the SFX pool. This player is non-pooled and non-priority — each new UI event interrupts the current UI sound. UI sounds play during pause because the node is `PROCESS_MODE_ALWAYS`.

8. **Volume control interface**:
   ```
   AudioSystem.set_master_volume(db: float)
   AudioSystem.set_music_volume(db: float)
   AudioSystem.set_sfx_volume(db: float)
   AudioSystem.set_ui_volume(db: float)
   AudioSystem.set_amb_volume(db: float)
   AudioSystem.get_master_volume() -> float   (and equivalent getters for all buses)
   ```
   These write directly to `AudioServer` bus volumes. All values are clamped to −80.0 – 0.0 dB at the setter. Getters read from `AudioServer.get_bus_volume_db()` directly — not from cached class variables — to remain accurate if other code modifies AudioServer directly. Persistence is handled by Save / Load, which calls these setters on load and reads the getters on save. Audio System does not own persistence.

9. **No external audio node creation**: Any system creating `AudioStreamPlayer` nodes outside Audio System bypasses the bus architecture and breaks volume control. This is a forbidden pattern (see `technical-preferences.md`).

10. **Process modes**:
    - Music Player A and B: `PROCESS_MODE_ALWAYS` — music continues during pause
    - Ambient Player A and B: `PROCESS_MODE_ALWAYS` — ambient continues during pause
    - Dedicated UI player: `PROCESS_MODE_ALWAYS` — UI sounds play during pause (Pause Menu)
    - Dedicated Stinger player: `PROCESS_MODE_ALWAYS` — narrative stingers play in any game state, including PAUSED and END states
    - SFX pool nodes: `PROCESS_MODE_PAUSABLE` — SFX stops during pause

11. **Autoload order**: `AudioSystem` must be listed **after** `GameStateManager` in Project Settings → AutoLoad. Signal connections established in `AudioSystem._ready()` assume `GameStateManager` is already initialized and its signals are available. Add the following guard at the top of `_ready()`:
    ```gdscript
    if not is_instance_valid(GameStateManager):
        push_error("AudioSystem: GameStateManager must be initialized before AudioSystem in AutoLoad order.")
        return
    ```
    **Note:** `assert()` is stripped entirely in Godot 4 release builds. This `push_error()` guard fires in both debug and release, preventing a silent null-dereference crash in production if AutoLoad order is misconfigured.

12. **Narrative stinger API**: Audio System maintains a single dedicated non-pooled `AudioStreamPlayer` for one-shot narrative moments (`_stinger_player`). `process_mode = PROCESS_MODE_ALWAYS` (plays in any game state, including PAUSED). Routed to the `SFX` bus. This player is separate from the SFX pool and cannot be evicted.

    ```
    AudioSystem.play_stinger(event_name: StringName) -> void
    AudioSystem.stop_stinger() -> void   # Stops in-progress stinger; restores Music bus
    ```

    **Behavior:**
    - Looks up the event in `AudioEventRegistry` (same registry as `play_event()`).
    - If the event has `bus = &"SFX"` or `bus = &"UI"`: evaluates stinger priority (see below), then plays.
    - If the event is not found: logs `push_error()` and returns without playing or ducking.

    **Stinger priority policy (from `AudioEventData.stinger_priority`):**
    - `NARRATIVE` (1) stinger in progress: a new `COMBAT` (0) stinger call is silently ignored — the narrative moment plays to completion.
    - `COMBAT` (0) stinger in progress: a new `NARRATIVE` (1) stinger immediately interrupts it.
    - Same priority: new caller interrupts (last-caller-wins), per Edge Case 15.

    **Music bus duck:**
    - Uses `event.duck_depth_db` (default −6.0 dB) as duck depth and `event.restore_duration_sec` (default 0.5s) as restore duration.
    - Duck fade-in: 0.1s.
    - **DYING state exception:** If `_music_state == MusicState.DYING` when `play_stinger()` is called, the duck tween is suppressed entirely (music is already at −80 dB; ducking further is a no-op). The stinger plays normally; Music bus volume is unchanged.
    - **Music duck guard:** Stores the Music bus volume at the moment `play_stinger()` is called and restores exactly that value — not a fixed offset — so the duck is correct even if the user has adjusted Music volume.
    - When the stinger's `finished` signal fires (or `stop_stinger()` is called), the Music bus returns to the stored pre-duck level over `event.restore_duration_sec`.
    - Before connecting `_stinger_player.finished`, explicitly disconnect any prior connection to prevent double-restore when a stinger is interrupted:
      ```gdscript
      if _stinger_player.finished.is_connected(_on_stinger_finished):
          _stinger_player.finished.disconnect(_on_stinger_finished)
      _stinger_player.finished.connect(_on_stinger_finished, Object.CONNECT_ONE_SHOT)
      ```

    **Call sites (provisional — confirmed when dependent GDDs are authored):**
    - `sfx_stinger_memory_fragment` — intermediate memory reveal (duck −10 dB, restore 1.5s; `stinger_priority = NARRATIVE`)
    - `sfx_stinger_memory_first` — first memory recovered (duck −10 dB, restore 1.5s; `stinger_priority = NARRATIVE`) — distinct asset, same parameters as `memory_fragment` by default; audio-director authors a unique composition
    - `sfx_stinger_memory_final` — final memory (plot twist moment) (duck −14 dB, restore 2.0s; `stinger_priority = NARRATIVE`)
    - `sfx_stinger_memo_peak` — Memo dialogue peak moments (duck −10 dB, restore 1.5s; `stinger_priority = NARRATIVE`)
    - `sfx_stinger_boss_spawn` — boss arrival on `combat_started(is_boss: true)` (duck −6 dB, restore 0.5s; `stinger_priority = COMBAT`) — HIGH eviction priority
    - `sfx_stinger_boss_kill` — boss defeated (provisional; duck −6 dB, restore 0.5s; `stinger_priority = COMBAT`) — call site confirmed when Boss Encounter GDD #11 is authored
    - `sfx_stinger_run_start` — ambient sting on `run_started` (duck 0 dB — no duck; `stinger_priority = COMBAT`) — provisional, audio-director evaluates during content production

    Stinger events use the naming convention `"sfx_stinger_[identifier]"`. These are registered in `AudioEventRegistry` alongside other SFX events.

---

### SFX Event Priority Assignment Table

The following table defines canonical priority tiers for event categories. All dependent systems (Game Feel / Juice, Spell Casting & Effects, Health & Damage, Enemy AI, UI) must register their events with priorities matching this table. The audio-director may adjust individual entries, but the table defines the defaults.

| Priority | Tier | Event Categories |
|----------|------|-----------------|
| `2` = **HIGH** | Never evicted under normal conditions | The duo death sound, boss spawn stinger, status effect applied (Freeze / Burn), critical damage received by the duo, wave-end sound |
| `1` = **NORMAL** | Evicted only when no LOW slots remain | Prana cast sounds (`sfx_prana_cast_*`), enemy hit confirmation, enemy attack telegraph |
| `0` = **LOW** | Evicted first | Footstep sounds, minor ambient feedback (item pickup, Prana collect), non-critical environmental sounds |

**Prana cast rationale:** Prana casts are NORMAL (not HIGH) because up to 9 Prana types may fire simultaneously on a full 3×3 combo, and HIGH-priority slots cannot be evicted — assigning them HIGH would exhaust the non-eviction budget. Prana casts still take priority over environmental noise (LOW) while yielding to critical player-state feedback (HIGH).

**Wave-end rationale:** Wave-end sound marks the "player exhales" beat (COMBAT→PREPARATION transition). The documented worst-case pool scenario — full 3×3 combo + Cluster swarm ≈ 20 simultaneous events — fires precisely when a wave ends. At NORMAL priority, wave-end would be evicted under peak conditions, losing the one moment where audio must confirm the transition. As a single, non-recurring event, assigning HIGH costs one slot in the non-eviction budget while protecting the beat's reliability.

---

### States and Transitions

| From | To | Trigger | Transition |
|------|----|---------|------------|
| *(startup)* | `MAIN_MENU` | Game launch (initial state) | Instant |
| `MAIN_MENU` | `PREPARATION` | `run_started` signal | Crossfade (`CROSSFADE_MENU_TO_PREPARATION`) |
| `PREPARATION` | `COMBAT` | `combat_started` signal | Crossfade (`CROSSFADE_TO_COMBAT`) |
| `COMBAT` | `PREPARATION` | `preparation_started` signal | Crossfade (`CROSSFADE_COMBAT_TO_PREPARATION`) |
| `PREPARATION` | `DYING` | `death_started` signal | Fast fade to silence (`CROSSFADE_TO_DYING`) |
| `COMBAT` | `DYING` | `death_started` signal | Fast fade to silence (`CROSSFADE_TO_DYING`) |
| `DYING` | `END_DEFEAT` | `run_ended(win: false)` signal | Crossfade from silence (`CROSSFADE_TO_END`) |
| `PREPARATION` | `END_VICTORY` | `run_ended(win: true)` signal | Crossfade (`CROSSFADE_TO_END`) |
| `PREPARATION` | `END_DEFEAT` | `run_ended(win: false)` signal | Crossfade (`CROSSFADE_TO_END`) |
| `COMBAT` | `END_VICTORY` | `run_ended(win: true)` signal | Crossfade (`CROSSFADE_TO_END`) |
| `COMBAT` | `END_DEFEAT` | `run_ended(win: false)` signal | Crossfade (`CROSSFADE_TO_END`) — *defensive fallback only; by Game State contract, the duo's death always emits `death_started` before `run_ended(win: false)`, so this path must not be reached during normal play* |
| `END_VICTORY` | `MAIN_MENU` | END_VICTORY cue `finished` signal (auto) | Crossfade (`CROSSFADE_TO_MAIN_MENU`) |
| `END_DEFEAT` | `MAIN_MENU` | END_DEFEAT cue `finished` signal (auto) | Crossfade (`CROSSFADE_TO_MAIN_MENU`) |

`MAIN_MENU` loops indefinitely. `PREPARATION` loops. `COMBAT` loops. `DYING` is silent (no cue — intentional silence). `END_VICTORY` and `END_DEFEAT` play once to completion — they are the only non-looping states.

**END cue format constraint (non-negotiable):** `END_VICTORY` and `END_DEFEAT` `AudioStream` resources must be delivered as non-looping files — loop must be disabled at the asset level. The auto-transition to `MAIN_MENU` depends on the `finished` signal, which Godot's `AudioStreamPlayer` does not emit for looping streams. A looping END cue will silently prevent the auto-transition from ever firing.

Audio System never transitions music spontaneously (except the END auto-transition and the DYING silence) — all other transitions are triggered by a signal from Game State & Scene Flow.

---

### Interactions with Other Systems

| System | Interaction | Direction |
|--------|-------------|-----------|
| **Game State & Scene Flow** | Emits `run_started`, `combat_started(is_boss)`, `preparation_started`, `death_started`, `run_ended(win)` → Audio System listens and transitions music state. **Note:** Audio System does NOT connect to `wave_ended` — `preparation_started` is the authoritative trigger for COMBAT→PREPARATION. | Game State → Audio System |
| **Game Feel / Juice** | Calls `AudioSystem.play_event()` for hit feedback, Prana cast sounds, dash cues | Game Feel → Audio System |
| **Spell Casting & Effects** | Calls `AudioSystem.play_event()` for Prana type-specific cast audio; constructs dynamic keys via `StringName("sfx_prana_cast_" + prana_type_name)` | Spell Casting → Audio System |
| **Health & Damage** | Calls `AudioSystem.play_event()` for damage received, death feedback | Health & Damage → Audio System |
| **Enemy AI** | Calls `AudioSystem.play_event()` for enemy attack telegraphs (minimal at MVP) | Enemy AI → Audio System |
| **Save / Load** | Reads volume getters on save; calls volume setters on load (all 5 buses) | Save/Load ↔ Audio System |
| **UI systems** | Call `AudioSystem.play_event()` for menu navigation sounds; registry entries set `bus = &"UI"` — routed to dedicated UI player (PROCESS_MODE_ALWAYS, plays during pause) | UI → Audio System |
| **Level/room systems** | Call `AudioSystem.play_ambient()` / `stop_ambient()` for environmental texture | Room → Audio System |
| **Lore Fragments / Memo (#21)** | Calls `AudioSystem.play_stinger("sfx_stinger_memory_fragment")` on memory fragment reveal and Memo narrative peak moments; Audio System ducks Music bus −6 dB for stinger duration | Lore Fragments → Audio System |
| **Game Feel / Juice (#30)** | Calls `AudioSystem.play_stinger("sfx_stinger_boss_spawn")` on `combat_started(is_boss: true)` to mark the boss arrival with a one-shot musical sting | Game Feel → Audio System |

Audio System **never emits signals** to other systems. It is a passive service — all dependencies are inward. **Corollary for visual feedback:** Systems that display visual effects synchronized to audio (e.g., Combat HUD hit flash) must independently connect to the same upstream signals as Audio System. Audio System does not emit a "sound played" confirmation event.

## Formulas

> **Note:** Audio System has no gameplay-balance formulas. The mathematical content here is the crossfade volume transition and the decibel range used for volume controls.

### Formula 1: Crossfade Volume Transition

The crossfade uses **simultaneous** fades: both tweens run at the same time over the same `fade_duration`. No silence gap occurs between states.

**Fade out (outgoing cue):**
`volume_db_out(t) = lerp(outgoing_player.volume_db_at_transition_start, -80.0, t / fade_duration)`

**Fade in (incoming cue):**
`volume_db_in(t) = lerp(-80.0, 0.0, t / fade_duration)`

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `t` | float (seconds) | 0.0 – `fade_duration` | Elapsed time within the fade |
| `fade_duration` | float (seconds) | 0.0 – state-dependent (see Tuning Knobs) | Duration for this transition direction |
| `outgoing_player.volume_db_at_transition_start` | float (dB) | −80.0 – 0.0 | The outgoing cue's actual volume when the transition begins (avoids loudness spikes when user volume ≠ 0 dB) |

**Output range:** −80.0 dB (silence) to 0.0 dB (full volume)

**Note on target volume:** The incoming cue's target of 0.0 dB refers to the `AudioStreamPlayer` node's `volume_db` property — not master output level. Actual perceived level is the sum of this value and the Music bus volume (set via `set_music_volume()`). Bus volume is independent of crossfade logic.

**Guard:** If `fade_duration <= 0.0`, skip the tween entirely: set `outgoing_player.volume_db = -80.0` and `incoming_player.volume_db = 0.0` immediately. This prevents division-by-zero and enables instant-cut configurations.

**Example — simultaneous crossfade, t=0.5s with fade_duration=1.0s, outgoing at −6 dB:**
- `volume_db_out = lerp(-6.0, -80.0, 0.5) = -43.0 dB`
- `volume_db_in = lerp(-80.0, 0.0, 0.5) = -40.0 dB`

**Note:** −80 dB is Godot's effective silence floor for `AudioStreamPlayer.volume_db`. The Tween built-in handles the interpolation — this formula describes the intent, not a custom calculation.

**~3 dB midpoint dip (applies to all simultaneous linear crossfades except `CROSSFADE_TO_END`):** A simultaneous linear crossfade produces a perceivable loudness dip at the midpoint (t = fade_duration / 2). At midpoint, outgoing is at ~50% of its start level and incoming is at 50% of target — the combined perceived amplitude briefly drops ~3 dB below the nominal level. This is accepted behavior for all short crossfades in this system. **Exception: `CROSSFADE_DURATION_TO_END` (2.0s)** — the 2.0s duration makes the midpoint dip physically perceptible and cannot be masked by composer technique (the incoming cue starts at −80 dB, so a "strong entry attack" is inaudible until the fade is nearly complete). For this transition only, use `Tween.TRANS_SINE` (constant-power sinusoidal curve), which maintains constant perceived energy through the midpoint: `_active_tween.set_trans(Tween.TRANS_SINE)`. All other crossfade tweens use the default linear curve.

---

### Formula 2: Volume dB Range (User-Facing)

User volume settings are stored and applied in decibels. The UI exposes a 0–100 slider that maps to a dB range:

`volume_db = lerp(-80.0, 0.0, float(slider_value) / 100.0)`

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `slider_value` | int | 0 – 100 | User-facing volume setting (0 = mute, 100 = max) |
| `volume_db` | float (dB) | −80.0 – 0.0 | AudioServer bus volume |

**Output range:** −80.0 dB (slider at 0) to 0.0 dB (slider at 100)

**Implementation note:** The divisor must be `100.0` (float literal), not `100` (int literal). In GDScript, `int / int` performs integer division, returning 0 for all `slider_value` 0–99 and 1 only at 100, collapsing the entire slider range to silence except at max.

**Mute note:** Slider at 0 sets the bus to −80.0 dB (near-silent, ~0.01% amplitude), not technical silence. If true silence is required (e.g., a Mute toggle), call `AudioServer.set_bus_mute()` separately.

**Known limitation (post-MVP):** Linear dB mapping produces a perceptual dead zone at the low end. A `pow`-based perceptual curve is deferred post-MVP as a UX quality improvement.

## Edge Cases

**1. `play_event()` called with unregistered event key**

Logs `push_error()` and returns without playing. Callers must not depend on audio playing for gameplay logic.

**2. All SFX pool slots occupied**

Evict by priority tier: interrupt the oldest LOW-priority slot first; if none, oldest NORMAL-priority. Never interrupt HIGH-priority unless only HIGH slots remain. If all slots are HIGH, evict the oldest HIGH. "Oldest" = the slot with the **smallest stored `Time.get_ticks_msec()` timestamp value** (played least recently — equivalently, the slot that has been playing the longest, since elapsed time = `current_ticks − stored_timestamp`). Evict by finding `min(stored_timestamp)` across eligible slots. The interrupted sound is dropped without fadeout.

**3. Music state transition triggered while a crossfade is already in progress**

Kill the active tween before creating the new one:
```gdscript
if _active_tween != null:
    _active_tween.kill()
```
Begin the new transition from the outgoing cue's current `volume_db` (not from 0.0 dB). The incoming cue always starts from −80.0 dB regardless of prior state. On the very first music transition, `_active_tween` is null — the null guard prevents a crash.

**4. `run_ended` fires mid-crossfade into `PREPARATION`**

Edge Case 3 handles this — the tween cancels and the END transition begins from the current volume values.

**5. Music cue file missing from `AudioEventRegistry`**

If a state's mapped cue is null (audio-director has not assigned a stream), the music manager logs `push_error()` and **remains in the current state** — the state transition is blocked. Music silence is preferable to an unknown-state crash.

**6. `set_*_volume()` called with out-of-range value**

Clamped at the setter: below −80.0 → set to −80.0; above 0.0 → set to 0.0.

**7. Audio bus layout not configured in Project Settings**

`AudioServer.get_bus_index()` returns −1 for missing buses. The system detects a −1 return and calls `push_error()` with a human-readable message. All `play_event()` calls continue to function silently (no audio) rather than crashing.

**8. `fade_duration = 0.0`**

If any crossfade duration constant is set to 0.0, skip the tween and perform an instant cut (set volumes directly). This makes `fade_duration = 0.0` a valid "instant cut" configuration useful for testing or specific transitions.

**9. `run_started` fires before `END_VICTORY` / `END_DEFEAT` cue finishes**

The END cue continues playing to completion. The `run_started` signal is not acted upon until the END cue's `finished` signal fires and the auto-transition to `MAIN_MENU` completes. A subsequent `run_started` from the next run will then trigger `MAIN_MENU → PREPARATION` normally.

**10. `play_event()` called during PAUSED state**

SFX pool nodes are `PROCESS_MODE_PAUSABLE` — calls to SFX events during pause are silently dropped. Sounds do not play and are not queued for playback on unpause. UI events (registered with `bus = &"UI"`) route to the dedicated PROCESS_MODE_ALWAYS UI player and play normally during pause. This is the mechanism for Pause Menu audio feedback.

**11. `AudioEventRegistry` .tres file not found at startup**

`load()` returns null if the path is incorrect or the file is missing. Audio System checks for null immediately after loading:
```gdscript
_registry = load("res://assets/data/audio_event_registry.tres")
if _registry == null:
    push_error("AudioSystem: AudioEventRegistry not found. All play_event() calls will be no-ops.")
```
With a null registry, every `play_event()` call hits the null-check path and returns without playing. The game continues without audio rather than crashing.

**12. `play_ambient()` called while an ambient crossfade is already in progress**



Kill the active ambient tween before starting the new one:
```gdscript
if _active_ambient_tween != null:
    _active_ambient_tween.kill()
```
Swap the active/inactive ambient player roles and begin the new crossfade from current volume values.

**13. `play_event()` called on an event registered with `bus = &"AMB"`**

Direct `play_event()` calls to the AMB bus are not supported — callers must use `play_ambient()`. If a caller registers an event with `bus = &"AMB"` and calls `play_event()` on it, Audio System logs `push_error()` and returns without playing. No SFX pool slot, UI player, or ambient player changes state.

**14. `AudioEventData.priority` value out of range**

The valid priority values are `0` (LOW), `1` (NORMAL), `2` (HIGH). If an `AudioEventData` resource is authored with a `priority` value outside `{0, 1, 2}` (e.g., `priority = 5`), Audio System detects this at registration time and: logs `push_error()` with the offending event name and value, clamps the priority to `1` (NORMAL) as the safest default, and registers the event with the clamped value. The audio-director must correct the registry resource to resolve the error. An out-of-range priority is never silently accepted.

**15. `play_stinger()` called while a stinger is already playing**

Priority policy applies first (see Core Rule 12). If the new stinger is blocked by priority (COMBAT trying to interrupt NARRATIVE), it is silently discarded — no duck, no stream change.

If the new stinger is allowed to proceed: the prior `finished` connection is explicitly disconnected before the new one is connected (see Core Rule 12 connection guard). Then the new stinger interrupts the in-progress one immediately (no fadeout). The Music bus duck tween is restarted from the current ducked volume using the new event's `duck_depth_db`. The Music bus restore on completion uses the new event's `restore_duration_sec` and the **original `_music_pre_stinger_volume`** captured at the first `play_stinger()` call — this value is **retained, not re-captured**. Re-capturing the current Music bus volume at interrupt time would read the already-ducked value, causing the restore target to drift permanently lower with each subsequent interrupt (compounding −6 dB per interrupt). The original pre-stinger baseline is always the correct restore target.

## Dependencies

### Systems That Depend on Audio System

| System | What it needs | Bidirectional contract |
|--------|---------------|----------------------|
| **Game Feel / Juice** | `play_event()` for all feedback audio | Game Feel must declare Audio System as a dependency |
| **Spell Casting & Effects** | `play_event()` for cast and impact audio; constructs dynamic keys via `StringName("sfx_prana_cast_" + prana_type_name)` | Spell Casting must declare Audio System as a dependency |
| **Health & Damage** | `play_event()` for damage and death audio | Health & Damage must declare Audio System as a dependency |
| **Enemy AI** | `play_event()` for enemy attack audio (MVP: minimal) | Enemy AI must declare Audio System as a dependency |
| **UI systems** (Main Menu, Combat HUD, Pause Menu) | `play_event()` for navigation and feedback (registry entries set `bus = &"UI"` — routed to dedicated PROCESS_MODE_ALWAYS player) | All UI GDDs must declare Audio System as a dependency |
| **Save / Load** | Volume getters/setters for all 5 buses (settings persistence) | Save / Load must declare Audio System as a dependency |
| **Level/room systems** | `play_ambient()` / `stop_ambient()` for environmental texture | Room GDDs must declare Audio System as a dependency |

### Audio System's Own Dependencies

Audio System has **no runtime dependencies**. It is Foundation layer — it initializes from static configuration data (`AudioEventRegistry` resource) and listens to signals it connects to at startup.

**Signal dependency on Game State & Scene Flow**: Audio System listens to signals emitted by Game State & Scene Flow: `run_started`, `combat_started(is_boss: bool)`, `preparation_started`, `death_started`, `run_ended(win: bool)`. Audio System does **not** connect to `wave_ended` — `preparation_started` is the sole authoritative trigger for COMBAT→PREPARATION music transitions. This is a one-way signal connection — Audio System connects to Game State at startup; Game State does not import Audio System.

**AudioEventRegistry resource schema**: `AudioEventRegistry` is a custom GDScript resource class:
```gdscript
class_name AudioEventRegistry
extends Resource

@export var events: Dictionary[StringName, AudioEventData]
```
`@export var events: Dictionary[StringName, AudioEventData]` (typed) enforces key/value types in the Godot editor inspector, preventing accidental wrong-type entries during content authoring.

The audio-director populates `events` in the Godot editor via the resource inspector, authoring one `AudioEventData` entry per event key. The `.tres` file is saved at `res://assets/data/audio_event_registry.tres`.

**Startup validation (validate-on-register):** After loading, Audio System iterates all entries and validates each value:
```gdscript
_registry = load("res://assets/data/audio_event_registry.tres")
if _registry == null:
    push_error("AudioSystem: AudioEventRegistry not found.")
    return
for key: StringName in _registry.events:
    if not _registry.events[key] is AudioEventData:
        push_error("AudioSystem: Registry entry '%s' is not an AudioEventData — skipped." % key)
        continue
    var entry := _registry.events[key] as AudioEventData
    if entry.priority not in [0, 1, 2]:
        push_error("AudioSystem: Registry entry '%s' has invalid priority %d — clamped to NORMAL." % [key, entry.priority])
        entry.priority = 1
    if entry.stinger_priority not in [0, 1]:
        push_error("AudioSystem: Registry entry '%s' has invalid stinger_priority %d — clamped to COMBAT." % [key, entry.stinger_priority])
        entry.stinger_priority = 0
    _validated_events[key] = entry
```
Audio System routes all `play_event()` / `play_stinger()` calls through `_validated_events` (not the raw loaded dictionary). Type errors surface at startup in both debug and release builds, not silently at call time in production.

*Note: Game State & Scene Flow does not need to declare Audio System as a dependency — the connection is one-way (signal listener). However, Game State & Scene Flow's GDD must confirm that `death_started` is an emitted signal — if not present, it must be added.*

**Prana Data**: Prana Data GDD (approved) defines `audio_signature: AudioStream` per Prana type. Spell Casting & Effects is responsible for translating Prana type identifiers to event key strings before calling `play_event()`. Audio System does not import Prana Data.

## Tuning Knobs

### Crossfade Durations

| Knob | Default | Safe Range | What it affects | What breaks if wrong |
|------|---------|------------|-----------------|----------------------|
| `CROSSFADE_DURATION_TO_COMBAT` | 0.1s | 0.0 – 0.5s | PREPARATION → COMBAT | Intent: "punches in fast" — combat music cuts in sharply. Values above 0.2s soften the punch; 0.0s is a valid hard cut (handled by the `fade_duration <= 0.0` guard). |
| `CROSSFADE_DURATION_MENU_TO_PREPARATION` | 1.0s | 0.0 – 3.0s | MAIN_MENU → PREPARATION at run start | Too long: music lags behind run start; too short: jarring cut |
| `CROSSFADE_DURATION_COMBAT_TO_PREPARATION` | 0.8s | 0.0 – 2.0s | COMBAT → PREPARATION at wave end | Intent: "clean exhale" — gives the listener time to register combat tension releasing before the Preparation texture settles. Too short: sounds like a cut, not an exhale; too long: drags the transition. The ~3 dB midpoint dip applies here as with all simultaneous fades (see Formula 1). |
| `CROSSFADE_DURATION_TO_END` | 2.0s | 0.5 – 5.0s | Any → END_VICTORY or END_DEFEAT | Too short: lacks emotional gravity; too long: player waits through a slow fade |
| `CROSSFADE_DURATION_TO_MAIN_MENU` | 0.5s | 0.0 – 2.0s | END auto-transition back to MAIN_MENU music | Too long: dead air after end cue completes; too short: abrupt |
| `CROSSFADE_DURATION_TO_DYING` | 0.1s | 0.0 – 0.3s | COMBAT → DYING (death animation silence) | Too long: combat music lingers through death animation; too short: abrupt mute |
| `CROSSFADE_DURATION_AMBIENT_OUT` | 0.5s | 0.0 – 2.0s | `stop_ambient()` fade-out duration | Too long: ambient lingers past room transition; too short: abrupt cut. Distinct from `play_ambient()` crossfade (which uses two simultaneous tweens); `stop_ambient()` fades only the active player. |

### Pool and Mix

| Knob | Default | Safe Range | What it affects | What breaks if wrong |
|------|---------|------------|-----------------|----------------------|
| `SFX_POOL_SIZE` | 24 | 12 – 24 | Maximum concurrent SFX | Below 20: sounds may drop during peak-of-peak scenario (full 3×3 combo + Cluster swarm = ~20 events); above 24: unnecessary node overhead on PC. Safe range minimum raised from 8 to 12 to reflect worst-case analysis. |
| `DYING_MIN_HOLD_SEC` | 1.5s | 0.5 – 3.0s | Minimum silence duration in DYING state | Too short: "moment breathes" claim is lost — silence is imperceptible; too long: player waits before defeat stinger. **Must be validated against the duo death animation total duration (crumple + bloom + dissolve) when that animation is authored — defeat stinger should fire after dissolve completes, not during it.** |
| Default master volume | 0.0 dB | −80.0 – 0.0 dB | Starting volume on first launch (before saved settings) | Too low: players think game has no audio; too high: ear shock on first launch |
| Default music volume | −6.0 dB | −80.0 – **−3.0 dB** | Starting music mix level | Safe range maximum is −3.0 dB (not 0.0 dB) — this restriction makes the "Prana SFX must remain audible over music" constraint architecturally enforceable. At Music ≤ −3.0 dB and SFX = 0.0 dB, Prana SFX always has at least 3 dB of headroom above music. The `set_music_volume()` setter must clamp the upper bound to −3.0 dB; document this in the setter's in-code comment. |
| Default SFX volume | 0.0 dB | −80.0 – 0.0 dB | Starting SFX mix level | SFX at 0 dB is the reference — tune music and ambient relative to this |
| Default UI volume | −3.0 dB | −80.0 – 0.0 dB | Starting UI sound level | Should sit between SFX and music in perceived loudness |
| Default AMB volume | −12.0 dB | **−80.0 – −10.0 dB** | Starting ambient layer level | Safe range maximum is −10.0 dB (not 0.0 dB) — this restriction architecturally enforces the "world breathes softly" half of the sonic identity directive. At AMB ≤ −10.0 dB, ambient remains textural and below Prana SFX in all supported configurations. The `set_amb_volume()` setter must clamp the upper bound to −10.0 dB. |

### Structural Constraints (not tuning knobs)

- **Bus count**: 4 buses + Master. Adding a 5th (e.g., Voice) requires a GDD revision and Project Settings update.
- **Volume range**: Always −80.0 to 0.0 dB. Setting buses above 0 dB introduces distortion and is not supported. **Music bus upper bound: −3.0 dB** (enforced by `set_music_volume()` clamping — see Tuning Knobs). **AMB bus upper bound: −10.0 dB** (enforced by `set_amb_volume()` clamping — see Tuning Knobs).
- **Music state count**: 6 states at MVP. Adding a BOSS state at Vertical Slice requires: GDD revision, new cue from audio-director, new signal payload handling for `combat_started(is_boss: true)`.
- **Managed players total**: 2 Music (A/B) + 2 Ambient (A/B) + 1 UI + 1 Stinger + 24 SFX pool = 30 nodes. The stinger player added in Core Rule 12 is counted separately from the SFX pool.

## Visual/Audio Requirements

Audio System is the audio framework — it has no visual output of its own. Audio content requirements belong to the audio-director and sound-designer:

- **Music cues required at MVP**: 5 cues (Main Menu, Preparation, Combat, Victory, Defeat). `DYING` state has no cue — it is intentional silence. Audio-director defines composition, tempo, and mix targets.
  - **Structural guidance for composers:** Preparation cue should be a short loop (target 8–16 bars) with minimal melodic progression — it functions as atmospheric tension, not a theme. A shorter loop reduces the chance of a mid-phrase cut when the player locks their grid. Combat cue should have a clear downbeat entry point compatible with the 0.5s crossfade from Preparation.
  - **END cue format constraint (non-negotiable):** END_VICTORY and END_DEFEAT must be delivered as non-looping `AudioStream` files. Loop must be disabled at the asset level. The auto-transition to `MAIN_MENU` depends on the `finished` signal — Godot does not emit `finished` for looping streams. A looping END cue will silently prevent the music flow from ever recovering.
- **Ambient event catalog**: The audio-director and sound-designer define the full ambient catalog. Each event must have a canonical string key following `"amb_[location]_[descriptor]"` convention (e.g., `"amb_arena_hum"`, `"amb_dungeon_electric"`). These are registered in `AudioEventRegistry` with `bus = &"AMB"`.
- **SFX event catalog**: Naming convention: `"sfx_[category]_[identifier]"` for SFX bus events (e.g., `"sfx_prana_cast_ashfire"`, `"sfx_enemy_hit"`), `"ui_[identifier]"` for UI bus events (e.g., `"ui_menu_confirm"`). The `bus` field in `AudioEventData` determines routing — the naming prefix is a convention for readability only.
- **Asset delivery standard**: All audio assets must be delivered at a target integrated loudness of **−18 LUFS** (true peak −1 dBTP). Measurement guidance by category: music and ambient tracks (long-form, looping) are measured at integrated LUFS; short transient SFX (Prana casts, hit sounds) are measured at true peak dBTP rather than integrated LUFS, as integrated measurement is not meaningful for sub-2-second events. Bus volume offsets defined in Tuning Knobs assume this delivery standard. Assets exceeding −1 dBTP true peak must be redelivered before integration. **Prana cast and hit SFX minimum floor: −6 dBTP true peak.** Assets below this floor are too quiet to cut through music at any supported Music bus volume setting and must be redelivered.
- **Sonic identity and mix contract**: *"The world breathes softly; magic screams."* AMB and Preparation cues should be understated and textural; Prana SFX should be loud, sharp, and elemental. Prana SFX (registered as NORMAL priority) must remain audible over music at all Music volume settings within the tuning knob safe range. **This is architecturally enforced two ways:** (1) the Music bus safe range maximum is −3.0 dB (see Tuning Knobs), and the SFX bus defaults to 0.0 dB, guaranteeing Prana SFX always has at least 3 dB of headroom over music within the supported range; (2) the AMB bus safe range maximum is −10.0 dB, keeping ambient below Prana SFX in all supported configurations. Prana SFX assets must additionally be mixed to a level that cuts through at −18 LUFS delivery standard.

## UI Requirements

Audio System has no player-facing UI of its own. Volume controls are exposed via the `set_*_volume()` / `get_*_volume()` interface.

**📌 UX Flag — Audio System**: Volume control UI (Master, Music, SFX, AMB, UI sliders) is a UI requirement owned by the Pause Menu / Settings GDDs. When those GDDs are authored, they should specify slider ranges mapping to Formula 2 (0–100 slider → −80–0 dB) and default display values from the Tuning Knobs section. Note the `float(slider_value) / 100.0` divisor must use a float literal to avoid integer division.

**Slider debounce requirement**: The dedicated UI player is non-queued and non-rate-limited — each `play_event()` call interrupts the previous UI sound. Volume slider drag fires `play_event()` at ~30–60 events/sec during continuous drag, producing audible stutter or silence via rapid-fire interrupts. The Settings/Pause Menu GDD **must** debounce UI audio events at the call site: fire `play_event("ui_slider_feedback")` at most once per 16–33 ms during drag (i.e., at the end of a drag gesture, not on every intermediate value change). This debounce is a call-site responsibility — Audio System does not internally rate-limit `play_event()` calls.

## Acceptance Criteria

> **Test teardown requirement (all integration tests):** `AudioServer` is a global singleton. Every integration test must include `after_each` teardown:
> 1. Reset all bus volumes to their documented tuning knob defaults via `AudioSystem.set_*_volume()` — Music: −6.0 dB, SFX: 0.0 dB, UI: −3.0 dB, AMB: −12.0 dB, Master: 0.0 dB. Do not reset to 0.0 dB across the board; that would leave Music above its −3.0 dB ceiling for subsequent tests.
> 2. Stop all SFX pool players and reset all pool slot `stream` to null.
> 3. Stop ambient players (A and B) and reset their `stream` to null.
> 4. Stop the stinger player and reset its `stream` to null.
> 5. Reset `music_state` to `MusicState.MAIN_MENU`.
> 6. Kill any active tweens (`_active_tween`, `_active_ambient_tween`, `_active_stinger_tween`).
> 7. Clear the `_validated_events` dictionary of any test-only dummy entries registered during the test. Failure to clear the registry causes dummy events from one test to be found by `play_event()` in subsequent tests.
>
> Without full teardown, GUT test execution order determines results.

### Bus Architecture

**AC-AS-01** — On startup, Audio System verifies exactly 5 audio buses exist with canonical names: `Master`, `Music`, `SFX`, `UI`, `AMB`. Unit test calls `AudioServer.get_bus_index()` for each name and asserts none return −1, and `AudioServer.get_bus_count() == 5`.

**AC-AS-02** — The `Music`, `SFX`, `UI`, and `AMB` buses have `Master` as their parent. Unit test verifies `AudioServer.get_bus_send(bus_idx)` for each of the four buses returns `&"Master"`. Also verifies `AudioServer.get_bus_send(master_idx) == &""`.

### SFX Dispatch

**AC-AS-03** — On startup, Audio System pre-creates exactly `SFX_POOL_SIZE` (default 24) `AudioStreamPlayer` nodes in the SFX pool. Unit test asserts pool size equals the `SFX_POOL_SIZE` constant. Also asserts: (a) each slot is an `AudioStreamPlayer`; (b) each slot has `process_mode == PROCESS_MODE_PAUSABLE`; (c) all 24 slots have `_timestamps[i] == 0` (initial timestamp value).

**AC-AS-04** — Calling `play_event("registered_sfx_event")` with a free pool slot assigns it correctly. Integration test registers a dummy SFX event (`bus = &"SFX"`), calls `play_event()`, and immediately (no frame advance) asserts: (a) exactly one pool slot has `stream == registered dummy stream` (slot was selected and assigned); (b) that slot's `bus == &"SFX"`; (c) all other pool slots have unchanged `stream`. **Note:** `playing == true` is not asserted — `AudioStreamPlayer.playing` is driven by the audio server thread which does not process during headless GUT execution; stream assignment is the reliable synchronous assertion for slot selection.

**AC-AS-05** — Calling `play_event("unregistered_event")` produces a `push_error()` log entry and does not crash or alter pool state. Unit test snapshots all pool slots' `playing` and `stream` values before the call, then asserts no slot changed state after the call.

**AC-AS-06** — Pool eviction respects the priority contract. Integration test uses a test-accessible `_set_slot_timestamp(idx, ticks: int)` method to set deterministic timestamps. *Test A (LOW eviction):* fill all 24 slots with LOW-priority events; use `_set_slot_timestamp()` to set slot 2's timestamp to 100 (oldest — smallest value) and all others to 5000+. Call `play_event()` once more. Assert slot 2 specifically was evicted (its stream reassigned to the new event). *Test B (NORMAL eviction):* repeat with all 24 NORMAL-priority slots; assert the designated oldest NORMAL slot (by `_set_slot_timestamp`) was evicted. *Test C (HIGH protection):* fill 23 slots with LOW-priority, 1 slot (slot 5) with HIGH-priority; set slot 5's timestamp to 0 (it would be "oldest" if priority allowed). Call `play_event()` — assert slot 5 is NOT evicted (HIGH protected); assert a LOW slot is evicted instead. *Test D (all HIGH):* fill all 24 slots with HIGH-priority; designate slot 3 as oldest via `_set_slot_timestamp(3, 0)`. Call `play_event()` — assert slot 3 was evicted (oldest HIGH when all slots are HIGH).

**AC-AS-07** — A registered UI bus event routes to the dedicated UI player, not the SFX pool. Integration test calls `play_event()` with an event whose registry entry specifies `bus = &"UI"`. Asserts: (a) zero SFX pool slots changed `stream` state; (b) the dedicated UI player's `stream == registered dummy stream` (assigned correctly); (c) the dedicated UI player has `process_mode == PROCESS_MODE_ALWAYS`.

### Music State Machine

**AC-AS-08** — Audio System initializes in `MAIN_MENU` state. Unit test reads the initial music state and asserts `music_state == MusicState.MAIN_MENU`.

**AC-AS-09** — `run_started` signal transitions state from `MAIN_MENU` to `PREPARATION`. Integration test: assert initial state is `MAIN_MENU`, call `AudioSystem._on_run_started()` directly, assert `music_state == MusicState.PREPARATION` immediately after call.

**AC-AS-10** — `combat_started` signal transitions state from `PREPARATION` to `COMBAT`. Integration test: set state to `PREPARATION`, call `AudioSystem._on_combat_started(false)` directly, assert `music_state == MusicState.COMBAT`.

**AC-AS-11** — Only `preparation_started` transitions music state from `COMBAT` to `PREPARATION`. `wave_ended` is NOT connected to music state changes. Integration test A: set state to `COMBAT`, call `AudioSystem._on_wave_ended()` directly, assert `music_state` remains `MusicState.COMBAT` (wave_ended must not change music state). Integration test B: set state to `COMBAT`, call `AudioSystem._on_preparation_started()`, assert `music_state == MusicState.PREPARATION`.

**AC-AS-33** — `wave_ended` followed by `preparation_started` produces exactly one COMBAT→PREPARATION crossfade tween (not two). Integration test: enter `COMBAT`, capture initial `_active_tween` reference (may be null). Call `AudioSystem._on_wave_ended()` — assert `music_state` remains `MusicState.COMBAT` (no tween initiated by wave_ended). Then call `AudioSystem._on_preparation_started()` — assert: (a) `music_state == MusicState.PREPARATION`; (b) `_active_tween` is non-null (exactly one tween was created by preparation_started); (c) `_active_tween` is a different object than the initial reference. This confirms the double-trigger bug is closed: wave_ended is not connected to music state.

**AC-AS-12** — `run_ended(win: false)` transitions to `END_DEFEAT` from both `PREPARATION` and `COMBAT`. Integration test: (a) set state to `PREPARATION`, call `AudioSystem._on_run_ended(false)`, assert `MusicState.END_DEFEAT`; (b) set state to `COMBAT`, call `AudioSystem._on_run_ended(false)`, assert `MusicState.END_DEFEAT`.

**AC-AS-13** — `run_ended(win: true)` transitions to `END_VICTORY` from both `PREPARATION` and `COMBAT`. Integration test mirrors AC-AS-12 with `true` and `MusicState.END_VICTORY`.

**AC-AS-14** — A second state transition during an active crossfade cancels the prior tween and creates a new one. Integration test: initiate a PREPARATION→COMBAT crossfade (call `AudioSystem._on_combat_started(false)`); capture the `_active_tween` reference as `tween_1`. Then immediately call `AudioSystem._on_run_ended(false)` (run ends during crossfade). Assert: (a) `_active_tween` is a different object than `tween_1` (new tween was created); (b) `not tween_1.is_valid()` (prior tween was killed — `Tween.is_valid()` returns `false` after `.kill()`; **do not** use `is_running()` which does not exist in Godot 4); (c) `music_state == MusicState.END_DEFEAT`. **Note:** Mid-fade volume values are not asserted — `Tween.custom_step()` does not exist in Godot 4. Volume transition correctness is covered by the pure function test in AC-AS-16.

**AC-AS-15** — `END_VICTORY` and `END_DEFEAT` states are non-interruptible by game signals. Integration test: enter `END_DEFEAT`, then call `_on_run_started()`, `_on_combat_started(false)`, `_on_wave_ended()`, and `_on_run_ended(true)` in succession. Assert state remains `MusicState.END_DEFEAT` after all four calls.

**AC-AS-16** — Crossfade formula is correct at midpoint and boundary values. Unit test calls `AudioSystem._compute_crossfade_volume(start_db, target_db, t, duration) -> float` (pure function, no tween): assert `_compute_crossfade_volume(-6.0, -80.0, 0.5, 1.0)` is within ±0.01 dB of −43.0; assert `_compute_crossfade_volume(-80.0, 0.0, 0.5, 1.0)` is within ±0.01 dB of −40.0; assert `_compute_crossfade_volume(-6.0, -80.0, 0.0, 1.0) == -6.0` (t=0 returns start); assert `_compute_crossfade_volume(-6.0, -80.0, 1.0, 1.0) == -80.0` (t=duration returns target). **Implementation note:** `_compute_crossfade_volume()` is a test-only pure function that describes Formula 1's intent. It is NOT wired into a `_process()` loop — the live tween performs the actual interpolation at runtime. Do not call this function from `_process()` or any non-test code path.

### Music State — DYING

**AC-AS-28** — `death_started` transitions from `COMBAT` to `DYING` and initiates a music fade. Integration test: enter `COMBAT`, call `AudioSystem._on_death_started()`, assert: (a) `music_state == MusicState.DYING`; (b) `_active_tween` is non-null (a fade tween was created). Manual QA (timed): trigger player death in-game, verify music fades to silence within `CROSSFADE_DURATION_TO_DYING` seconds with no residual audio before the defeat stinger. **Note:** Mid-fade volume assertions are not possible without `Tween.custom_step()`, which does not exist in Godot 4. The linear interpolation formula used in the tween is covered by AC-AS-16.

**AC-AS-29** — DYING hold guard: `run_ended(win: false)` is queued (not immediate) when called before `DYING_MIN_HOLD_SEC` elapses. Integration test A (early signal): call `AudioSystem._on_death_started()` to enter DYING, then immediately call `AudioSystem._on_run_ended(false)`. Assert: (a) `music_state == MusicState.DYING` (state has NOT yet transitioned to END_DEFEAT — hold guard is active); (b) `_pending_defeat_transition == true` or equivalent queued flag is set (implementation detail — test via public `has_pending_defeat()` accessor or equivalent). Integration test B (delayed signal — after hold): Same setup, but after confirming state is still DYING, advance internal DYING timer past `DYING_MIN_HOLD_SEC` using a test-accessible `_set_dying_elapsed(sec)` method (or equivalent), then assert `music_state == MusicState.END_DEFEAT` (queued transition fired). **Note:** Real-time await for 1.5s is not required — use the timer injection accessor. If no timer injection is available, document as Manual QA only: trigger player death, wait 1.5s, verify END_DEFEAT music begins.

### Music State — END Auto-Transition

**AC-AS-26** — After END cue finishes, state auto-transitions to `MAIN_MENU`. Integration test: (1) trigger a full crossfade to END_DEFEAT by calling `AudioSystem._on_run_ended(false)` from PREPARATION state — this initiates the crossfade and connects the `finished` signal via `Object.CONNECT_ONE_SHOT` to the incoming player; (2) capture the incoming player reference as `end_player`; (3) emit the signal directly: `end_player.finished.emit()`; (4) assert `music_state == MusicState.MAIN_MENU`. **The crossfade initiation in step (1) is required** — `Object.CONNECT_ONE_SHOT` connects the signal at crossfade initiation, not at state assignment. Emitting `finished` without first running the crossfade will find no handler connected and the state will not change.

**AC-AS-27** — After the END auto-transition, a subsequent `run_started` signal triggers `MAIN_MENU → PREPARATION` normally. Integration test: follow AC-AS-26 to reach `MAIN_MENU`, call `_on_run_started()`, assert `music_state == MusicState.PREPARATION`.

### Music State — Ambient

**AC-AS-23** — `play_ambient("registered_amb_event")` assigns the stream to the active ambient player on the AMB bus. Integration test: registers a dummy ambient event (`bus = &"AMB"`), calls `play_ambient()`, asserts: (a) Ambient A has `stream == registered dummy stream` (assigned correctly); (b) Ambient A has `bus == &"AMB"`; (c) all SFX pool slots have unchanged `stream`.

**[M] AC-AS-24** — `stop_ambient()` initiates a fade-out on the active ambient player. Integration test (synchronous portion): call `play_ambient()`, then `stop_ambient()`, assert: (a) `_active_ambient_tween` is non-null (a fade tween was created); (b) the ambient tween has at least one property track targeting −80.0 dB on the active player (if Godot 4 exposes tween track inspection; otherwise omit). Manual QA (timed): call `play_ambient()`, then `stop_ambient()`, wait `CROSSFADE_DURATION_TO_AMBIENT_OUT` seconds, verify ambient player volume is near −80.0 dB and no audio is audible. **Note:** `Tween.custom_step()` does not exist in Godot 4 — mid-fade volume assertions via tween time injection are not possible without running the scene tree process loop.

**AC-AS-25** — `play_ambient()` while an ambient track is already playing crossfades to the new event without silence. Integration test: call `play_ambient("amb_a")`, capture `_active_ambient_tween` as `tween_1`, then immediately call `play_ambient("amb_b")`. Assert: (a) `_active_ambient_tween` is a different object than `tween_1` (a new crossfade tween was created); (b) the incoming ambient player's `stream == amb_b dummy stream` (new event assigned before tween runs); (c) Ambient A still has `stream == amb_a dummy stream` at time of assertion (outgoing player not cleared synchronously). Manual QA: play two different ambient events back-to-back and confirm no audible silence gap between them. **Note:** Confirming that both fade tweens run simultaneously is not assertable synchronously in GUT without running the scene process loop — simultaneous execution is guaranteed by `_active_ambient_tween.set_parallel(true)` in Core Rule 8.

### Stinger Playback

**AC-AS-35** — `play_stinger()` routes to the dedicated stinger player (not the SFX pool) and ducks the Music bus by the event's `duck_depth_db`. Integration test: snapshot all 24 SFX pool slot streams. Register a dummy stinger event (`bus = &"SFX"`, `duck_depth_db = -6.0`, `stinger_priority = 0`). **Note: bus must be `&"SFX"` or `&"UI"` — the `play_stinger()` guard rejects all other bus values; a `bus = &"Music"` entry will cause the stinger not to play and the test to be a silent false green.** Capture `prior_music_volume_db = AudioServer.get_bus_volume_db(music_bus_idx)`. Call `AudioSystem.play_stinger("dummy_stinger")`. Assert: (a) all SFX pool slots have unchanged `stream` values (stinger is non-pooled); (b) the stinger player's `stream == dummy stinger stream`; (c) `AudioServer.get_bus_volume_db(music_bus_idx)` is within ±0.01 dB of `(prior_music_volume_db + duck_depth_db)` — Music bus was ducked by `duck_depth_db` relative to its pre-call value.

**AC-AS-36** — `stop_stinger()` ends stinger playback and restores Music bus volume. Integration test: call `play_stinger("dummy_stinger")`, capture `prior_music_volume_db` before the call and `post_duck_volume_db` after. Call `stop_stinger()`. Assert: (a) stinger player's `stream` is null or reassigned (cleared); **do not** assert `playing == false` — `AudioStreamPlayer.playing` is unreliable in headless GUT (same threading issue as AC-AS-04); (b) `_active_stinger_tween` is non-null (a restore tween was created) — the tween being non-null is the synchronous assertion for "restore initiated." Manual QA (timed): play a stinger mid-combat, call `stop_stinger()`, wait `restore_duration_sec`, confirm `AudioServer.get_bus_volume_db(music_bus_idx) ≈ prior_music_volume_db` (no abrupt jump).

### Volume Control

**AC-AS-17** — `set_music_volume(-20.0)` sets AudioServer Music bus volume to −20.0 dB. Unit test calls the setter, reads `AudioServer.get_bus_volume_db(music_bus_idx)`, asserts equality within `is_equal_approx()` tolerance.

**AC-AS-18** — `set_sfx_volume(-200.0)` (below −80.0) clamps to −80.0. Unit test asserts `AudioServer.get_bus_volume_db(sfx_idx) == -80.0`.

**AC-AS-19** — `set_master_volume(10.0)` (above 0.0) clamps to 0.0. Unit test asserts bus at 0.0 dB.

**AC-AS-30** — Lower-bound clamping for UI and AMB buses. Unit test: `set_ui_volume(-200.0)` → assert `AudioServer.get_bus_volume_db(ui_idx) == -80.0`; `set_amb_volume(-200.0)` → assert `AudioServer.get_bus_volume_db(amb_idx) == -80.0`.

**AC-AS-37** — `set_music_volume()` enforces upper bound clamp at −3.0 dB (not 0.0 dB). Unit test: (a) call `set_music_volume(-3.0)` — assert `AudioServer.get_bus_volume_db(music_bus_idx) == -3.0` (at boundary, allowed); (b) call `set_music_volume(-1.0)` — assert `AudioServer.get_bus_volume_db(music_bus_idx) == -3.0` (clamped to upper bound); (c) call `set_music_volume(10.0)` — assert bus at −3.0 dB (not 0.0 dB). **This AC verifies the architectural SFX headroom invariant: Music bus cannot exceed −3.0 dB regardless of input.**

**AC-AS-38** — `set_amb_volume()` enforces upper bound clamp at −10.0 dB (not 0.0 dB). Unit test: (a) call `set_amb_volume(-10.0)` → assert bus at −10.0 dB (at boundary); (b) call `set_amb_volume(-5.0)` → assert bus at −10.0 dB (clamped); (c) call `set_amb_volume(0.0)` → assert bus at −10.0 dB.

**AC-AS-20** — `get_music_volume()` returns the value reflecting the most recent `set_music_volume()` call. Unit test round-trips: (a) −6.0 (in-range): assert getter returns −6.0; (b) −80.0 (lower boundary): assert getter returns −80.0; (c) −100.0 (out-of-range): assert getter returns −80.0 (clamped).

**AC-AS-31** — Formula 2 (slider → dB) is correctly implemented without integer division. Unit test calls `AudioSystem._slider_to_db(50)` and asserts within ±0.01 dB of −40.0; `_slider_to_db(0)` asserts −80.0; `_slider_to_db(100)` asserts 0.0.

### Singleton Contract

**AC-AS-21** — `AudioSystem.play_event()` is callable from any GDScript node without explicit reference. Integration test calls `play_event("test_sfx_event")` from a standalone script. Assert no null-reference error occurs and a pool slot changes state.

### Process Mode Correctness

**AC-AS-32** — Process modes are correct on all managed nodes. Unit test asserts: Music Player A and B have `PROCESS_MODE_ALWAYS`; Ambient Player A and B have `PROCESS_MODE_ALWAYS`; dedicated UI player has `PROCESS_MODE_ALWAYS`; Stinger player has `PROCESS_MODE_ALWAYS`; all 24 SFX pool nodes have `PROCESS_MODE_PAUSABLE`. Total managed nodes asserted: 30 (2 music + 2 ambient + 1 UI + 1 stinger + 24 SFX).

### Error Handling

**AC-AS-22** — If a music state's registered cue is null, Audio System logs `push_error()` and **remains in the current state** (state transition is blocked). Unit test: assert state is `PREPARATION`; set the COMBAT state's registered cue to null; call `AudioSystem._on_combat_started(false)`. Assert: (a) `music_state == MusicState.PREPARATION` (unchanged); (b) no music player stream changed; (c) a `push_error()` was logged.

**AC-AS-34** — `play_event()` called with an AMB-bus-registered event logs `push_error()` and does not alter any player. Integration test: register a dummy event with `bus = &"AMB"`; snapshot all SFX pool slot streams, the UI player stream, and all ambient player streams. Call `play_event("dummy_amb_event")`. Assert: (a) all SFX pool slots have unchanged `stream` values; (b) UI player `stream` is unchanged; (c) both ambient players have unchanged `stream` values; (d) a `push_error()` was logged. This confirms that `play_event()` guards against the AMB bus (ambient routing must use `play_ambient()`, not `play_event()`).

## Open Questions

1. **Boss music state (VS scope)**: A dedicated `BOSS` music state for the Warped Warden is deferred to Vertical Slice. When the Boss Encounter GDD is authored, this GDD must be updated with: a new `BOSS` enum constant, a new registered cue, and handling for `combat_started(is_boss: true)` to route to the `BOSS` state instead of `COMBAT`. *(Boss spawn stinger via `play_stinger()` is already specified for MVP — see Core Rule 12.)*

2. **Music looping format — RESOLVED**: MAIN_MENU, PREPARATION, and COMBAT cues must loop seamlessly. **Decision: audio-director delivers pre-looped OGG files.** The loop point is baked into the file by the composer using `AudioStreamOggVorbis.loop_mode = LOOP_FORWARD` with the loop offset set at the asset level. This avoids engine-side alignment fragility and keeps loop craftsmanship with the composer. WAV and MP3 are not valid formats for looping music cues in this game. Audio System does not manage loop offsets at runtime. **Note:** This decision does not apply to END_VICTORY and END_DEFEAT — those must be non-looping regardless.

3. **Footstep / movement audio ownership**: Player footstep/dash sounds are logically triggered by Player Controller events. Does Player Controller call `AudioSystem.play_event("sfx_fayde_footstep")` directly, or does Audio System listen to a Player Controller signal? Resolve in Player Controller GDD. **Note:** Footstep sounds must be assigned `priority = LOW` and **strongly recommended** to use a dedicated non-pooled `PROCESS_MODE_PAUSABLE` player — footsteps at normal movement speed fire 2–3 events per second, consuming pool slots and producing eviction pops when interrupted mid-sound. A dedicated footstep player costs 1 node and eliminates all pool pressure from footsteps. Decide in Player Controller GDD before implementation.

*(Q4 — `death_started` signal — resolved: Game State & Scene Flow GDD updated 2026-05-23 to add `death_started` to its signal contract.)*

5. **Memo's Resonance audio progression**: The game concept describes Memo undergoing gradual Resonance across the run, completing at the plot twist moment. The stinger API supports discrete one-shot moments. Does Memo's Resonance progression require a parameterized audio layer (e.g., an ambient sublayer that crossfades in as Resonance increases, or a Music bus filter that shifts timbre) — or does the `play_stinger("sfx_stinger_memo_peak")` API suffice? **Resolve when Lore Fragments GDD #21 is authored.** If a parameterized audio layer is required, this GDD must be revised before #21 can be designed — the framework does not currently expose a Resonance state parameter.

6. **CRITICAL stinger priority tier for boss spawn** *(deferred — Boss Encounter GDD #11)*: The current two-tier stinger priority policy (NARRATIVE = 1, COMBAT = 0) causes `sfx_stinger_boss_spawn` to be silently ignored if a NARRATIVE stinger is in progress (e.g., a memory fragment plays in the room just before the boss arena). A CRITICAL tier (`stinger_priority = 2`, overrides all including NARRATIVE) would fix this. **Defer until Boss Encounter GDD (#11) is authored.** If that GDD requires a guaranteed boss spawn sting, this GDD must be revised to add: a `CRITICAL` constant to `stinger_priority` valid range `{0, 1, 2}`, updated priority policy in Core Rule 12 and Edge Case 15, and updated validate-on-register range check.

7. **AMB bus ducking during NARRATIVE stingers** *(deferred — Vertical Slice implementation)*: `play_stinger()` currently ducks only the Music bus. At the plot twist moment (default AMB = −12 dB, Music ducked to −18 dB), the AMB layer is ~6 dB louder than the ducked Music, potentially undermining the narrative moment. Fix would require a new field `amb_duck_depth_db: float` in `AudioEventData` and a parallel AMB duck tween in `play_stinger()`. **Defer until stinger system is implemented at Vertical Slice.** Evaluate in audio QA playtest — if AMB/Music imbalance is perceptible at the plot twist, implement the field before shipping VS.

8. **Volume slider perceptual curve** *(deferred — post-MVP UX polish)*: Formula 2 uses a linear dB mapping (`lerp(-80.0, 0.0, slider / 100.0)`), which produces a perceptual dead zone: approximately 0–30% of slider travel is inaudible (−80–−56 dB range). Meaningful volume control only exists in the upper ~30–40% of the slider. Proposed fix (ready to implement when prioritized): `volume_db = lerp(-60.0, 0.0, pow(float(slider_value) / 100.0, 0.5))`. This compresses the lower range into the audible region. **Defer to post-MVP.** The Settings / Pause Menu GDD must flag this formula replacement when that system is authored.

9. **Stinger restore overwrites user mid-stinger volume change** *(deferred — Vertical Slice implementation)*: If the user adjusts the Music bus volume slider while a stinger is playing (and ducking the Music bus), the restore on stinger completion will overwrite the user's new setting with the pre-stinger baseline. Two fix options: (a) **delta restore** — restore by `+duck_depth_db` from current Music bus value rather than to the stored absolute baseline; (b) **tolerance check** — if current Music bus volume differs from the expected ducked value (`stored_baseline + duck_depth_db`) by more than 0.5 dB, assume user changed it and skip restore. **Defer to VS implementation.** Resolve during AC-AS-36 extension authoring; document the chosen strategy in Core Rule 12.

---

### Deferred Acceptance Criteria *(add at Vertical Slice implementation time)*

The following ACs have no current entry in the AC section. Number them sequentially after the last existing AC when implementing the stinger system:

- **Stinger priority policy — NARRATIVE blocks COMBAT**: Enter a NARRATIVE stinger; call `play_stinger()` with a COMBAT stinger. Assert: COMBAT call is silently ignored; NARRATIVE stinger continues; Music bus duck unchanged.
- **Stinger priority policy — NARRATIVE interrupts COMBAT**: Enter a COMBAT stinger; call `play_stinger()` with a NARRATIVE stinger. Assert: NARRATIVE stinger immediately replaces COMBAT; duck tween restarts with new event's `duck_depth_db`; original `_music_pre_stinger_volume` baseline is retained.
- **Stinger priority policy — same priority last-caller-wins**: Two COMBAT stingers in sequence; assert second caller interrupts first.
- **DYING + stinger + finish → Music bus unchanged**: Trigger `death_started` → DYING → call `play_stinger()` → emit `_stinger_player.finished`. Assert Music bus volume remains at −80 dB (DYING duck suppression prevented any restore tween from being created).
