# ADR-0002: Autoload Architecture and Registration Order

## Status
Accepted

## Date
2026-05-29

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (Autoload / Scene Tree) |
| **Knowledge Risk** | LOW — AutoLoad system unchanged since Godot 4.0; no breaking changes in 4.4–4.6 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Open Project Settings → AutoLoad after initial setup; confirm 11 entries in documented order |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | ADR-0003, ADR-0004, ADR-0005, ADR-0006 — all Foundation Layer ADRs build on knowing which systems are Autoloads |
| **Blocks** | All coding — no implementation sprint may begin without this order locked |
| **Ordering Note** | Must be Accepted before any Autoload `.gd` file is created. Changing registration order after files exist risks breaking `_ready()` signal connections already coded. |

## Context

### Problem Statement
The project has 11 global systems that must be accessible from any scene node at runtime and must survive scene transitions. Godot's AutoLoad system provides this, but without a document locking in (a) which systems are Autoloads vs. scene nodes, and (b) the exact registration order and the reasoning behind it, any developer reordering the Project Settings → AutoLoad entries will produce startup null crashes as downstream systems connect to signals before upstream systems have initialized.

### Constraints
- Godot 4.6: AutoLoad registration order is controlled through Project Settings → AutoLoad (UI panel — not version-controlled as plain text by default)
- All Autoloads are accessed from GDScript by `class_name` — no external dependency injection framework
- Unit tests (GUT) must be able to stub Autoload signals for isolated system testing
- Solo development context: no build tooling to enforce registration order automatically

### Requirements
- Must support the 11 global systems identified in architecture.md: PranaCatalog, EnemyCatalog, GameStateManager, SceneManager, AudioSystem, HealthAndDamage, StatusEffectsManager, CombinationResolution, SpellCastingEffects, SpellVFX, RunManager
- Must guarantee data catalogs (PranaCatalog, EnemyCatalog) are ready before any system that calls `get_type()` in its `_ready()`
- Must guarantee GameStateManager is ready before any system that connects to its signals in `_ready()`
- Must guarantee HealthAndDamage is ready before StatusEffectsManager (SEM calls `apply_damage()`)
- Scene nodes (PlayerController, PranaGrid, EnemyInstance, WaveManager, CombatHUD, IsometricRoom) must NOT be Autoloads — their lifetime is tied to the arena scene

## Decision

Use Godot's native AutoLoad system for exactly **11 global systems**. Register them in the fixed order below in Project Settings → AutoLoad. This order is the single authoritative initialization sequence for the project.

### Autoload vs. Scene Node Criteria

A system is an **Autoload** if it meets ALL of the following:
1. Must be accessible from scene nodes in any loaded scene (not just the arena)
2. Must survive scene transitions (room changes via SceneManager)
3. Does NOT have a lifetime tied to a specific scene

A system is a **scene node** if any of the following is true:
1. Its lifecycle is bound to the arena scene (spawned when the arena loads, freed when it unloads)
2. It is a visual/physics element (Control, CharacterBody2D) whose state resets between runs

### Autoload Registration Order

| # | Node Name | File | Reason for Position |
|---|-----------|------|---------------------|
| 1 | PranaCatalog | `src/data/prana_catalog.gd` | Data catalog — no dependencies; first because all Prana-aware systems depend on it |
| 2 | EnemyCatalog | `src/data/enemy_catalog.gd` | Data catalog — no dependencies; second for symmetry with PranaCatalog |
| 3 | GameStateManager | `src/core/game_state_manager.gd` | State machine — reads catalogs only at transition time (not at `_ready()`); must be ready before all signal subscribers (positions 4–11) |
| 4 | SceneManager | `src/core/scene_manager.gd` | Subscribes to GSM signals in `_ready()`; depends on GSM (position 3) |
| 5 | AudioSystem | `src/audio/audio_system.gd` | Subscribes to GSM signals in `_ready()`; depends on GSM (position 3) |
| 6 | HealthAndDamage | `src/systems/health_and_damage.gd` | Subscribes to GSM.`run_started` in `_ready()`; must be before StatusEffectsManager |
| 7 | StatusEffectsManager | `src/systems/status_effects_manager.gd` | Subscribes to H&D.`enemy_killed` in `_ready()`; depends on H&D (position 6) |
| 8 | CombinationResolution | `src/systems/combination_resolution.gd` | Subscribes to GSM.`combat_started` in `_ready()`; accesses PranaCatalog at init |
| 9 | SpellCastingEffects | `src/systems/spell_casting_effects.gd` | Subscribes to CombinationResolution.`combo_resolved` in `_ready()`; depends on CR (position 8) |
| 10 | SpellVFX | `src/ui/spell_vfx.gd` | Particle pool Autoload (ADR-0015); depends on PranaCatalog at init; no downstream Autoload depends on it |
| 11 | RunManager | `src/systems/run_manager.gd` | Subscribes to GSM run lifecycle signals; last — no downstream Autoload depends on it |

