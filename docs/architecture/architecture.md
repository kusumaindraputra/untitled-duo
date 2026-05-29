# The Last Cipher — Master Architecture

## Document Status

- **Version:** 1.0 (draft)
- **Last Updated:** 2026-05-29
- **Engine:** Godot 4.6 (Compatibility renderer, OpenGL 3.3 / D3D12 Windows)
- **GDDs Covered:** game-state-scene-flow, health-damage, prana-data, enemy-data, player-controller, prana-grid, combination-resolution, spell-casting-effects, enemy-ai, wave-encounter-system, combat-hud, status-effects, run-management, audio-system (14 of 15 First-Playable/MVP systems)
- **ADRs Referenced:** ADR-0001 (Accepted), ADR-0002 (Accepted), ADR-0003 (Accepted), ADR-0004 (Accepted), ADR-0005 (Accepted), ADR-0006 (Accepted), ADR-0007 (Accepted), ADR-0008 (Accepted); ADR-0009–0010 Proposed (defer to sprint start)
- **Technical Director Sign-Off:** 2026-05-29 — APPROVED WITH CONDITIONS (ADR-0002–0006 required before coding; H&D registration contract in ADR-0007; ADR-0001 verification test before IsometricRoom sprint)
- **Lead Programmer Feasibility:** N/A (Lean mode — skipped)

---

## Engine Knowledge Gap Summary

| Risk | Domain | Impact |
|------|--------|--------|
| HIGH | TileMapLayer isometric | ADR-0001 validation test required before first IsometricRoom implementation |
| HIGH | UI Dual-focus (4.6) | PranaGrid mouse/gamepad cursor + CombatHUD must be tested with both input methods |
| MEDIUM | Input / SDL3 gamepad | Gamepad bindings should be validated post-build on target hardware |
| MEDIUM | GDScript 4.5+ features | `@abstract`, variadic args available; training data unreliable — verify against engine docs |

---

## System Layer Map

<!-- WRITTEN: 2026-05-29 — approved by user -->

```
┌─────────────────────────────────────────────────────────────────┐
│  PRESENTATION LAYER                                             │
│  CombatHUD (CanvasLayer 10, PROCESS_MODE_ALWAYS)               │
│  [Future VS+: RunSummaryScreen, MainMenu, PauseMenu]            │
├─────────────────────────────────────────────────────────────────┤
│  FEATURE LAYER                                                  │
│  WaveManager (Node/Autoload — encounter lifecycle)              │
│  [Future VS+: BossEncounter, ObstacleSystem, PranaDrop,         │
│   ProceduralDungeon, LoadoutSlots, MetaProgression]             │
├─────────────────────────────────────────────────────────────────┤
│  CORE LAYER                                                     │
│  PlayerController (CharacterBody2D — Fayde movement/dash)       │
│  HealthAndDamage (Autoload — HP pools + damage pipeline)        │
│  PranaGrid (Scene node — 3×3 arrangement UI)                    │
│  CombinationResolution (Autoload — arrangement → SpellEffect)   │
│  SpellCastingEffects (Autoload — execution layer)               │
│  StatusEffectsManager (Autoload — tick timing authority)        │
│  EnemyInstance (CharacterBody2D — per-enemy behavior)           │
├─────────────────────────────────────────────────────────────────┤
│  FOUNDATION LAYER                                               │
│  GameEnums (game_enums.gd — class_name only, NOT autoload)      │
│  PranaCatalog (Autoload — 5 PranaType .tres files)              │
│  EnemyCatalog (Autoload — 4 EnemyType .tres files)              │
│  GameStateManager (Autoload — 6-state MVP machine)              │
│  SceneManager (Autoload — sub-scene swap, persistent HUD)       │
│  AudioSystem (Autoload — 4-bus + AudioEventRegistry)            │
│  RunManager (Autoload — run lifecycle, 3-field record)          │
│  IsometricRoom (Scene root — TileMapLayer + Y-sort wrapper)     │
│                         ⚠️ HIGH RISK: TileMapLayer isometric     │
│                         in Godot 4.6 not yet verified (ADR-0001) │
├─────────────────────────────────────────────────────────────────┤
│  PLATFORM LAYER                                                 │
│  Godot 4.6 — Compatibility renderer (OpenGL 3.3 / D3D12 Win)   │
│  GodotPhysics2D, AudioServer, PhysicsDirectSpaceState2D         │
└─────────────────────────────────────────────────────────────────┘
```

