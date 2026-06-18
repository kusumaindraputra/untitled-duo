# Story 002: SceneManager and main.tscn Infrastructure

> **Epic**: Game State & Scene Flow
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: S (2–3 hours)
> **Manifest Version**: 2026-05-30
> **Last Updated**: 2026-05-30

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirements**: `TR-GSF-003`, `TR-GSF-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Persistent HUD via Sub-Scene Swap
**ADR Decision Summary**: `main.tscn` is the permanent root scene (set as Project Main Scene). CombatHUD lives as a CanvasLayer (layer 10) child of `main.tscn` and is never unloaded. SceneManager swaps sub-scenes (arena rooms) as children of a `SubSceneRoot` node on `main.tscn`, using `await get_tree().process_frame` between `queue_free()` and `add_child()`.

**Secondary ADR**: ADR-0002: Autoload Architecture — SceneManager is Autoload position 4, registered after GameStateManager (position 3). SceneManager connects to GameStateManager signals in `_ready()`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `await get_tree().process_frame` frame boundary between `queue_free()` and `add_child()` is required — `queue_free()` defers removal to end-of-frame; adding the new scene in the same frame causes both old and new to coexist briefly. `change_scene_to_file()` is explicitly forbidden (destroys the root and loses HUD). No breaking changes to these APIs in Godot 4.4–4.6.

**Control Manifest Rules (Foundation Layer)**:
- Required: `main.tscn` is the project Main Scene (Project Settings → Application → Run). It is the permanent root and is never unloaded. (ADR-0005)
- Required: CombatHUD lives in CanvasLayer layer 10 on `main.tscn`. `process_mode = PROCESS_MODE_ALWAYS`. (ADR-0005)
- Required: `SceneManager.change_room()` must `await get_tree().process_frame` between `queue_free()` and `add_child()`. (ADR-0005, TR-GSF-003)
- Required: Register at Autoload position 4 in Project Settings. (ADR-0002)
- Forbidden: Never use `change_scene_to_file()` — destroys the root and loses HUD. (ADR-0005)
- Forbidden: Never reinstantiate CombatHUD on room load. (ADR-0005)
- Forbidden: Never set CombatHUD as an Autoload. (ADR-0005)
- Forbidden: No `class_name` declaration on Autoload scripts. (ADR-0002)

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] `main.tscn` exists as the project Main Scene (Project Settings → Application → Run → Main Scene)
- [ ] `main.tscn` has a permanent CanvasLayer node (layer 10) as a child — placeholder for CombatHUD (can be empty at this story; HUD is implemented in CombatHUD epic)
- [ ] `main.tscn` has a `SubSceneRoot` node (plain Node2D) as a child — this is where SceneManager swaps arena rooms in and out (TR-GSF-004)
- [ ] `src/core/scene_manager.gd` exists — no `class_name` declaration; registered as Autoload position 4
- [ ] `change_room(scene: PackedScene) -> void` method implemented with `await get_tree().process_frame` between `queue_free()` and `add_child()` (TR-GSF-003)
- [ ] **TR-GSF-003**: A new sub-scene's `_ready()` is NOT called in the same frame as the previous sub-scene's `queue_free()` — verified by integration test
- [ ] **TR-GSF-004**: CanvasLayer (layer 10) node on `main.tscn` remains in the scene tree before and after a `change_room()` call — `is_inside_tree()` returns true at both points
- [ ] Re-entrancy guard on `change_room()` — second call while a swap is in progress is rejected with `push_error()` (GDD Core Rule: re-entrancy extends to SceneManager)
- [ ] SceneManager connects to `GameStateManager.state_changed` in `_ready()` — drives room loads reactively (ADR-0003)
- [ ] **AC-08** (manual): Full MVP playthrough — HUD node present in scene tree at every state transition; health and Prana display values correct at each transition

---

## Implementation Notes

*Derived from ADR-0005 and ADR-0002 Implementation Guidelines:*

**`main.tscn` scene tree structure:**
```
main.tscn (root: Node)
├── CanvasLayer (layer = 10, process_mode = PROCESS_MODE_ALWAYS)  ← CombatHUD placeholder
└── SubSceneRoot (Node2D)  ← arena room swapped here
```

**SceneManager skeleton:**
```gdscript
extends Node

var _current_scene: Node = null
var _is_swapping: bool = false