### Scene Node Systems (NOT Autoloads)

| Node | Why Scene-Local |
|------|-----------------|
| PlayerController | The duo's per-arena instance; freed on room change |
| PranaGrid | UI node bound to arena scene; state resets each run |
| EnemyInstance | Per-enemy node; spawned and freed within a wave |
| WaveManager | Encounter lifecycle tied to the arena scene |
| CombatHUD | CanvasLayer child of main scene root; re-instantiated with scene |
| IsometricRoom | The arena root itself |

### Key Interfaces and Lifecycle Rules

```gdscript
# ── SAFE: access Autoloads by class_name from any GDScript node ────────────
var prana_type = PranaCatalog.get_type(1)         # safe from _ready() onward
var state = GameStateManager.get_active_state()    # safe from _ready() onward

# ── SAFE: connect to Autoload signals in _ready() ──────────────────────────
func _ready() -> void:
    # GSM is registered at position 3; this Autoload is at position 6+ → safe
    GameStateManager.run_started.connect(_on_run_started)

# ── UNSAFE: do NOT access Autoload state in these contexts ─────────────────
func _init() -> void:
    PranaCatalog.get_type(1)   # WRONG — Autoloads not in tree yet during construction

# @export default expressions also run before the scene tree exists:
@export var bad: int = PranaCatalog.SOME_PROPERTY  # WRONG — crashes editor

# Static initializers run at parse time — same problem:
static var bad2: int = GameStateManager.get_active_state()  # WRONG
```

**Rules enforced by this ADR:**
1. Autoload `.gd` files **must NOT declare `class_name`**. Godot 4.6 rejects a `class_name` that matches the Autoload node name registered in Project Settings — the editor reports "class_name hides autoload singleton". Access all Autoloads via their Project Settings node name directly (e.g. `GameStateManager.get_active_state()`). *(Corrected in AV-6 — original Rule 1 was inverted.)*
2. Autoloads may only be accessed from `_ready()`, deferred calls, or signal handlers — never from `_init()`, `@export` default expressions, or static initializers.
3. No Autoload may call methods on a **higher-registered** Autoload during its own `_ready()`. Use signal connections for deferred communication.
4. Runtime child node instantiation inside Autoloads must use `call_deferred("add_child", node)` to avoid scene tree warnings during the AutoLoad initialization phase.

### Architecture Diagram

```
Project Settings → AutoLoad (initialization order)
┌──────────────────────────────────────────────────────────────┐
│  1. PranaCatalog     (data catalog, no deps)                 │
│  2. EnemyCatalog     (data catalog, no deps)                 │
│  3. GameStateManager (state machine, reads catalogs lazily)  │
│  4. SceneManager     (connects to GSM signals)               │
│  5. AudioSystem      (connects to GSM signals)               │
│  6. HealthAndDamage  (connects to GSM.run_started)           │
│  7. StatusEffectsManager (connects to H&D signals)           │
│  8. CombinationResolution (connects to GSM.combat_started)   │
│  9. SpellCastingEffects   (connects to CR.combo_resolved)    │
│ 10. SpellVFX         (particle pool; reads PranaCatalog)     │
│ 11. RunManager       (connects to GSM lifecycle signals)     │
└──────────────────────────────────────────────────────────────┘
                       ↓
All Autoloads complete _ready() → Main scene _ready() fires → safe
```

## Alternatives Considered

### Alternative B: SystemsRoot Scene Node
- **Description**: A dedicated `SystemsRoot.tscn` is the main scene. It manually adds all 10 global systems via `add_child()` in `_ready()` in the required order. Other scenes access systems via `get_node("/root/SystemsRoot/HealthAndDamage")`.
- **Pros**: Registration order is visible in a `.tscn` file under version control; no dependency on Project Settings UI
- **Cons**: `get_node()` path strings break on rename; runtime path lookup overhead; requires all consumers to know the exact tree path; not idiomatic Godot for global systems
- **Rejection Reason**: More boilerplate, more fragile, no safety advantage over AutoLoad. Godot's AutoLoad system is purpose-built for exactly this use case.

### Alternative C: ServiceLocator Autoload
- **Description**: A single `GameServices` Autoload provides `register_system(id: StringName, system: Node)` and `get_system(id: StringName) -> Node` APIs. All other "systems" are children of GameServices.
- **Pros**: Single root AutoLoad entry; adds a discovery layer that could help with testing
- **Cons**: Redundant in GDScript — `class_name` already provides type-safe, zero-cost singleton lookup; hides dependencies (systems appear decoupled but are coupled through the locator); service discovery is unnecessary for a statically-typed single-developer project
- **Rejection Reason**: Unnecessary indirection. The ServiceLocator pattern is useful in languages without global class access; GDScript `class_name` makes it redundant and adds no value here.