**Autoload registration order** (Project Settings → AutoLoad):
```
1. PranaCatalog         (first — data catalog; everything depends on it)
2. EnemyCatalog         (second — data catalog)
3. GameStateManager     (third — state machine; catalogs must be ready)
4. SceneManager         (fourth — after GSM)
5. AudioSystem          (fifth — after GSM for state signals)
6. HealthAndDamage      (sixth — after GSM for run_started)
7. StatusEffectsManager (seventh — after HealthAndDamage)
8. CombinationResolution (eighth — after data catalogs)
9. SpellCastingEffects  (ninth — after CombinationResolution)
10. RunManager          (tenth — after GameStateManager)
```

---

## Module Ownership

<!-- WRITTEN: 2026-05-29 — approved by user -->

### Foundation Layer

| Module | File | Owns | Exposes | Consumes | Engine APIs |
|--------|------|------|---------|----------|-------------|
| **GameEnums** | `src/data/game_enums.gd` | All shared enum definitions: DamageClass, DamageSource, BaseStatus, CastAnimation, VfxBurstShape, EnemyArchetype, RunOutcome, HPZone, WaveState, EnemyState | All constants via `class_name GameEnums` | Nothing | None (`extends RefCounted`) |
| **PranaCatalog** | `src/data/prana_catalog.gd` | 5 PranaType `.tres`; `_initialized` guard | `get_type(id: int) -> PranaType` (returns `duplicate_deep()`) | Nothing (file-backed .tres) | `ResourceLoader.load()`, `Resource.duplicate_deep()` ⚠️ Godot 4.5+ replaces deprecated `duplicate(true)` |
| **EnemyCatalog** | `src/data/enemy_catalog.gd` | 4 EnemyType `.tres`; active/vs_scope/inactive filter | `get_type(id) -> EnemyType`; `get_active_types() -> Array[EnemyType]` | Nothing | `ResourceLoader.load()` |
| **GameStateManager** | `src/core/game_state_manager.gd` | Active state; `_previous_state`; transition validation; re-entrancy flag | Signals: `state_changed`, `run_started`, `preparation_started`, `combat_started`, `grid_locked`, `grid_hidden`, `wave_ended`, `death_started`, `run_ended`, `game_paused`, `game_resumed`, `room_cleared`; `get_active_state()` | PranaGrid.`is_loadout_valid()`; listens to PranaGrid.`arrangement_confirmed`, WaveManager.`wave_cleared`/`all_waves_cleared`/`boss_defeated`, HealthAndDamage.`player_died` | `get_tree().paused`, `call_deferred()` |
| **SceneManager** | `src/core/scene_manager.gd` | Current sub-scene ref; persistent root scene; HUD node ref | `change_room(packed_scene: PackedScene)` | GSM signals (trigger scene changes) | `PackedScene.instantiate()`, `remove_child()`, `add_child()`, `queue_free()`, `await get_tree().process_frame` |
| **AudioSystem** | `src/audio/audio_system.gd` | AudioEventRegistry `Dict[StringName, AudioEventData]`; Music FSM state; SFX pool (24 `AudioStreamPlayer`); bus routing | `play_event(id: StringName)`, `play_stinger(id: StringName)`, `register_event(id, data)` | GSM signals (music transitions); H&D.`player_died`, `player_hp_zone_changed` | `AudioServer.set_bus_volume_db()`, `AudioServer.get_bus_index()`, `AudioStreamPlayer`, `create_tween()` |
| **RunManager** | `src/systems/run_manager.gd` | `run_active`, `run_outcome` (RunOutcome), `waves_completed` | `get_run_data() -> Dictionary` (copy) | GSM: `run_started`, `wave_ended`, `room_cleared`, `run_ended` | None |
| **IsometricRoom** | `src/world/isometric_room.gd` | TileMapLayer (floor/walls); spawn marker `Node2D`; `y_sort_enabled = true` | `get_spawn_markers() -> Array[Vector2]`; scene root for all game entities | Nothing at runtime | `TileMapLayer`, `TileSet.TILE_SHAPE_ISOMETRIC`, `Node2D.y_sort_enabled` ⚠️ HIGH RISK — Godot 4.6 isometric unverified (ADR-0001 verification required before implementation) |

### Core Layer

