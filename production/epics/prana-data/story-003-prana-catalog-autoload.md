# Story 003: PranaCatalog Autoload

> **Epic**: Prana Data
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (3–4 hours)
> **Manifest Version**: 2026-05-30
> **Last Updated**: 2026-05-30

## Context

**GDD**: `design/gdd/prana-data.md`
**Requirements**: `TR-PD-001`, `TR-PD-002`, `TR-PD-005`

*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: PranaCatalog Immutability via duplicate_deep()
**ADR Decision Summary**: `PranaCatalog.get_type(id)` always returns `_types[id].duplicate_deep()` — never a direct reference. `_initialized` flag with `push_error()` guard (not assert). `_validate_all()` validates id, base_damage_modifier > 0, non-empty name, non-null asset fields at startup.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `duplicate_deep()` introduced in Godot 4.5 — replaces deprecated `duplicate(true)`. Verify isolation manually before committing: call `get_type(0)`, mutate `base_damage_modifier = 999.0`, call `get_type(0)` again and assert original value unchanged. `assert()` is stripped from Godot 4.6 release exports — all guards must use `push_error()`.

**Control Manifest Rules (Foundation Layer)**:
- Required: Register exactly 10 Autoloads — PranaCatalog at position 1 (first). (ADR-0002)
- Required: Autoload node name in Project Settings must exactly match `class_name` declaration. (ADR-0002)
- Required: Access Autoloads only from `_ready()`, deferred calls, or signal handlers. (ADR-0002)
- Required: `PranaCatalog.get_type(id)` must always return `original.duplicate_deep()`. (ADR-0008)
- Required: All startup guards use `push_error()`, not `assert()`. (ADR-0008)
- Forbidden: Never return a direct reference from `PranaCatalog.get_type()`. (ADR-0008)
- Forbidden: Never use `duplicate(true)` — deprecated since Godot 4.5. (ADR-0008)
- Forbidden: Never access Autoloads in `_init()`, `@export` default expressions, or static initializers. (ADR-0002)

---

## Acceptance Criteria

*From GDD `design/gdd/prana-data.md` and ADR-0008, scoped to this story:*

- [ ] `src/data/prana_catalog.gd` exists; `class_name PranaCatalog extends Node`; registered as Autoload #1 in Project Settings
- [ ] `var _initialized: bool = false`; set to `true` at end of `_ready()` after `_validate_all()` completes
- [ ] `get_type(id)` returns `push_error()` + null if called before `_initialized` (NOT assert — assert is stripped from release builds)
- [ ] `get_type(id)` returns `_types[id].duplicate_deep()` — verified by mutation isolation test (AC-PD-04b)
- [ ] `get_type(-1)` and `get_type(5)` both return null and fire `push_error()` with ID info — no crash
- [ ] `_validate_all()` checks per loaded type: `t.id == expected_index`, `t.base_damage_modifier > 0.0`, `not t.name.is_empty()`, `t.audio_signature != null`, `t.icon != null`
- [ ] AC-PD-01: catalog contains exactly 5 entries with IDs 0–4 after `_ready()`
- [ ] AC-PD-04: two sequential `get_type(0)` calls return identical values for all 12 properties
- [ ] AC-PD-04b: Caller A sets `copy.base_damage_modifier = 99.0`; Caller B's `get_type(0)` returns `1.25`
- [ ] AC-PD-04c: Caller A replaces `copy.icon = stub_texture`; Caller B's `get_type(0)` returns original catalog icon

---

## Implementation Notes

*Derived from ADR-0008 Implementation section:*

```gdscript
class_name PranaCatalog
extends Node

var _initialized: bool = false
var _types: Array[PranaType] = []

func _ready() -> void:
    _load_types()
    _validate_all()
    _initialized = true

func get_type(id: int) -> PranaType:
    if not _initialized:
        push_error("PranaCatalog.get_type() called before _ready() — check Autoload order")
        return null
    if id < 0 or id >= _types.size():
        push_error("PranaCatalog.get_type(): invalid ID %d (catalog has %d types)" % [id, _types.size()])
        return null
    return _types[id].duplicate_deep()

func _validate_all() -> void:
    for expected_id in range(_types.size()):
        var t: PranaType = _types[expected_id]
        if t == null:
            push_error("PranaCatalog: type at index %d is null" % expected_id)
            continue
        if t.id != expected_id:
            push_error("PranaCatalog: type at index %d has wrong id %d" % [expected_id, t.id])
        if t.base_damage_modifier <= 0.0:
            push_error("PranaCatalog: type %d has base_damage_modifier <= 0" % t.id)
        if t.name.is_empty():
            push_error("PranaCatalog: type %d has empty name" % t.id)
        if t.audio_signature == null:
            push_error("PranaCatalog: type %d has null audio_signature" % t.id)
        if t.icon == null:
            push_error("PranaCatalog: type %d has null icon" % t.id)
```

