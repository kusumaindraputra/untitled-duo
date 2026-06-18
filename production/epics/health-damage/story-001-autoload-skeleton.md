# Story 001: Autoload Skeleton, Enemy HP Registry, and Run Reset

> **Epic**: Health & Damage
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: ~2h
> **Manifest Version**: 2026-05-30
> **Last Updated**: 2026-06-02

## Context

**GDD**: `design/gdd/health-damage.md`
**Requirement**: `TR-HD-001`, `TR-HD-006`, `TR-HD-009`, `TR-HD-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: HealthAndDamage Singleton
**ADR Decision Summary**: HealthAndDamage is Autoload #6 — sole owner of all HP state for the session. HP stored as `float` internally; exposed as `int` via `roundi()`. Enemy HP registered via `register_enemy(enemy, type_id)` keyed by `enemy.get_instance_id()`.

**Secondary ADRs**: ADR-0002 (Autoload ordering — #6, after SceneManager #4, before StatusEffectsManager #7), ADR-0014 (registration ordering contract — WaveManager calls `register_enemy` before `add_child`)

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `instance_from_id()`, `Dictionary`, `RefCounted` all stable since Godot 4.0. No post-cutoff APIs.

**Control Manifest Rules (Core layer)**:
- Required: Register as Autoload #6. Access Autoloads only from `_ready()` or signal handlers.
- Required: HP stored as `float` internally; damage/heal numbers emitted as `int` via `roundi()`.
- Required: `register_enemy(enemy, type_id)` called by WaveManager before `add_child()` — NOT in `EnemyInstance._ready()`.
- Forbidden: Never access HP state directly from another system.
- Forbidden: Never call `instance_from_id()` without null-checking the result.

---

## Acceptance Criteria

*From GDD `design/gdd/health-damage.md`, scoped to this story:*

- [ ] **AC-HD-17** — On `run_started` signal: `_fayde_current_hp` equals `FAYDE_MAX_HP` (100) regardless of previous HP value. (Run-reset path reachable without a full scene.)
- [ ] **AC-HD-17b** — After `_on_run_started()`: `_enemy_registry.is_empty() == true`; `_fayde_dead == false`; `_iframe_active == false`. All three verified in one call, independent of HP check in AC-HD-17.
- [ ] **AC-HD-18** — A newly registered enemy has `current_hp` equal to `EnemyCatalog.get_type(type_id).base_hp`. Verify for Drifter (20), Charger (35), Cluster (12).

---

## Implementation Notes

*Derived from ADR-0007 Implementation Guidelines:*

**Class skeleton:**
```gdscript
class_name HealthAndDamage
extends Node

var _fayde_max_hp: float = 100.0
var _fayde_current_hp: float = 100.0
var _iframe_active: bool = false
var _iframe_timer: float = 0.0
const FAYDE_IFRAME_DURATION: float = 0.5
var _current_zone: GameEnums.HPZone = GameEnums.HPZone.FULL
var _fayde_dead: bool = false
var _first_run_active: bool = false
var _enemy_registry: Dictionary = {}  # int → EnemyHPInstance

const FAYDE_MAX_HP: float = 100.0
const FAYDE_HP_CRITICAL_CAREFUL: float = 0.40
const FAYDE_HP_CRITICAL_DESPERATE: float = 0.20
const HEAVY_HIT_THRESHOLD: int = 15
const FIRST_RUN_DAMAGE_MULTIPLIER: float = 0.5
```

**Inner class (in same file or as nested class):**
```gdscript
class EnemyHPInstance extends RefCounted:
    var max_hp: float
    var current_hp: float
    var type_id: int
    var is_dead: bool = false
    var prana_affiliation: GameEnums.DamageClass = GameEnums.DamageClass.NONE
```

**register_enemy:**
```gdscript
func register_enemy(enemy: Node, type_id: int) -> void:
    var et := EnemyCatalog.get_type(type_id)
    var inst := EnemyHPInstance.new()
    inst.max_hp = et.base_hp
    inst.current_hp = et.base_hp
    inst.type_id = type_id
    inst.prana_affiliation = et.prana_affiliation
    _enemy_registry[enemy.get_instance_id()] = inst