| Module | File | Owns | Exposes | Consumes | Engine APIs |
|--------|------|------|---------|----------|-------------|
| **PlayerController** | `src/gameplay/player_controller.gd` | Velocity, position, state (DISABLED/ENABLED/DASHING), `_is_invincible`, `_last_facing_dir`, dash cooldown accumulator, footstep accumulator + shuffle bag | `is_invincible() -> bool`; `get_facing_direction() -> Vector2`; `get_cast_position() -> Vector2`; `get_controller_state()` | GSM: `combat_started` → enable, `preparation_started` → disable; SC&E: `cast_hit_started` → CAST_LOCKED; `Input` actions; AudioSystem.`play_event()` | `CharacterBody2D.move_and_slide()`, `Input.get_vector()`, `Input.is_action_just_pressed()`, `atan2()`, `round()` |
| **HealthAndDamage** | `src/systems/health_and_damage.gd` | Fayde `current_hp`; all enemy HP instances (Dict[int, EnemyHPInstance]); `_iframe_active`; `_current_zone` | `apply_damage(target, base_damage: float, element, source: DamageSource)`; `apply_heal(target, heal_amount: float)`; `force_end_iframe_window()`; signals: `damage_taken`, `health_restored`, `player_died`, `enemy_killed`, `heavy_hit`, `player_hp_zone_changed` | PlayerController.`is_invincible()` (step 1a); EnemyCatalog (base_hp at spawn); GSM.`run_started` → reset | `roundi()`, `clamp()`, `instance_from_id()` |
| **PranaGrid** | `src/ui/prana_grid.gd` | 9-slot arrangement array; grid state (ARRANGEMENT/LOCKED/HIDDEN); `committed_fragments` | `committed_fragments` getter; `is_loadout_valid() -> bool`; signal: `arrangement_confirmed` | GSM: `preparation_started` → clear+ARRANGEMENT, `grid_locked` → LOCKED, `grid_hidden` → HIDDEN; PranaCatalog for rendering | `CanvasLayer` parent, Control nodes, mouse drag, `Input` ⚠️ HIGH RISK: dual-focus Godot 4.6 — test mouse + gamepad paths independently |
| **CombinationResolution** | `src/systems/combination_resolution.gd` | Resolution algorithm; effect tables (data-driven Resources) | Signal: `combo_resolved(spell_effect: SpellEffect)` | PranaGrid.`committed_fragments` (after `combat_started`); GSM.`combat_started` → trigger | `Resource` loading |
| **SpellCastingEffects** | `src/systems/spell_casting_effects.gd` | SpellEffect cache per wave; SC&E state (IDLE/READY/CHAINING/CAST_LOCKED); combo index; timing accumulators | `get_stat_bonus(stat_id: StringName) -> float`; signals: `chain_index_changed`, `spell_hit_element`, `cast_hit_started(duration)` | CombinationResolution.`combo_resolved`; GSM.`combat_started`/`preparation_started`; PlayerController.`get_facing_direction()` + `get_cast_position()`; H&D.`apply_damage()`; StatusEffectsManager.`apply_status()`; Input.`is_action_just_pressed(&"cast")` | `PhysicsDirectSpaceState2D.intersect_ray()`, `get_world_2d().direct_space_state`, `PhysicsRayQueryParameters2D.create()` |
| **StatusEffectsManager** | `src/systems/status_effects_manager.gd` | All active `StatusInstance` objects (per target, per type); tick accumulators | `apply_status(target: Node, type: BaseStatus, duration: float)`; `is_frozen(target) -> bool`; `is_blinded(target) -> bool` | H&D.`apply_damage()` (DoT); H&D.`apply_heal()` (Regen); H&D.`enemy_killed` → clear; GSM.`preparation_started` → clear all | `_process(delta)` float accumulators only |
| **EnemyInstance** | `src/enemies/enemy_instance.gd` | Velocity, position, archetype behavior state, `_combat_active`, contact timer, enemy state (ALIVE/DEAD) | `init(enemy_type_id: int)`; animation interface | EnemyCatalog.`get_type()` at init; GSM.`combat_started` → activate; GSM.`preparation_started` → deactivate; H&D.`apply_damage()` on contact; H&D.`enemy_killed` → death sequence | `CharacterBody2D.move_and_slide()`, `Area2D` + `CollisionShape2D`, `body_entered`/`body_exited`, `AnimationPlayer`, `queue_free()` |

### Feature + Presentation Layer

