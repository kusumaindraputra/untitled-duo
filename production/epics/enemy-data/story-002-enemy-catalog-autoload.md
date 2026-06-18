# Story 002: EnemyCatalog Autoload

> **Epic**: Enemy Data
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (2–3 hours)
> **Manifest Version**: 2026-05-30
> **Last Updated**: 2026-05-30

## Context

**GDD**: `design/gdd/enemy-data.md`
**Requirements**: `TR-ED-001`, `TR-ED-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Autoload Architecture and Registration Order
**ADR Decision Summary**: EnemyCatalog is Autoload position 2 — registered after PranaCatalog, before GameStateManager. All consuming systems call `EnemyCatalog.get_type(id)` from `_ready()` or signal handlers only.

**Secondary ADR**: ADR-0008: PranaCatalog Immutability — EnemyCatalog follows the identical immutability contract. `get_type()` always returns `duplicate_deep()`, never a direct reference.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: AutoLoad system unchanged since Godot 4.0. Known Godot 4 constraint: `class_name` declaration on an Autoload script causes a "hides autoload singleton" parse error if the name matches the Autoload node name. **Do not add `class_name EnemyCatalog`** — access the catalog exclusively via its Autoload node name `EnemyCatalog`. This matches the pattern used by `src/data/prana_catalog.gd`. See tech-debt-register.md (ADR-0002 annotation item).

**Control Manifest Rules (Foundation Layer)**:
- Required: Register EnemyCatalog at Autoload position 2 in Project Settings (exactly: `EnemyCatalog` → `res://src/data/enemy_catalog.gd`). (ADR-0002)
- Required: `EnemyCatalog.get_type(id)` must always return `original.duplicate_deep()` — never a direct reference. (ADR-0008)
- Required: All startup guards use `push_error()`, not `assert()` — stripped from release builds. (ADR-0008)
- Forbidden: Access Autoloads in `_init()` or `@export` default expressions. (ADR-0002)
- Forbidden: Never return a direct reference from `get_type()`. (ADR-0008)
- Forbidden: Never use `duplicate(true)` — use `duplicate_deep()`. (ADR-0008)

---

## Acceptance Criteria

*From GDD `design/gdd/enemy-data.md`, scoped to this story:*

- [ ] `src/data/enemy_catalog.gd` exists — no `class_name` declaration (Godot 4 Autoload constraint)
- [ ] EnemyCatalog registered at Autoload position 2 in `project.godot` (TR-ED-001)
- [ ] `get_type(id: int) -> EnemyType` returns a `duplicate_deep()` copy — never a direct reference (TR-ED-002)
- [ ] **AC-ED-07**: Requesting the same entry twice returns identical field values (immutability preserves data)
- [ ] **AC-ED-08**: Mutating a field on the returned copy does not affect the next `get_type()` call for the same ID
- [ ] **AC-ED-11**: `get_type(99)` (non-existent ID) returns `null`
- [ ] **AC-ED-12**: `get_active_types()` never includes any entry with `status != ACTIVE`
- [ ] **AC-ED-13**: `get_active_types()` never includes `INACTIVE` entries
- [ ] **AC-ED-15**: `get_type(id)` returns a complete `EnemyType` with all 13 fields accessible in one call
- [ ] **AC-ED-16**: `get_spawnable_types()` returns only entries where `status == ACTIVE` AND `wave_threat_value != null`
- [ ] `_validate_all()` called from `_ready()` — calls `push_error()` for any entry with `id < 0`, empty `name`, or invalid `archetype`
- [ ] Unit test `tests/unit/enemy-data/enemy_catalog_test.gd` exists and all tests pass

---

## Implementation Notes

*Derived from ADR-0002 and ADR-0008 Implementation Guidelines:*

Follow the exact same pattern as `src/data/prana_catalog.gd` (Story 003 of Prana Data epic). Key differences for EnemyCatalog:

**No `class_name` declaration** — Godot 4 parse error if class_name matches Autoload node name. Access exclusively via Autoload path. (Known tech debt — see ADR-0002 annotation in tech-debt-register.md)