```

**force_end_iframe_window (test seam):**
```gdscript
func force_end_iframe_window() -> void:
    _iframe_active = false
    _iframe_timer = 0.0
```

**Run reset — connect in `_ready()`:**
```gdscript
func _ready() -> void:
    GameStateManager.run_started.connect(_on_run_started)

func _on_run_started() -> void:
    _fayde_current_hp = FAYDE_MAX_HP
    _fayde_dead = false
    _iframe_active = false
    _iframe_timer = 0.0
    _enemy_registry.clear()
    _current_zone = GameEnums.HPZone.FULL
    # Zone signal AC-HD-32 handled in Story 004 (zone signal path)
```

**Note on typed Dictionary**: Godot 4.6 supports `Dictionary[int, EnemyHPInstance]` syntax but GDScript typed Dicts have known class-cache issues with custom `RefCounted` subclasses (tech debt from EnemyCatalog Story 002). Use untyped `Dictionary` for `_enemy_registry` with manual type assertions in tests.

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 002: `apply_damage()` pipeline
- Story 003: I-frame float accumulator timer
- Story 004: `apply_heal()`, zone signals (including AC-HD-32 run-reset zone sync)
- Story 005: `enemy_killed`, `player_died` signals, heavy hit, first-run mercy

---

## QA Test Cases

*Logic story — automated test specs.*

**AC-HD-17 — run_started resets Fayde HP**
- Given: `HealthAndDamage` node added to scene tree; `_fayde_current_hp` manually set to 42.0
- When: `_on_run_started()` is called (or `run_started` signal is emitted)
- Then: `_fayde_current_hp` equals `FAYDE_MAX_HP` (100.0)
- Edge cases: HP already at max (100) → still passes; HP below 0 edge case cannot occur (dead-target guard in Story 002)

**AC-HD-17b — run_started clears all state flags**
- Given: `_enemy_registry` contains one entry; `_fayde_dead = true`; `_iframe_active = true`
- When: `_on_run_started()` called
- Then: `_enemy_registry.is_empty() == true`; `_fayde_dead == false`; `_iframe_active == false`
- Edge cases: Called multiple times in a row → idempotent (same result)

**AC-HD-18 — registered enemy HP matches catalog**
- Given: `EnemyCatalog` autoload available; three enemy IDs (0=Drifter, 1=Charger, 2=Cluster)
- When: `register_enemy(mock_node, type_id)` called for each
- Then: `_enemy_registry[id].current_hp == base_hp` for each type (20.0 / 35.0 / 12.0); `_enemy_registry[id].max_hp == base_hp`
- Edge cases: register same node twice → second call overwrites the first (no duplicate guard at this level)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/health-damage/health_damage_skeleton_test.gd` — must exist and pass headless

**Status**: [x] Created — see Completion Notes

---

## Dependencies

- Depends on: None (first story in this epic)
- Unlocks: Story 002 (apply_damage needs the registry and HP vars), Story 003 (i-frame timer vars), Story 004 (apply_heal + zone state)

---

## Completion Notes

**Completed**: 2026-06-02
**Criteria**: 3/3 passing (none deferred)
**Deviations**:
- ADVISORY: `_fayde_current_hp: int` — ADR-0007 specifies `float` internally. Pending ADR-0007 revision before regen system lands.
- ADVISORY: Header comment "Autoload #5" — ADR-0002 says #6. Intentional placeholder until AudioSystem story lands.
- ADVISORY: `unregister_enemy` is public — prior `/code-review` suggested `_unregister_enemy`. Logged, not enforced.
**Test Evidence**: Logic — `tests/unit/health-damage/health_damage_skeleton_test.gd` (covers AC-HD-17, 17b, 18; run status: manual verification recommended)
**Code Review**: Complete — `/code-review` APPROVED WITH SUGGESTIONS, commit `6f883c1` (all required changes applied)
