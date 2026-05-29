# ADR-0005: Persistent HUD via Sub-Scene Swap

## Status
Accepted

## Date
2026-05-29

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (Scene Management / CanvasLayer) |
| **Knowledge Risk** | LOW — CanvasLayer, `PROCESS_MODE_ALWAYS`, PackedScene.instantiate() unchanged since Godot 4.0 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | `PackedScene.instantiate()` (renamed from `instance()` in 4.0 — in training data) |
| **Verification Required** | None — CanvasLayer persistence across sub-scene swaps is stable Godot behavior |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Accepted) — SceneManager is an Autoload that executes the sub-scene swap |
| **Enables** | SceneManager implementation; CombatHUD implementation |
| **Blocks** | SceneManager coding; any story that involves room transitions |
| **Ordering Note** | Must be Accepted before SceneManager.gd or main.tscn are created |

## Context

### Problem Statement

The game has two UI elements that must persist across room-to-room transitions: CombatHUD (HP bar, damage numbers, chain indicator) and PranaGrid (slot arrangement). When SceneManager loads a new room (a different IsometricRoom scene), any nodes that live inside the departing scene are freed. Without an explicit strategy, the HUD would be destroyed and re-instantiated on every room load — causing flicker, loss of accumulator state (active Regen display, ongoing chain indicators), and additional startup cost.

### Constraints

- Engine: Godot 4.6, Compatibility renderer
- Game has no persistent world state between rooms at MVP — only the HUD UI persists
- SceneManager must swap room scenes without triggering a full screen black-out or reload
- CombatHUD must be `PROCESS_MODE_ALWAYS` to display the pause overlay while `get_tree().paused = true`
- PranaGrid state must reset between rooms (new wave = new arrangement)

### Requirements

- CombatHUD survives every room transition
- PranaGrid does NOT survive room transitions (state intentionally resets per run)
- Room loading must not cause a visible flash or frame skip
- Architecture must be simple enough to implement solo in < 1 sprint

## Decision

The **main scene** (`src/scenes/main.tscn`) is a permanent root scene that is never unloaded. It contains:

```
Main (Node)
├── SubSceneContainer (Node2D)        ← rooms load/unload here
│   └── [current IsometricRoom]       ← replaced on room transition
├── CanvasLayer (layer 10)            ← HUD root — never moves
│   └── CombatHUD (Control)           ← PROCESS_MODE_ALWAYS
└── [PranaGrid lives inside IsometricRoom ← resets on transition]
```

SceneManager's `change_room(packed_scene: PackedScene)` performs the swap:

```gdscript
func change_room(packed_scene: PackedScene) -> void:
    var old_scene: Node = _sub_scene_container.get_child(0) if \
        _sub_scene_container.get_child_count() > 0 else null

    if old_scene:
        old_scene.queue_free()
        await get_tree().process_frame  # wait one frame for free to propagate

    var new_scene: Node = packed_scene.instantiate()
    _sub_scene_container.add_child(new_scene)
```

### PranaGrid Position

PranaGrid lives inside `IsometricRoom.tscn` as a CanvasLayer child of the room root. This ensures PranaGrid state resets with each new room. GameStateManager's `preparation_started` signal clears the grid arrangement at the start of each wave regardless — PranaGrid reset is redundant but harmless.

### HUD CanvasLayer Assignment

CombatHUD occupies CanvasLayer layer 10 (`LAYER_HUD = 10`). Layer assignment:

| Layer | Content |
|-------|---------|
| 0 (default) | Game world — IsometricRoom, entities |
| 1 | PranaGrid (inside IsometricRoom's CanvasLayer child) |
| 10 | CombatHUD (Main.CanvasLayer) |
| 128 (future) | Debug overlays |

### Scene Root Architecture

```
main.tscn (permanent root — never freed)
├── SubSceneContainer (Node2D, PROCESS_MODE_INHERIT)
│   └── IsometricRoom.tscn (loaded by SceneManager)
│       ├── TileMapLayer (floor, walls)
│       ├── SpawnMarkers (Node2D children)
│       ├── PlayerController (CharacterBody2D)
│       ├── WaveManager (Node)
│       └── CanvasLayer (layer 1)
│           └── PranaGrid (Control)
└── CanvasLayer (layer 10, PROCESS_MODE_ALWAYS)
    └── CombatHUD (Control)
```

## Alternatives Considered

### Alternative B: Single Scene (Everything Together)

- **Description**: All entities, HUD, and room content live in one scene. Room changes swap out only the room's tile/entity children, leaving HUD nodes in place.
- **Pros**: Simpler scene hierarchy; no SceneManager needed
- **Cons**: Manual management of which nodes to free vs. keep on every room load; any mistake frees the HUD accidentally; does not scale to multiple rooms without significant refactoring
- **Rejection Reason**: Brittle at scale; sub-scene swap achieves the same isolation without manual management

### Alternative C: Autoload HUD

- **Description**: CombatHUD is instantiated by an Autoload and added to the viewport as a CanvasLayer child of the Autoload node.
- **Pros**: HUD is guaranteed to exist from game start
- **Cons**: Autoloads extending `Node` (not `RefCounted`) add scene overhead; HUD as an Autoload child breaks the layer ordering guarantee; creates a two-Autoload dependency (HUD Autoload must connect to H&D, SC&E Autoloads)
- **Rejection Reason**: Unnecessary complexity. A CanvasLayer at layer 10 on the permanent main.tscn achieves identical behavior without Autoload overhead.

### Alternative D: Reinstantiate HUD on Every Room Load

- **Description**: SceneManager destroys and recreates CombatHUD with each room load.
- **Pros**: Simple — no persistent root scene needed
- **Cons**: Visible flicker on recreate; loses accumulator state (ongoing damage number animations, active chain indicators); additional instantiation cost per room
- **Rejection Reason**: Flicker is a UX failure. Accumulator loss is a correctness failure for active effects during transition.

## Consequences

### Positive

- CombatHUD node lifetime is the session lifetime — no risk of freed HUD
- `PROCESS_MODE_ALWAYS` on CombatHUD ensures it renders even during pause
- Room transitions are instantaneous from the player's perspective (one-frame gap)
- SceneManager is the single authority for room swaps — all other systems connect to GSM signals

### Negative

- `main.tscn` is a permanent dependency — it must be the project's `Main Scene` in Project Settings
- `await get_tree().process_frame` in `change_room()` introduces a one-frame gap — this is intentional and must not be awaited from `_ready()` callbacks that expect instant transitions

### Risks

- **Risk**: Developer sets a different scene as the Main Scene, bypassing main.tscn.
  **Mitigation**: Document in CLAUDE.md or project setup guide. One-time setup; unlikely to change.
- **Risk**: `queue_free()` + same-frame `add_child()` of new room causes a one-frame flicker.
  **Mitigation**: `await get_tree().process_frame` between free and add ensures the freed scene is fully removed before the new scene's `_ready()` runs. Add a black fade-out/fade-in tween in CombatHUD if visible gap is objectionable (deferred to Game Feel / Juice sprint).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| game-state-scene-flow.md | TR-GSF-007: Scene transitions must not destroy the CombatHUD | CanvasLayer(10) on permanent main.tscn root — never freed |
| game-state-scene-flow.md | TR-GSF-009: CombatHUD must be visible and responsive during PREPARATION and COMBAT phases | `PROCESS_MODE_ALWAYS` on CombatHUD CanvasLayer; layer 10 renders above all game content |
| combat-hud.md | TR-CH-001: HP bar and chain indicators must survive room transitions without flickering | CombatHUD persistence — never reinstantiated |

## Performance Implications

- **CPU**: `queue_free()` + `instantiate()` per room transition — one-time cost, not per-frame
- **Memory**: CombatHUD node always allocated — negligible (< 1 KB for Control nodes)
- **Load Time**: `await get_tree().process_frame` adds exactly one frame (~16ms at 60fps) to room transition time — acceptable

## Validation Criteria

1. **AC-0005-01**: Transition from one IsometricRoom to another — CombatHUD node is the same instance before and after (same `get_instance_id()`)
2. **AC-0005-02**: During room transition, CombatHUD continues rendering (no single-frame null/blank frame visible at 60fps)
3. **AC-0005-03**: PranaGrid `committed_fragments` array is empty after room load — state correctly reset
4. **AC-0005-04**: `get_tree().paused = true` — CombatHUD `_process()` continues running; IsometricRoom entities halt

## Related Decisions

- [ADR-0002: Autoload Architecture](adr-0002-autoload-architecture.md) — SceneManager is Autoload #4
- [ADR-0003: Signal-Driven Architecture](adr-0003-signal-driven-architecture.md) — SceneManager reacts to GSM signals, not direct calls
- [docs/architecture/architecture.md](../architecture.md) — Data Flow Scenario 5 (initialization order); Module Ownership (SceneManager, CombatHUD)
