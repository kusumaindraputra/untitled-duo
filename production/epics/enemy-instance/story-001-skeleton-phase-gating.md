# Story 001: Scene Skeleton, Group, init(), Phase Gating

> **Epic**: Enemy Instance
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: ~2.5h
> **Manifest Version**: 2026-05-30
> **Last Updated**: 2026-05-31

## Context

**GDD**: `design/gdd/enemy-ai.md`
**Requirement**: `TR-EAI-001`, `TR-EAI-002`, `TR-EAI-005`, `TR-EAI-007`

**ADR Governing Implementation**: ADR-0003: Signal-Driven Architecture
**ADR Decision Summary**: Connect to `GameStateManager.combat_started` and `GameStateManager.preparation_started` in `_ready()`. State transitions (combat_active flag) are signal-driven. Disconnect in `_exit_tree()`.

**Secondary ADRs**: ADR-0002 (Autoload access from `_ready()` only), ADR-0010 (`add_to_group(&"enemy")`), ADR-0007 (register via WaveManager before add_child — init() is the runtime contract)

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `CharacterBody2D`, `Area2D`, `PROCESS_MODE_PAUSABLE`, `add_to_group()` all stable.

**Control Manifest Rules (Core layer)**:
- Required: `add_to_group(&"enemy")` in `_ready()`.
- Required: `PROCESS_MODE_PAUSABLE` (pausing freezes contact timer + movement automatically).
- Required: Connect to signals in `_ready()`, disconnect in `_exit_tree()`.
- Forbidden: Never add to both `&"player"` and `&"enemy"` groups.
- Forbidden: Never access Autoloads in `_init()`.

---

## Acceptance Criteria

- [ ] **AC-EAI-01** — GIVEN an enemy instance added to scene tree, WHEN `process_mode` read, THEN equals `PROCESS_MODE_PAUSABLE`.
- [ ] **AC-EAI-02** — GIVEN enemy instance in scene tree, WHEN node tree inspected, THEN a child `Area2D` (named `HitArea`) with its own `CollisionShape2D` exists, structurally separate from the root `CollisionShape2D`.
- [ ] **AC-EAI-03a** — GIVEN `init(0)` called (Drifter), THEN `_archetype == SEEKER`, `_base_damage == 8.0`, `_move_speed == 80.0`.
- [ ] **AC-EAI-03b** — GIVEN `init(1)` called (Charger), THEN `_archetype == RUSHER`, `_base_damage == 20.0`, `_move_speed == 50.0`.
- [ ] **AC-EAI-03c** — GIVEN `init(2)` called (Cluster), THEN `_archetype == SWARMER`, `_base_damage == 4.0`, `_move_speed == 70.0`.
- [ ] **AC-EAI-04** — GIVEN `_combat_active = false`, WHEN `_physics_process(delta)` runs, THEN `velocity == Vector2.ZERO`.
- [ ] **AC-EAI-05** — GIVEN `_state == DEAD` AND `_combat_active = true`, WHEN `_physics_process(delta)` runs, THEN `velocity == Vector2.ZERO` (DEAD takes precedence).
- [ ] **AC-EAI-06** — GIVEN `_combat_active = false` and valid Fayde ref, WHEN `combat_started` fires, THEN `_combat_active = true` and next `_physics_process` produces non-zero velocity.
- [ ] **AC-EAI-18** — GIVEN enemy after `_ready()`, WHEN `is_in_group("enemy")` called, THEN returns `true`.
- [ ] **AC-EAI-19** — GIVEN enemy after `_ready()`, WHEN `is_in_group("player")` called, THEN returns `false`.

---

## Implementation Notes