| Module | File | Owns | Exposes | Consumes | Engine APIs |
|--------|------|------|---------|----------|-------------|
| **WaveManager** | `src/systems/wave_manager.gd` | `_wave_composition`; `_enemies_alive`/`_total`; `_wave_state` | Signals: `wave_cleared`, `all_waves_cleared`, `boss_defeated` | GSM.`combat_started` → spawn; GSM.`preparation_started` → reset; H&D.`enemy_killed` → decrement | `PackedScene.instantiate()`, `add_child()` |
| **CombatHUD** | `src/ui/combat_hud.gd` | HP bar; floating damage number pool; chain dot indicators; visual state | Nothing (passive listener) | H&D signals; SC&E signals; GSM: `combat_started`, `preparation_started`, `run_started` | `CanvasLayer` (layer 10), `ProgressBar`, `Label`, `create_tween()` ⚠️ `PROCESS_MODE_ALWAYS` — verify focus behavior during `get_tree().paused` |

### Dependency Diagram

```
Foundation ──────────────────────────────────────────────────────
 GameEnums ← all modules (class_name — no import needed)
 PranaCatalog ←── PranaGrid, CombinationResolution, SpellCastingEffects
 EnemyCatalog ←── HealthAndDamage(spawn), EnemyInstance(init), WaveManager(spawn)
 GameStateManager ──signals──► PlayerController, HealthAndDamage, PranaGrid,
                                StatusEffectsManager, SpellCastingEffects,
                                EnemyInstance, WaveManager, RunManager, CombatHUD
 SceneManager ←── GSM signals; loads → IsometricRoom
 AudioSystem ←── GSM signals, PlayerController.play_event(),
                  HealthAndDamage signals, SpellCastingEffects.play_event()
 RunManager ←── GSM signals
 IsometricRoom = arena scene root (parents PlayerController, EnemyInstances, WaveManager ref)

Core ─────────────────────────────────────────────────────────────
 PlayerController ──is_invincible()──► HealthAndDamage
 HealthAndDamage ◄──apply_damage/heal── SpellCastingEffects, EnemyInstance, StatusEffectsManager
 PranaGrid ──committed_fragments──► CombinationResolution
            ──is_loadout_valid()──► GameStateManager
            ──arrangement_confirmed──► GameStateManager
 CombinationResolution ──combo_resolved──► SpellCastingEffects
 SpellCastingEffects ──apply_damage()──► HealthAndDamage
                    ──apply_status()──► StatusEffectsManager
                    ──cast_hit_started──► PlayerController
 StatusEffectsManager ──apply_damage/heal──► HealthAndDamage
 EnemyInstance ──apply_damage()──► HealthAndDamage
               ◄──enemy_killed signal── HealthAndDamage (listened by WaveManager + EnemyInstance)

Feature ──────────────────────────────────────────────────────────
 WaveManager ──wave_cleared/all_waves_cleared/boss_defeated──► GameStateManager

Presentation ─────────────────────────────────────────────────────
 CombatHUD ◄──signals── HealthAndDamage, SpellCastingEffects, GameStateManager
```

---

## Data Flow

<!-- WRITTEN: 2026-05-29 — approved by user -->

### Scenario 1 — Frame Update Path (COMBAT_PHASE, per physics frame)

```
Input (keyboard/gamepad)
   │
   ▼
PlayerController._physics_process(delta)
   ├── Input.get_vector() → velocity lerp → move_and_slide()
   ├── float accumulator → footstep fire → AudioSystem.play_event()
   └── If dash pressed → DASHING, _is_invincible = true

EnemyInstance._physics_process(delta) [×10 at FP]
   ├── dir = (fayde.global_position − self.global_position).normalized()
   ├── velocity = dir × _move_speed → move_and_slide()
   └── Area2D.body_entered → contact_timer → H&D.apply_damage(CONTACT)

SpellCastingEffects._process(delta)
   ├── Input.is_action_just_pressed(&"cast") check
   ├── PhysicsDirectSpaceState2D.intersect_ray() → primary_target
   ├── Damage formula → H&D.apply_damage(DIRECT)
   └── Status → StatusEffectsManager.apply_status()

StatusEffectsManager._process(delta)
   └── float accumulators → tick → H&D.apply_damage(DOT) or H&D.apply_heal()

HealthAndDamage (reactive — no _process loop)
   └── Signals → CombatHUD, AudioSystem, WaveManager, EnemyInstance
```

*All timing via float accumulators in `_process(delta)` — never `SceneTree.create_timer()` or `Timer` nodes. Synchronized with `PROCESS_MODE_PAUSABLE`.*

