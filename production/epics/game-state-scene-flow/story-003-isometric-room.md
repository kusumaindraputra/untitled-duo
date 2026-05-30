# Story 003: IsometricRoom Scene Root

> **Epic**: Game State & Scene Flow
> **Status**: Blocked
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: S (2–3 hours)
> **Manifest Version**: 2026-05-30
> **Last Updated**: —

## ⚠️ BLOCKED

**Blocker**: ADR-0001 validation test (QQ-01) — TileMapLayer isometric rendering with Compatibility renderer in Godot 4.6 is NOT yet verified. This story MUST NOT be started until the throwaway validation project is run and results documented.

**Verification procedure** (from ADR-0001):
1. Create a throwaway Godot 4.6 project (Compatibility renderer)
2. Add a `TileMapLayer` node with `tile_shape = TileSet.TILE_SHAPE_ISOMETRIC` and tile size `64×32`
3. Enable `y_sort_enabled = true` on the parent `Node2D`
4. Confirm isometric tile rendering works correctly in the Compatibility renderer on Windows
5. Document result in `docs/architecture/adr-0001-isometric-view.md` Validation section
6. Update `production/session-state/active.md` QQ-01 item to resolved

**Unblock condition**: ADR-0001 validation test passed and documented.

---

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirements**: TR-ID not yet registered — ⚠️ Warning: no `TR-GSF-*` entry covers IsometricRoom specifically. The TR registry covers GameStateManager and SceneManager behavior (TR-GSF-001–008). IsometricRoom may need a `TR-GSF-009` entry added to `docs/architecture/tr-registry.yaml` before this story is closed.

**ADR Governing Implementation**: ADR-0001: Isometric 2D View
**ADR Decision Summary**: IsometricRoom uses `TileMapLayer` with `TileSet.TILE_SHAPE_ISOMETRIC` and tile size `64×32`. The parent `Node2D` has `y_sort_enabled = true`. Gameplay logic stays in 2D cartesian coordinates; isometric projection is rendering-only. All entity sprites must be children of a `y_sort_enabled = true` ancestor.

**Secondary ADRs**: ADR-0002 (IsometricRoom is a scene node, not an Autoload), ADR-0005 (IsometricRoom is loaded into `SubSceneRoot` via `SceneManager.change_room()`)

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: ⚠️ `TileMapLayer` replaced deprecated `TileMap` since Godot 4.3 — do NOT use `TileMap`. `TileSet.TILE_SHAPE_ISOMETRIC` and `y_sort_enabled` are the correct Godot 4.6 APIs but have NOT been verified against the Compatibility renderer for this project. The LLM's knowledge predates Godot 4.4–4.6; cross-reference `docs/engine-reference/godot/` before implementing any TileMapLayer or isometric-projection API call. `YSort` node is deprecated since Godot 4.0 — use `Node2D.y_sort_enabled = true` property instead.

**Control Manifest Rules (Foundation Layer)**:
- Required: Use `TileMapLayer` with `TileSet.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC`. (ADR-0001)
- Required: Enable `Node2D.y_sort_enabled = true` on IsometricRoom root and any parent of entity sprites. (ADR-0001)
- Required: Tile size `64×32 px` (2:1 dimetric). Sprite target: `32–48 px` tall. (ADR-0001)
- Required: Movement input is screen-space — WASD = screen up/down/left/right, not isometric grid directions. (ADR-0001)
- Forbidden: Never use `TileMap` (deprecated since 4.3). (ADR-0001)
- Forbidden: Never use `YSort` node (deprecated since 4.0) — use `Node2D.y_sort_enabled` property. (ADR-0001)
- Forbidden: Never put gameplay logic in isometric projection coordinates. (ADR-0001)

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md` and ADR-0001, scoped to this story:*

- [ ] **Prerequisite**: ADR-0001 validation test (QQ-01) completed and result documented — blocks scene authoring
- [ ] `scenes/IsometricRoom.tscn` exists; root node is `Node2D` with `y_sort_enabled = true`
- [ ] Scene contains a `TileMapLayer` child node with `TileSet.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC` and tile size `Vector2i(64, 32)`
- [ ] Scene contains spawn marker nodes (plain `Marker2D` or `Node2D`) at authored positions; exposed via `get_spawn_markers() -> Array[Vector2]` on a root script
- [ ] `get_spawn_markers()` returns at least 3 positions (one per MVP enemy archetype spawn zone)
- [ ] IsometricRoom scene loads correctly via `SceneManager.change_room()` — no null errors on startup
- [ ] A placeholder 2D sprite (CharacterBody2D child) placed in the room sorts correctly behind/in-front of tile features based on Y position — visual verification
- [ ] `IsometricRoom.tscn` is NOT registered as an Autoload (scene-local lifecycle only, per ADR-0002)

---

## Implementation Notes

*Derived from ADR-0001 Implementation Guidelines:*

**Scene structure:**
```
IsometricRoom.tscn (root: Node2D, y_sort_enabled = true)
├── TileMapLayer (tile_shape = TILE_SHAPE_ISOMETRIC, tile_size = Vector2i(64, 32))
├── SpawnMarkers (Node2D)
│   ├── SpawnZone_A (Marker2D)
│   ├── SpawnZone_B (Marker2D)
│   └── SpawnZone_C (Marker2D)
└── EntityLayer (Node2D, y_sort_enabled = true)  ← enemy/player nodes added here
```

**Root script:**
```gdscript
extends Node2D