**Class skeleton:**
```gdscript
class_name EnemyInstance
extends CharacterBody2D

enum EnemyState { CHASING, DEAD }

var _state: EnemyState = EnemyState.CHASING
var _combat_active: bool = false
var _archetype: GameEnums.EnemyArchetype = GameEnums.EnemyArchetype.SEEKER
var _base_damage: float = 0.0
var _move_speed: float = 0.0
var _fayde_ref: Node = null
var _dir_last_valid: Vector2 = Vector2.RIGHT
var _fayde_in_contact: bool = false
var _contact_timer: float = 0.0

const ENEMY_MIN_CONTACT_INTERVAL: float = 0.3

func _ready() -> void:
    process_mode = PROCESS_MODE_PAUSABLE
    add_to_group(&"enemy")
    GameStateManager.combat_started.connect(_on_combat_started)
    GameStateManager.preparation_started.connect(_on_preparation_started)
    HealthAndDamage.enemy_killed.connect(_on_enemy_killed)
    _fayde_ref = get_tree().get_first_node_in_group(&"player")

func _exit_tree() -> void:
    if GameStateManager.combat_started.is_connected(_on_combat_started):
        GameStateManager.combat_started.disconnect(_on_combat_started)
    if GameStateManager.preparation_started.is_connected(_on_preparation_started):
        GameStateManager.preparation_started.disconnect(_on_preparation_started)
    if HealthAndDamage.enemy_killed.is_connected(_on_enemy_killed):
        HealthAndDamage.enemy_killed.disconnect(_on_enemy_killed)

func init(enemy_type_id: int) -> void:
    var et := EnemyCatalog.get_type(enemy_type_id)
    _archetype = et.archetype
    _base_damage = et.base_damage
    _move_speed = et.base_move_speed

func _on_combat_started(_is_boss: bool = false) -> void:
    _combat_active = true

func _on_preparation_started(_wave_index: int = 0, _waves_remaining: int = 0) -> void:
    _combat_active = false
    velocity = Vector2.ZERO
    _contact_timer = 0.0

func _physics_process(_delta: float) -> void:
    if not _combat_active or _state == EnemyState.DEAD:
        velocity = Vector2.ZERO
        return
    # Movement and contact (Stories 002–003)
```

**Note on `init()` vs `_ready()`**: WaveManager calls `register_enemy(enemy, type_id)` on H&D BEFORE `add_child()`, then calls `init(type_id)` AFTER `add_child()` per ADR-0014. The `_fayde_ref` lookup in `_ready()` is safe — WaveManager spawns enemies after `combat_started` fires, so `_fayde_ref` will resolve correctly.

---

## Out of Scope

- Story 002: Movement vector computation
- Story 003: Area2D contact callbacks
- Story 004: Death signal handler

---

## QA Test Cases

**AC-EAI-01 — PROCESS_MODE_PAUSABLE**
- Given: `EnemyInstance` instantiated and `add_child(enemy)` called in test scene
- When: `enemy.process_mode` read
- Then: Equals `Node.PROCESS_MODE_PAUSABLE`

**AC-EAI-02 — Area2D child exists**
- Given: Enemy instance in scene tree
- When: `enemy.get_node_or_null("HitArea")` called
- Then: Returns non-null `Area2D` node with a `CollisionShape2D` child; root `CollisionShape2D` also exists at root level (distinct from HitArea's child)

**AC-EAI-03a/b/c — init() caches catalog data**
- Given: EnemyCatalog autoload available with IDs 0/1/2
- When: `enemy.init(0)` / `init(1)` / `init(2)` called
- Then: `_archetype`, `_base_damage`, `_move_speed` match Enemy Data spec (8.0/80.0, 20.0/50.0, 4.0/70.0)
- Edge cases: init() with invalid ID should push_error (guard in EnemyCatalog.get_type)

**AC-EAI-04 — DISABLED blocks movement**
- Given: `_combat_active = false`; `_fayde_ref` points to a mock node at (100, 0)
- When: `_physics_process(1.0/60.0)` called
- Then: `velocity == Vector2.ZERO`

**AC-EAI-05 — DEAD takes precedence over combat_active**
- Given: `_state = DEAD`; `_combat_active = true`; `_fayde_ref` valid
- When: `_physics_process(1.0/60.0)` called
- Then: `velocity == Vector2.ZERO`

**AC-EAI-06 — combat_started enables movement**
- Given: `_combat_active = false`; Fayde mock at (100, 0); enemy at (0, 0)
- When: `_on_combat_started()` called; then `_physics_process(1.0/60.0)`
- Then: `velocity.length() > 0`

**AC-EAI-18/19 — Group membership**
- Given: Enemy `_ready()` called
- When: `is_in_group("enemy")` and `is_in_group("player")` checked
- Then: `true` and `false` respectively

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/enemy-instance/enemy_instance_skeleton_test.gd` — must pass headless

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (first story in this epic; H&D Story 001 should be DONE for register_enemy contract)
- Unlocks: Story 002 (movement), Story 003 (contact), Story 004 (death signal handler)