---

### Scenario 2 — State Transition: PREPARATION → COMBAT

```
Player confirms PranaGrid (slot 4 non-null)
   │
   ▼
PranaGrid emits: arrangement_confirmed
   │
   ▼
GameStateManager._on_arrangement_confirmed()
   ├── PranaGrid.is_loadout_valid() → true
   ├── emit grid_locked ───────────────────────────────────► PranaGrid → LOCKED
   └── emit combat_started(is_boss: false)
         ├─────────────────────────────────────────────────► PlayerController → ENABLED
         ├─────────────────────────────────────────────────► EnemyInstances activate
         ├─────────────────────────────────────────────────► CombatHUD → combat layout
         ├─────────────────────────────────────────────────► AudioSystem → COMBAT music
         └─────────────────────────────────────────────────► WaveManager → spawn 10 enemies

CombinationResolution (triggered by combat_started)
   └── reads PranaGrid.committed_fragments → resolves → emits combo_resolved(SpellEffect)
         │
         ▼
   SpellCastingEffects caches SpellEffect → READY state
```

*Signal ordering guarantee: `grid_locked` always fires before `combat_started` in the same handler.*

---

### Scenario 3 — Run End: Same-Frame Death Priority

```
Physics frame N:
  Enemy kill: H&D → enemy_killed ────────────────────────────► WaveManager._enemies_alive -= 1
                                                              ► (if 0) emit all_waves_cleared
                                                                then boss_defeated
                                                              [boss_defeated → call_deferred]

  Fayde death: H&D → player_died (IMMEDIATE)
     │
     ▼
  GameStateManager._on_player_died() [IMMEDIATE]
     ├── emit death_started ─────────────────────────────────► AudioSystem → DYING
     ├── _active_state = DEATH_SCREEN
     └── emit run_ended(win: false) ────────────────────────► RunManager.run_outcome = LOSS

Physics frame N+1:
  call_deferred fires: _request_transition(RUN_SUMMARY)
     └── _active_state == DEATH_SCREEN → REJECTED (invalid transition)
         Loss preserved. ✓
```

---

### Scenario 4 — Save/Load Path (MVP: None)

No save/load system at MVP. `RunManager` persists run state in memory for the current session only. Architecture is designed for later addition: `RunManager.get_run_data()` already returns a copy-safe `Dictionary` — a future `SaveManager` autoload can serialize it without structural change.

---

### Scenario 5 — Initialization Order (startup)

```
AutoLoads (in registration order):
  1. PranaCatalog._ready()        → loads 5 .tres, validates, _initialized = true
  2. EnemyCatalog._ready()        → loads 4 .tres
  3. GameStateManager._ready()    → state = MAIN_MENU
  4. SceneManager._ready()        → loads persistent root + HUD
  5. AudioSystem._ready()         → builds registry, SFX pool
  6. HealthAndDamage._ready()     → empty HP dicts; connects to GSM.run_started
  7. StatusEffectsManager._ready()→ empty table; connects to H&D.enemy_killed, GSM
  8. CombinationResolution._ready()→ loads effect tables; connects to GSM.combat_started
  9. SpellCastingEffects._ready() → connects to CombinationResolution + GSM
 10. RunManager._ready()          → connects to GSM signals

Main scene loads:
  → IsometricRoom (TileMapLayer, spawn markers, Y-sort)
  → PlayerController (CharacterBody2D, "player" group)
  → PranaGrid (CanvasLayer child)
  → CombatHUD (CanvasLayer layer 10)
  → WaveManager node
```

*Scene nodes are always safe to call PranaCatalog — all Autoloads initialize before the main scene.*

---

## API Boundaries

<!-- WRITTEN: 2026-05-29 — approved by user -->

### Foundation Layer Contracts (GDScript pseudocode)