## Consequences

### Positive
- All 11 Autoloads complete `_ready()` before the main scene's `_ready()` runs — safe to call from any scene node's `_ready()`
- Project Settings → AutoLoad is the single source of truth for initialization sequence
- Autoloads persist across scene changes — no state loss during room transitions
- `class_name` access is a compile-time constant lookup — zero runtime overhead

### Negative
- Registration order lives in Project Settings (internal binary format) — not natively diff-able in Git without Godot's text-based project.godot format
- GDScript `class_name` access is global — no compile-time enforcement that a system isn't accessed before Autoloads are ready; lifecycle rules require discipline
- `extends Node` (not `extends RefCounted`) required for all Autoloads — slightly higher memory overhead than plain objects (negligible at 10 nodes)

### Risks
- **Risk**: Developer reorders AutoLoad entries in Project Settings → startup null crash.
  **Mitigation**: This ADR documents the canonical order. Onboarding checklist verifies order. Startup smoke test (AC-0002-01) detects crashes early.
- **Risk**: Scene node accesses an Autoload in `_init()` or an `@export` default expression before Autoloads are in the tree.
  **Mitigation**: Rule 2 above is enforced by code review and the CI grep invariant check for `_init()` → Autoload access patterns.
- **Risk**: New Autoload added without updating this document, silently breaking the dependency graph.
  **Mitigation**: Any new Autoload requires either a revision to this ADR or a superseding ADR. The 11-system list is exhaustive for First Playable / MVP scope.

## GDD Requirements Addressed

| GDD System | Requirement (TR ID) | How This ADR Addresses It |
|------------|---------------------|--------------------------|
| game-state-scene-flow.md | TR-GSF-008: GameStateManager is the sole authority for active game state; all systems observe it via signals | AutoLoad position 3 guarantees GSM is ready before all signal-subscribing systems (4–10) |
| game-state-scene-flow.md | TR-ENG-002: All global systems must survive scene transitions without reinitializing | AutoLoad lifecycle (nodes persist under SceneTree root) fulfills this |
| prana-data.md | TR-PD-001: PranaCatalog must be accessible from PranaGrid, CombinationResolution, and SpellCastingEffects at `_ready()` time | AutoLoad position 1 (first) guarantees availability |
| enemy-data.md | TR-ED-001: EnemyCatalog must be accessible from EnemyInstance.`init()` and WaveManager spawn logic | AutoLoad position 2 guarantees availability |
| run-management.md | TR-RM-001: RunManager must persist run state across scene transitions | AutoLoad lifecycle (persists across scene changes) fulfills this |
| spell-casting-effects.md | TR-SC-001: SpellCastingEffects must connect to CombinationResolution.`combo_resolved` at startup | AutoLoad position 9 (after CR at 8) guarantees the signal is available to connect in `_ready()` |
| status-effects.md | TR-SE-001: StatusEffectsManager must be able to call HealthAndDamage.`apply_damage()` immediately when a tick fires | AutoLoad position 7 (after H&D at 6) guarantees H&D exists and is initialized before SEM's `_ready()` |

## Performance Implications
- **CPU**: Negligible — 10 `_ready()` calls at project start; no per-frame cost from Autoload registration
- **Memory**: ~11 additional Node allocations at root level; unmeasurable for a project of this scale
- **Load Time**: < 1ms startup overhead from AutoLoad initialization
- **Network**: N/A

## Migration Plan
New project — no existing code to migrate. Developer action on initial project setup: open Project Settings → AutoLoad, add 10 entries in documented order using exact `class_name` values.

## Validation Criteria
1. **AC-0002-01**: Open Project Settings → AutoLoad; confirm 11 entries in documented order. Autoload `.gd` files must NOT declare `class_name` (Godot 4.6 constraint — see Rule 1)
2. **AC-0002-02**: Launch game from Godot editor; verify no `push_error()` or null-dereference errors in Output panel during startup
3. **AC-0002-03**: From the first loaded scene's `_ready()`, call `PranaCatalog.get_type(1)`; confirm it returns a valid `PranaType` (not null)
4. **AC-0002-04**: Call `GameStateManager.get_active_state()` from a scene node `_ready()`; confirm it returns `GameEnums.GameState.MAIN_MENU`

## Related Decisions
- [ADR-0001: Isometric 2D View](adr-0001-isometric-view.md) — independent decision; no ordering constraint
- [ADR-0003: Signal-Driven Architecture](adr-0003-signal-driven-architecture.md) — builds on this: signals are the only communication channel between Autoloads
- [ADR-0006: GameEnums as Pure Enum Container](adr-0006-game-enums-container.md) — GameEnums uses `extends RefCounted` and is NOT an AutoLoad; this decision confirms that distinction
- [docs/architecture/architecture.md](../architecture.md) — System Layer Map and AutoLoad registration order source