Store `.tres` files at `res://assets/data/prana_types/prana_type_0.tres` through `prana_type_4.tres`. In GUT tests, use stub `.tres` fixtures in `tests/fixtures/prana_types/` to avoid dependency on production assets.

Never call `get_type()` in `_process()` — always cache with `@onready var` or in `_ready()`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: GameEnums (enum types used by PranaType fields)
- Story 002: PranaType resource schema (must exist before catalog can load instances)
- Story 004: Five production `.tres` files (catalog loads whatever files are present; this story uses test fixtures)

---

## QA Test Cases

*Written at story creation. Implement against these — do not invent new test cases during implementation.*

- **AC-1**: duplicate_deep() scalar isolation (AC-PD-04b)
  - Given: PranaCatalog loaded with fixture files, get_type(0) returns a PranaType with base_damage_modifier=1.25
  - When: Caller A calls get_type(0) and sets `caller_a.base_damage_modifier = 99.0`; Caller B then calls get_type(0)
  - Then: `caller_b.base_damage_modifier == 1.25` (catalog original unchanged)
  - Edge cases: Repeat for a String property (`name`) to confirm non-primitive isolation

- **AC-2**: duplicate_deep() reference-type isolation (AC-PD-04c)
  - Given: PranaCatalog loaded; stub texture preloaded at `res://tests/fixtures/stub_icon.png`
  - When: Caller A calls get_type(0) and sets `caller_a.icon = stub_texture`; Caller B calls get_type(0)
  - Then: `caller_b.icon != stub_texture` (is the original catalog icon, not the stub)
  - Edge cases: Underlying asset data IS shared by reference — only property reassignment is isolated; test reassignment only

- **AC-3**: Pre-ready guard with push_error (AC-0008-05)
  - Given: In GUT setup, `PranaCatalog._initialized = false` (simulate pre-ready state)
  - When: `PranaCatalog.get_type(0)` called
  - Then: Returns null; `push_error()` message contains "before _ready()"; no crash
  - Edge cases: assert() must NOT be used — verify by checking no GDScriptNativeClass error is thrown in release mode

- **AC-4**: Invalid ID high (AC-PD-23)
  - Given: PranaCatalog loaded with 5 types (IDs 0–4)
  - When: `PranaCatalog.get_type(5)` called
  - Then: Returns null; push_error fires containing ID "5"; no crash

- **AC-5**: Invalid ID low (AC-PD-23)
  - Given: PranaCatalog loaded
  - When: `PranaCatalog.get_type(-1)` called
  - Then: Returns null; push_error fires; no crash

- **AC-6**: Consistent reads (AC-PD-04)
  - Given: PranaCatalog loaded with fixture for type 0
  - When: `get_type(0)` called twice and results stored as `a` and `b`
  - Then: `a.name == b.name`, `a.base_damage_modifier == b.base_damage_modifier`, `a.damage_class == b.damage_class` (all 12 properties identical)

- **AC-7**: Validation fires on corrupt fixture (AC-0008-04)
  - Given: A test fixture PranaType.tres with `base_damage_modifier = 0.0`
  - When: PranaCatalog loads this fixture in `_load_types()` (test injection)
  - Then: `push_error()` fires at startup with the corrupt type's ID; remaining valid types load successfully

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/prana-data/prana_catalog_test.gd` — must exist and pass in GUT

**Status**: [x] PASSED — 16/16 tests (GdUnit4 v6.1.3, Godot 4.6.2, 2026-05-30)

---

## Dependencies

- Depends on: Story 002 (`prana_type.gd` schema must exist — catalog instantiates PranaType from `.tres` files)
- Unlocks: Story 004 (catalog functional; production `.tres` files can now be authored and verified at runtime)

---

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 9/10 passing (AC-PD-01 "exactly 5 entries after _ready()" deferred — requires Story 004 .tres files for production verification; stub fallback fills 5 slots in pre-production)
**Deviations**:
- ADVISORY: No `class_name PranaCatalog` in implementation. Story AC and ADR-0008 code snippet both specify it, but Godot 4.6 raises a parse error ("hides autoload singleton") when class_name matches the Autoload node name. Implementation is correct. Story AC + ADR snippet need a one-line update. Logged as tech debt.
- ADVISORY (G4): GdUnit4 v6 has no push_error capture API. Null-return contract is verified by tests; push_error behaviour confirmed via manual run. Documented in test file header.
**Test Evidence**: Logic — `tests/unit/prana-data/prana_catalog_test.gd` — 16/16 PASSED (GdUnit4 v6.1.3, Godot 4.6.2)
**Code Review**: APPROVED WITH SUGGESTIONS (2026-05-30 — this session)