```gdscript
# ── GameEnums (game_enums.gd) ─────────────────────────────────────────────────
# class_name GameEnums, extends RefCounted — NOT an Autoload.
# All constants use explicit integer assignments for .tres serialization stability.
enum DamageClass  { NONE = -1, FIRE = 0, SHADOW = 1, LIGHTNING = 2, ICE = 3, NATURE = 4 }
enum DamageSource { DIRECT = 0, DOT = 1, CONTACT = 2 }
enum BaseStatus   { BURN, BLIND, STUN, FREEZE, REGENERATE }
enum HPZone       { FULL, CAREFUL, DESPERATE }
enum GameState    { MAIN_MENU, PREPARATION_PHASE, COMBAT_PHASE, PAUSED, RUN_SUMMARY, DEATH_SCREEN }
enum RunOutcome   { NONE, WIN, LOSS }
enum EnemyArchetype { SEEKER, RUSHER, SWARMER, BOSS }
enum WaveState    { IDLE, WAVE_ACTIVE, WAVE_COMPLETE }

# ── PranaCatalog ───────────────────────────────────────────────────────────────
func get_type(id: int) -> PranaType  # duplicate_deep() copy; null + push_error() on miss
# push_error() if called before _ready() (_initialized guard).

# ── EnemyCatalog ───────────────────────────────────────────────────────────────
func get_type(id: int) -> EnemyType          # null on miss
func get_active_types() -> Array[EnemyType]  # active entries only

# ── GameStateManager ───────────────────────────────────────────────────────────
func get_active_state() -> GameEnums.GameState
signal state_changed(old_state: int, new_state: int)
signal run_started()
signal preparation_started(wave_index: int, waves_remaining: int)
signal combat_started(is_boss: bool)
signal grid_locked()        # always fires before combat_started in same handler
signal grid_hidden()
signal wave_ended()
signal death_started()      # first signal in COMBAT_PHASE → DEATH_SCREEN handler
signal run_ended(win: bool)
signal game_paused()
signal game_resumed()
signal room_cleared()
# Invariant: _request_transition() must never be called outside this file. CI grep enforced.

# ── SceneManager ───────────────────────────────────────────────────────────────
func change_room(packed_scene: PackedScene) -> void  # awaits process_frame between free+add

# ── AudioSystem ────────────────────────────────────────────────────────────────
func register_event(id: StringName, data: AudioEventData) -> void
func play_event(id: StringName) -> void
func play_stinger(id: StringName) -> void
# Priority: CRITICAL(2) > NARRATIVE(1) > COMBAT(0); same-tier = last-caller-wins

# ── RunManager ─────────────────────────────────────────────────────────────────
func get_run_data() -> Dictionary  # copy: { run_active, run_outcome, waves_completed }

# ── IsometricRoom ──────────────────────────────────────────────────────────────
func get_spawn_markers() -> Array[Vector2]
# ⚠️ HIGH RISK: TileMapLayer + TILE_SHAPE_ISOMETRIC — verify in Godot 4.6 before implementing.
```

### Core Layer Contracts

```gdscript
# ── PlayerController ──────────────────────────────────────────────────────────
# Invariant: must be in "player" group. EnemyInstance must NOT be in "player" group.
func is_invincible() -> bool
func get_facing_direction() -> Vector2  # normalized, post-snap 8-dir unit vector
func get_cast_position() -> Vector2     # Fayde's global_position

# ── HealthAndDamage ────────────────────────────────────────────────────────────
func apply_damage(target: Node, base_damage: float,
                  element: GameEnums.DamageClass, source: GameEnums.DamageSource) -> void
func apply_heal(target: Node, heal_amount: float) -> void  # negative = error + no-op
func force_end_iframe_window() -> void  # TEST SEAM ONLY — never call from gameplay
signal damage_taken(target: Node, final_damage: int, current_hp: int)
signal health_restored(target: Node, healed_amount: int, current_hp: int)
signal player_died()                    # fires exactly once per run
signal enemy_killed(instance_id: int, type_id: int,
                    prana_affiliation: GameEnums.DamageClass)  # NONE(-1) for neutral; never null
signal heavy_hit(target: Node, final_damage: int)
signal player_hp_zone_changed(zone: GameEnums.HPZone)

# ── PranaGrid ─────────────────────────────────────────────────────────────────
func is_loadout_valid() -> bool            # slot 4 non-null required
func get_committed_fragments() -> Array    # Array[PranaFragment|null], length 9; read-only
signal arrangement_confirmed()

# ── CombinationResolution ─────────────────────────────────────────────────────
signal combo_resolved(spell_effect: SpellEffect)

# ── SpellCastingEffects ───────────────────────────────────────────────────────
func get_stat_bonus(stat_id: StringName) -> float  # 0.0 if no cache or unknown id
signal chain_index_changed(combo_index: int, combo_attack_count: int)
signal spell_hit_element(target: Node, prana_type_id: int)
signal cast_hit_started(lock_duration: float)

# ── StatusEffectsManager ─────────────────────────────────────────────────────
func apply_status(target: Node, status_type: GameEnums.BaseStatus, duration: float) -> void
func is_frozen(target: Node) -> bool
func is_blinded(target: Node) -> bool

# ── EnemyInstance ─────────────────────────────────────────────────────────────
func init(enemy_type_id: int) -> void
# Invariant: EnemyInstance must NOT be in "player" group.
# Invariant: node survives at least one frame after enemy_killed fires (queue_free() only).

# ── WaveManager ───────────────────────────────────────────────────────────────
# Invariant: sole emitter of wave progress signals.
signal wave_cleared()
signal all_waves_cleared()
signal boss_defeated()
```

