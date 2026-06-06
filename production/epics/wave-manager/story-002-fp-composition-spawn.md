# Story 002: FP Wave Composition and Spawn Sequence

> **Epic**: WaveManager
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: ~3 hours
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-06

## Context

**GDD**: `design/gdd/wave-encounter-system.md`
**Requirement**: `TR-WES-002`, `TR-WES-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0014: H&D ↔ WaveManager Integration Contract
**ADR Decision Summary**: Spawn order is strictly `instantiate()` → `register_enemy()` → `add_child()` → `set global_position` → `init(type_id)`. `register_enemy()` must precede `add_child()` so H&D's HP pool is live before the enemy node's `_ready()` fires.

**Secondary ADR**: ADR-0007: HealthAndDamage Singleton — `register_enemy(enemy, type_id)` is H&D's API.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `PackedScene.instantiate()` (not deprecated `instance()`). `Node.add_child()` is synchronous — no deferred add for the spawn loop.

**Control Manifest Rules (Feature Layer)**:
- Required: `WaveManager calls HealthAndDamage.register_enemy(enemy, type_id)` before `add_child(enemy)` on every spawn
- Required: `EnemyType` resource includes `scene: PackedScene` field — WaveManager spawns via this field
- Required: WaveManager spawn order: `instantiate()` → `register_enemy()` → `add_child()` → `set global_position` → `init(type_id)`
- Forbidden: Never call `HealthAndDamage.register_enemy()` from `EnemyInstance._ready()`
- Forbidden: Never call `HealthAndDamage.unregister_enemy()` from WaveManager

---

## Acceptance Criteria

*From GDD `design/gdd/wave-encounter-system.md`, scoped to this story:*

- [ ] **AC-WES-01** — GIVEN the WaveManager script is loaded, WHEN `FP_DRIFTER_COUNT`, `FP_CHARGER_COUNT`, `FP_CLUSTER_COUNT` are read, THEN their values equal 3, 2, 5 respectively and sum to 10.
- [ ] **AC-WES-02** — GIVEN the FP composition array, WHEN each entry is validated against Enemy Data, THEN all `enemy_type_id` values exist in the EnemyCatalog with `status = active` AND `wave_threat_value` is not null.
- [ ] **AC-WES-03** — GIVEN the FP composition (3 Drifter + 2 Charger + 5 Cluster), WHEN the threat budget is calculated, THEN total = `(3×1) + (2×2) + (5×1) = 12`.
- [ ] **AC-WES-04** — GIVEN `combat_started(is_boss: false)` fires and the arena scene contains at least 10 spawn markers, WHEN the spawn loop completes, THEN exactly 10 enemy nodes are in the scene tree, `_enemies_alive = 10`, `_enemies_total = 10`, `_wave_state = WAVE_ACTIVE`. All 10 nodes added in the same frame (no deferred add).
- [ ] **AC-WES-05** — GIVEN an enemy node is added by WaveManager, WHEN `init(enemy_type_id)` is called on it, THEN the enemy's `_archetype`, `_base_damage`, `_move_speed` fields match the EnemyCatalog definition for that `enemy_type_id`.
- [ ] **AC-WES-06** — GIVEN the arena scene has fewer spawn markers than the composition count, WHEN the spawn loop runs, THEN `push_error()` is logged; the remaining enemies (up to marker count) are spawned; `_enemies_total` equals the number actually spawned (not the composition count).

---

## Implementation Notes

*Derived from ADR-0014 Implementation Guidelines:*

**FP composition constants** (tuning knobs — data-driven at MVP):
```gdscript
const FP_DRIFTER_COUNT: int = 3
const FP_CHARGER_COUNT: int = 2
const FP_CLUSTER_COUNT: int = 5

# Threat values per GDD Formula 1 (Drifter=1, Charger=2, Cluster=1)
const FP_DRIFTER_ID: int = 0
const FP_CHARGER_ID: int = 1
const FP_CLUSTER_ID: int = 2
```

**Composition array** is built in `_ready()` or `_on_preparation_started()` from the constants. Each entry is a Dictionary `{ "type_id": int, "scene": PackedScene }` loaded from EnemyCatalog.

**Spawn marker discovery**: The arena scene is expected to have a `SpawnPoints` container node with `Node2D` children `SP_01` through `SP_N`. WaveManager locates them via `get_node("../../SpawnPoints")` or an `@export var spawn_points_container: Node` reference set in the scene inspector. Read each child's `global_position` at spawn time (not cached — markers may not yet be in the world during `_ready()`).

**Strict spawn order (ADR-0014)**:
```gdscript
func _spawn_wave() -> void:
    var markers: Array = _get_spawn_markers()
    var spawn_idx: int = 0
    for entry in _wave_composition:
        if spawn_idx >= markers.size():
            push_error("WaveManager: fewer spawn markers (%d) than composition entries" % markers.size())
            break
        var enemy: Node = entry.scene.instantiate()
        HealthAndDamage.register_enemy(enemy, entry.type_id)  # BEFORE add_child
        add_child(enemy)
        enemy.global_position = markers[spawn_idx].global_position
        enemy.init(entry.type_id)
        spawn_idx += 1
    _enemies_total = spawn_idx
    _enemies_alive = _enemies_total
    if _enemies_total == 0:
        push_error("WaveManager: no enemies spawned — wave vacuously complete")
        _wave_state = WaveState.WAVE_COMPLETE
        emit_signal("all_waves_cleared")
        emit_signal("boss_defeated")
        return
    _wave_state = WaveState.WAVE_ACTIVE