func _ready() -> void:
    GameStateManager.state_changed.connect(_on_state_changed)

func change_room(scene: PackedScene) -> void:
    if _is_swapping:
        push_error("[SceneManager] change_room() called while swap in progress — rejected")
        return
    _is_swapping = true
    var sub_root := get_node("/root/main/SubSceneRoot")
    if _current_scene != null:
        _current_scene.queue_free()
        _current_scene = null
        await get_tree().process_frame  # TR-GSF-003: frame boundary required
    _current_scene = scene.instantiate()
    sub_root.add_child(_current_scene)
    _is_swapping = false
```

**Integration test approach**: Use two minimal test scenes (`TestSceneA.tscn`, `TestSceneB.tscn`). Call `change_room(TestSceneB)` while `TestSceneA` is loaded. Use `await get_tree().process_frame` in the test to confirm `TestSceneA` is fully removed before `TestSceneB._ready()` fires. Check CanvasLayer node remains in tree throughout.

**Note**: The CombatHUD itself is implemented in the CombatHUD epic — this story only creates the placeholder CanvasLayer node on `main.tscn` and verifies it survives room transitions.

---

## Out of Scope

*Handled by neighbouring stories or other epics:*

- Story 001: GameStateManager state machine — the signals SceneManager reacts to
- Story 003: IsometricRoom — the actual arena scene loaded via `change_room()`
- CombatHUD epic: populating the CanvasLayer placeholder with actual HUD nodes

---

## QA Test Cases

*Integration story — automated integration test specs.*

- **AC-1**: `change_room()` frame boundary (TR-GSF-003)
  - Given: `SubSceneRoot` has `TestSceneA` as child; frame-order recorder attached
  - When: `change_room(TestSceneB)` called; `await get_tree().process_frame` in test
  - Then: `TestSceneA._exit_tree()` fires before `TestSceneB._ready()` fires — no same-frame coexistence
  - Edge cases: `_current_scene` is null after `queue_free()` and before `add_child()`

- **AC-2**: Persistent HUD survives room swap (TR-GSF-004)
  - Given: `main.tscn` loaded; CanvasLayer (layer 10) present and `is_inside_tree() = true`
  - When: `change_room(TestSceneB)` called; `await get_tree().process_frame`
  - Then: CanvasLayer node is still `is_inside_tree() = true`; its `get_child_count()` is unchanged

- **AC-3**: Re-entrancy guard on `change_room()`
  - Given: `change_room()` called (swap in progress via yield/await)
  - When: second `change_room()` call made before first completes
  - Then: second call rejected; `push_error()` called; only first swap completes

- **AC-4**: Manual walkthrough — AC-08 (Advisory)
  - Setup: Run game from editor through full MVP loop: MAIN_MENU → PREPARATION_PHASE → COMBAT_PHASE (regular wave + boss) → RUN_SUMMARY or DEATH_SCREEN
  - Verify: CanvasLayer (HUD placeholder) node is present at every state; `is_inside_tree()` = true logged at each transition
  - Pass condition: No null dereferences on HUD node; no HUD flicker or disappearance

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/game-state-scene-flow/scene_manager_test.gd` — must exist and all tests pass; plus AC-08 manual walkthrough doc at `production/qa/evidence/scene-manager-hud-walkthrough.md`

**Status**: [x] Created — see Completion Notes

---

## Dependencies

- Depends on: Story 001 (GameStateManager must be registered at position 3 before SceneManager at position 4; SceneManager connects to GSM signals)
- Unlocks: Story 003 — IsometricRoom (SceneManager's `change_room()` is what loads the arena scene); all arena-bound epics that assume a working scene-swap infrastructure

---

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 9/10 passing (AC-08 manual deferred — CombatHUD epic not started; test before sprint close-out)
**Deviations**: ADVISORY — ADR-0005 refers to `SubSceneContainer`; implementation uses `SubSceneRoot` per story ACs. One-line ADR text revision recommended.
**Test Evidence**: Integration test at `tests/integration/game-state-scene-flow/scene_manager_test.gd` (15 tests — 3 added during code review to cover TR-GSF-003 frame-ordering, async re-entrancy, and mid-swap null window). Manual walkthrough (`production/qa/evidence/scene-manager-hud-walkthrough.md`) not yet created — deferred.
**Code Review**: Ran this session → CHANGES REQUIRED → all 4 required fixes applied. Full re-run before sprint close-out.