### Cross-Cutting Invariants

| Invariant | Enforcement |
|-----------|-------------|
| `"player"` group on PlayerController only | H&D step 1a + group check in EnemyInstance |
| `queue_free()` only for enemy death | Enemy AI GDD Rule 6; never `free()` |
| Float accumulator pattern for all game timers | All Core + Feature autoloads; no `Timer` nodes in gameplay |
| `push_error()` not `assert()` for release-safe guards | PranaCatalog, GameStateManager |
| Explicit integer assignments on all GameEnums constants | game_enums.gd implementation |
| `_request_transition()` never called outside GameStateManager | AC-06 CI grep check on every push to main |

---

## ADR Audit

<!-- WRITTEN: 2026-05-29 — approved by user -->

### ADR Quality Check

| ADR | Engine Compat | Version | GDD Linkage | Conflicts | Valid |
|-----|--------------|---------|-------------|-----------|-------|
| ADR-0001: Isometric View | ✅ | ✅ Godot 4.6 | ✅ game-concept, health-damage | None | ✅ |
| ADR-0002: Autoload Architecture | ✅ | ✅ Godot 4.6 | ✅ GSF, PD, ED, RM, SC, SE | None | ✅ |
| ADR-0003: Signal-Driven Architecture | ✅ | ✅ Godot 4.6 | ✅ GSF, PG, CH, RM | None | ✅ |
| ADR-0004: Float Accumulator Timer | ✅ | ✅ Godot 4.6 | ✅ PD, SC, PC, EA | None | ✅ |
| ADR-0005: Persistent HUD Sub-Scene Swap | ✅ | ✅ Godot 4.6 | ✅ GSF, CH | None | ✅ |
| ADR-0006: GameEnums Pure Container | ⚠️ VERIFY: .tres int serialization | ✅ Godot 4.6 | ✅ PD, HD, GSF | None | ✅ |
| ADR-0007: HealthAndDamage Singleton | ✅ | ✅ Godot 4.6 | ✅ HD, SE, EA, WE | None | ✅ |
| ADR-0008: PranaCatalog Immutability | ⚠️ VERIFY: duplicate_deep() isolation | ✅ Godot 4.6 | ✅ PD | None | ✅ |

ADRs 0001–0008 all pass quality gates. Two verification tests remain (ADR-0006: .tres int serialization; ADR-0008: duplicate_deep() isolation).

### Traceability Coverage

- **Covered:** TR-ISO-001 through TR-ISO-004 (ADR-0001); TR-ENG-002, TR-GSF-008, TR-PD-001, TR-ED-001, TR-RM-001, TR-SC-001, TR-SE-001 (ADR-0002); TR-GSF-002, TR-PG-004, TR-CH-002, TR-RM-004 (ADR-0003); TR-ENG-003, TR-PC-005, TR-SC-002, TR-SE-002 (ADR-0004); TR-GSF-007, TR-GSF-009, TR-CH-001 (ADR-0005); TR-PD-003/004, TR-ENG-001 (ADR-0006); TR-HD-001–014 (ADR-0007); TR-PD-002/005 (ADR-0008)
- **Remaining gaps:** TR-SC-005 (stat broker), TR-PC-006/TR-EA-009 (group convention) — covered by ADR-0009/0010 when authored

All Foundation and Core ADRs are now written. See Required ADRs below for remaining deferred items.

---

## Required ADRs

<!-- WRITTEN: 2026-05-29 — approved by user -->

### Foundation Layer — COMPLETE (all Accepted)