func get_spawn_markers() -> Array[Vector2]:
    var markers: Array[Vector2] = []
    for child in $SpawnMarkers.get_children():
        if child is Marker2D:
            markers.append(child.global_position)
    return markers
```

**Isometric coordinate note**: Position entities in 2D cartesian space (screen X/Y). The `TileMapLayer` handles rendering projection. Do NOT convert entity positions to isometric grid coordinates for gameplay logic.

**Y-sort**: `y_sort_enabled = true` on the root `Node2D` and the `EntityLayer` Node2D ensures sprites sort by their global Y position, producing correct overlap behavior in isometric projection.

**TileMapLayer tileset**: At MVP scope, author a minimal placeholder tileset with the correct `TILE_SHAPE_ISOMETRIC` + `64×32` shape. Final art tileset will be provided by the art team and swapped in without code changes.

---

## Out of Scope

*Handled by neighbouring stories or other epics:*

- Story 001: GameStateManager — state signals that trigger room loads
- Story 002: SceneManager — `change_room()` that loads this scene
- Enemy AI epic: spawn logic that reads `get_spawn_markers()` positions
- Art pipeline: final tileset art asset authoring
- ADR-0001 verification: throwaway test project (must be done BEFORE this story)

---

## QA Test Cases

*Integration story — mix of automated and manual verification.*

- **AC-1**: IsometricRoom loads without errors
  - Given: `SceneManager.change_room(IsometricRoom)` called from a test harness
  - When: scene loads and `await get_tree().process_frame`
  - Then: no `push_error()` output; `IsometricRoom` instance `is_inside_tree() = true`

- **AC-2**: `get_spawn_markers()` returns valid positions
  - Given: IsometricRoom loaded
  - When: `get_spawn_markers()` called
  - Then: returns `Array[Vector2]` with `len >= 3`; no null entries
  - Edge cases: All positions are non-zero (markers are actually placed in the scene, not at origin)

- **AC-3**: TileMapLayer isometric configuration
  - Given: IsometricRoom loaded; grab TileMapLayer reference
  - When: reading `tile_set.tile_shape` and `tile_set.tile_size`
  - Then: `tile_shape == TileSet.TILE_SHAPE_ISOMETRIC`; `tile_size == Vector2i(64, 32)`

- **AC-4**: Y-sort visual verification (manual — Advisory)
  - Setup: Add two test sprites at different Y positions in `EntityLayer`
  - Verify: sprite at higher Y (further from camera in isometric view) renders behind sprite at lower Y
  - Pass condition: Overlap order is correct for isometric perspective; no z-fighting or incorrect layering

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/game-state-scene-flow/isometric_room_test.gd` — must exist and pass; plus AC-4 visual evidence at `production/qa/evidence/isometric-room-ysort-evidence.md`

**Status**: [ ] Not yet created — BLOCKED on ADR-0001 validation

---

## Dependencies

- Depends on: Story 002 (SceneManager `change_room()` must exist to load this scene); ADR-0001 validation test PASSED (QQ-01 resolved)
- Unlocks: Enemy AI epic (spawn markers are what WaveManager uses); Player Controller epic (IsometricRoom is the scene the player moves through)