**Catalog structure:**
```gdscript
extends Node

const CATALOG_PATH := "res://assets/data/enemy_types/"
const ENTRY_COUNT := 4

var _types: Dictionary[int, EnemyType] = {}

func _ready() -> void:
    _load_catalog()
    _validate_all()

func get_type(id: int) -> EnemyType:
    if not _types.has(id):
        return null
    return _types[id].duplicate_deep()

func get_active_types() -> Array[EnemyType]:
    var result: Array[EnemyType] = []
    for entry in _types.values():
        if entry.status == GameEnums.EnemyStatus.ACTIVE:
            result.append(entry.duplicate_deep())
    return result

func get_spawnable_types() -> Array[EnemyType]:
    var result: Array[EnemyType] = []
    for entry in _types.values():
        if entry.status == GameEnums.EnemyStatus.ACTIVE and entry.wave_threat_value != null:
            result.append(entry.duplicate_deep())
    return result
```

**`_validate_all()` startup checks** (use `push_error()` — not `assert()`):
- `entry.id >= 0` — negative IDs are invalid
- `entry.name != ""` — empty names are invalid
- Valid `archetype` value (in EnemyArchetype enum range)
- If `status == ACTIVE`: `wave_threat_value != null` is advisory (boss is vs_scope, not active)

**Tests without .tres files**: Unit tests can programmatically construct `EnemyType` instances and populate `_types` directly (bypassing `_load_catalog()`) to test catalog logic in isolation. The `.tres` file data is verified in Story 003.

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 001: EnemyType Resource Schema — the GDScript class that defines the fields
- Story 003: Four EnemyType .tres Data Files — the actual field values (AC-ED-01 to AC-ED-06, AC-ED-09/10/14)

---

## QA Test Cases

*Logic story — automated test specs.*

- **AC-1**: `get_type()` returns a deep copy (TR-ED-002)
  - Given: catalog populated with a programmatic EnemyType (id=0, name="Drifter")
  - When: `get_type(0)` called, then `result.name = "MUTATED"`
  - Then: a second `get_type(0)` call returns name "Drifter" (not "MUTATED")
  - Edge cases: Verify with a nested resource field (e.g., `sprite_size`) if applicable

- **AC-2**: Same entry twice returns identical values (AC-ED-07)
  - Given: catalog populated with a programmatic EnemyType
  - When: `get_type(0)` called twice
  - Then: both calls return entries with identical field values

- **AC-3**: Non-existent ID returns null (AC-ED-11)
  - Given: catalog loaded with entries for IDs 0–3
  - When: `get_type(99)` called
  - Then: returns `null` (strict null — not a default EnemyType)
  - Edge cases: Also test negative IDs: `get_type(-1)` → null

- **AC-4**: `get_active_types()` excludes vs_scope entries (AC-ED-12)
  - Given: catalog has entries with ACTIVE (0,1,2) and VS_SCOPE (3)
  - When: `get_active_types()` called
  - Then: returned array contains IDs 0, 1, 2 — ID 3 is absent

- **AC-5**: `get_active_types()` excludes inactive entries (AC-ED-13)
  - Given: catalog has an entry with `status = INACTIVE`
  - When: `get_active_types()` called
  - Then: the INACTIVE entry is not in the result

- **AC-6**: `get_spawnable_types()` excludes null wave_threat_value (AC-ED-16)
  - Given: catalog has Drifter (wave_threat_value=1), Charger (2), Cluster (1), Warped Warden (null)
  - When: `get_spawnable_types()` called
  - Then: result contains IDs 0, 1, 2 only — ID 3 absent
  - Edge cases: Result count == 3

- **AC-7**: Single `get_type()` call returns all required fields (AC-ED-15)
  - Given: catalog has a fully populated EnemyType for ID 0
  - When: `get_type(0)` called
  - Then: returned entry has non-default values for: id, name, archetype, base_hp, base_damage, base_move_speed
  - Edge cases: No second lookup required to retrieve any field

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/enemy-data/enemy_catalog_test.gd` — must exist and all tests pass

**Status**: [x] Created and passing — 17/17 tests pass (2026-05-30)

---

## Dependencies

- Depends on: Story 001 (EnemyType class must exist; EnemyStatus enum must be in GameEnums)
- Unlocks: Story 003 — .tres data files (catalog must be functional before runtime validation runs)

---

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 12/12 passing (all covered by automated tests + live Godot headless run)
**Deviations**: 2 advisory items logged in tech-debt-register.md — Dictionary untyped revert, global class cache manual patch
**Test Evidence**: Logic — `tests/unit/enemy-data/enemy_catalog_test.gd` — 17/17 pass (Godot 4.6.2 headless)
**Code Review**: Complete — APPROVED (post-fix re-review; required changes applied before close)