| # | ADR File | Status | Covers TRs |
|---|----------|--------|-----------|
| ADR-0002 | `adr-0002-autoload-architecture.md` | ✅ Accepted | TR-ENG-002, TR-GSF-008, TR-PD-001, TR-ED-001, TR-RM-001, TR-SC-001, TR-SE-001 |
| ADR-0003 | `adr-0003-signal-driven-architecture.md` | ✅ Accepted | TR-GSF-002, TR-PG-004, TR-CH-002, TR-RM-004 |
| ADR-0004 | `adr-0004-float-accumulator-timer-pattern.md` | ✅ Accepted | TR-ENG-003, TR-PC-005, TR-SC-002, TR-SE-002 |
| ADR-0005 | `adr-0005-persistent-hud-sub-scene-swap.md` | ✅ Accepted | TR-GSF-007, TR-GSF-009, TR-CH-001 |
| ADR-0006 | `adr-0006-game-enums-pure-container.md` | ✅ Accepted | TR-PD-003, TR-PD-004, TR-ENG-001 |

### Core Layer — COMPLETE (all Accepted)

| # | ADR File | Status | Covers TRs |
|---|----------|--------|-----------|
| ADR-0007 | `adr-0007-health-damage-autoload-singleton.md` | ✅ Accepted | TR-HD-001 through TR-HD-014 |
| ADR-0008 | `adr-0008-prana-catalog-immutability.md` | ✅ Accepted | TR-PD-002, TR-PD-005 |

### Deferred to Implementation Sprint

| # | Run | Note |
|---|-----|------|
| ADR-0009 | `/architecture-decision "SpellCastingEffects Wave-Scoped Stat Broker"` | Covers `get_stat_bonus()` (TR-SC-005); needed before CR + Status Effects implementation sprint |
| ADR-0010 | `/architecture-decision "Player Group Convention and Target Discrimination"` | Covers TR-PC-006, TR-EA-009; needed before first enemy or H&D implementation sprint |

---

## Architecture Principles

<!-- WRITTEN: 2026-05-29 -->

1. **Signals define system boundaries.** Systems communicate exclusively via Godot signals. No system holds a typed reference to another system's implementation class. This enforces loose coupling and enables individual unit testing with stub signal emitters.

2. **State lives in one owner.** Every piece of game state has exactly one owning module. No system duplicates or caches state owned by another: HP in HealthAndDamage only; game state in GameStateManager only; Prana arrangement in PranaGrid only. Violations produce split-brain state that test suites cannot catch.

3. **Float accumulators, not Timer nodes.** All in-game timing uses delta accumulators in `_process(delta)`. This is the only pattern that pauses correctly with `PROCESS_MODE_PAUSABLE` without requiring custom pause/resume logic in every system.

4. **Data-driven balance values.** All tuning knobs live in `@export var` fields or `.tres` Resource files, never hardcoded inline. A designer must be able to adjust any value without touching code and without triggering a code rebuild.

5. **Defensive startup guards, not debug-only asserts.** Foundation autoloads validate their data on `_ready()` and use `push_error()` for all guards. `assert()` is stripped from Godot 4.6 release builds — it provides zero runtime protection in any shipped build. `push_error()` survives release exports.

---

## Open Questions

<!-- WRITTEN: 2026-05-29 -->

| ID | Summary | Priority | Resolution Path |
|----|---------|----------|-----------------|
| QQ-01 | TileMapLayer isometric config in Godot 4.6 + Compatibility renderer not verified | High | ADR-0001 Validation Criteria — run test project before first IsometricRoom implementation sprint |
| QQ-02 | PranaGrid dual-focus behavior (mouse drag + gamepad cursor) in Godot 4.6 | High | Build a prototype PranaGrid scene and test both input paths after ADR-0002 is written |
| QQ-03 | HealthAndDamage enemy HP: Dict[int, EnemyHPInstance] — needs a `register_enemy()` / `unregister_enemy()` call pattern that WaveManager must follow precisely | Medium | ADR-0007 — specify the registration contract (when to call, on which frame) |
| QQ-04 | WaveManager PackedScene loading — EnemyType.tres needs a `scene_path: String` property or a separate scene map | Medium | ADR-0002 or ADR-0007 — decide where enemy PackedScene references live |
| QQ-05 | Audio System 12 pending blockers (B1–B12) — Audio System GDD is not yet Approved | Medium | Resolve Audio System GDD blockers (Revision 5) before AudioSystem implementation sprint |
| QQ-06 | Prana Grid gamepad input map (ADR not yet written) — exact button bindings unresolved | Low | Input Map GDD (not yet authored); blocks only gamepad-specific Prana Grid implementation |