```

**Note**: The zero-spawn guard (AC-WES-11) belongs in `_spawn_wave()`. It is listed here because the guard fires immediately after the spawn loop — it is tightly coupled to the spawn logic rather than the kill tracking logic.

**Integration test scene fixture**: `scene: PackedScene` is `null` in all enemy `.tres` files; `EnemyInstance.tscn` does not yet exist. The integration test MUST inject `_wave_composition` directly rather than relying on `EnemyCatalog.scene`. Use a minimal test fixture:

```gdscript
# In test setup — build a fake entry using the enemy_instance.gd script on a plain scene
var test_scene: PackedScene = load("res://tests/integration/wave-encounter-system/fixtures/EnemyTestScene.tscn")
wm._wave_composition = []
for i in range(10):
    wm._wave_composition.append({ "type_id": 0, "scene": test_scene })
```

Create `tests/integration/wave-encounter-system/fixtures/EnemyTestScene.tscn` as a minimal `CharacterBody2D` with `src/gameplay/enemy_instance.gd` attached. This fixture is reusable across Stories 002, 003, and 004. `EnemyInstance.tscn` (production scene) is out of scope for this story.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: Skeleton class, signal declarations, phase gating handlers (must be Done first)
- [Story 003]: `_on_enemy_killed()` body — kill tracking and completion signals

---

## QA Test Cases

*Written by QA lead at story creation. Implement against these — do not invent new test cases.*

**Test file**: `tests/integration/wave-encounter-system/wave_manager_spawn_test.gd`

- **AC-WES-01**: FP composition constants
  - Given: WaveManager script loaded
  - When: `FP_DRIFTER_COUNT`, `FP_CHARGER_COUNT`, `FP_CLUSTER_COUNT` are read
  - Then: Values are 3, 2, 5 respectively; sum equals 10
  - Edge cases: Constants are `const` (not `var`) — verify assignment is immutable

- **AC-WES-02**: Composition entries exist in EnemyCatalog
  - Given: FP composition array built from constants
  - When: Each entry's `type_id` is looked up in `EnemyCatalog`
  - Then: All 3 type IDs (0, 1, 2) exist with `status = active` and `wave_threat_value != null`
  - Edge cases: EnemyCatalog is an Autoload — access in integration test after scene tree ready

- **AC-WES-03**: Threat budget calculation
  - Given: FP composition (3 Drifter threat=1, 2 Charger threat=2, 5 Cluster threat=1)
  - When: Threat budget is summed: `(3×1) + (2×2) + (5×1)`
  - Then: Total equals 12
  - Edge cases: Verify Charger threat value is 2 (not 1) per GDD Formula 1 table correction (Ice/Deepfrost)

- **AC-WES-04**: Simultaneous spawn on `combat_started(false)`
  - Given: WaveManager added to scene tree with a SpawnPoints container containing ≥10 Node2D markers
  - When: `_on_combat_started(false)` called (or `GameStateManager.combat_started` emitted)
  - Then: Exactly 10 child nodes of type EnemyInstance added; `_enemies_alive == 10`; `_enemies_total == 10`; `_wave_state == WAVE_ACTIVE`; all additions in same frame (child count verified synchronously after call, not on next frame)
  - Edge cases: Verify `register_enemy()` called before `add_child()` by checking H&D enemy registry before and after `add_child()`

- **AC-WES-05**: `init(type_id)` called with correct type
  - Given: Spawn loop runs; 10 enemy nodes added
  - When: Each enemy's `_archetype`, `_base_damage`, `_move_speed` are read post-spawn
  - Then: Fields match EnemyCatalog definition for that enemy's assigned `type_id`
  - Edge cases: Composition order: first 3 are Drifter (ID 0), next 2 are Charger (ID 1), last 5 are Cluster (ID 2)

- **AC-WES-06**: Fewer spawn markers → partial spawn with push_error
  - Given: WaveManager with SpawnPoints container containing only 4 markers (fewer than 10)
  - When: `_on_combat_started(false)` called
  - Then: `push_error()` logged; exactly 4 enemy nodes added; `_enemies_total == 4` (not 10); `_wave_state == WAVE_ACTIVE`
  - Edge cases: `_enemies_alive` also equals 4 (not 10)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/wave-encounter-system/wave_manager_spawn_test.gd` — must exist and pass

**Status**: [x] PASSED — 8/8 tests, GdUnit4 v6.1.3 + Godot 4.6.2, 0 orphans (2026-06-06)

---

## Dependencies

- Depends on: Story 001 DONE (skeleton, signal handlers, `_spawn_wave()` stub must exist); EnemyInstance Story 001 DONE (`init(enemy_type_id)` method must exist on enemy scene)
- Unlocks: Story 004 (full run integration depends on spawn working correctly)

## Completion Notes

**Completed**: 2026-06-06
**Criteria**: 6/6 passing
**Deviations**:
- ADVISORY: AC-WES-03 threat budget test uses GDD-specified literals (1, 2, 1) — matches live `.tres` data today; migrate to catalog reads before Story 003 close-out
- ADVISORY: `register_enemy()` ordering (AC-WES-04 sub-criterion) unverifiable by automation — H&D has no registry introspection API; verified by ADR-0014 code review only; documented in test file comment
**Test Evidence**: Integration — `tests/integration/wave-encounter-system/wave_manager_spawn_test.gd` — 8/8 PASSED headless; fixture at `tests/integration/wave-encounter-system/fixtures/EnemyTestScene.tscn`
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (all required changes applied)
