# Story 001: EnemyType Resource Schema

> **Epic**: Enemy Data
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (2–3 hours)
> **Manifest Version**: 2026-05-30
> **Last Updated**: 2026-05-30

## Context

**GDD**: `design/gdd/enemy-data.md`
**Requirements**: `TR-ED-003`, `TR-ED-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: GameEnums as Pure Enum Container
**ADR Decision Summary**: All shared enum types live in `src/data/game_enums.gd` with explicit integer assignments. `EnemyStatus` (active/vs_scope/inactive) must be added there — it is consumed by EnemyCatalog and Wave/Encounter System, making it cross-system.

**Secondary ADR**: ADR-0008: PranaCatalog Immutability — EnemyCatalog follows the identical `duplicate_deep()` pattern; the schema must be compatible (all fields must survive deep-copy without reference aliasing).

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Godot 4.x serializes `@export` enum fields as integers in `.tres` files — enum integer assignments in `GameEnums` are safety-critical. Explicit integer assignments prevent silent corruption if order ever changes. Nullable fields (`wave_threat_value`, `drop_prana_type`, `drop_rate`) must use `Variant` type — GDScript typed `int`/`float` cannot hold `null`. Verify against `docs/engine-reference/godot/` before implementing.

**Control Manifest Rules (Foundation Layer)**:
- Required: All GameEnums enum constants must have explicit integer assignments — append-only. (ADR-0006)
- Required: `game_enums.gd` contains only enum definitions — no `preload()`, `@onready`, `@export`, or `extends` beyond `RefCounted`. (ADR-0006)
- Forbidden: Never define cross-system enums in individual system files. (ADR-0006)
- Forbidden: Never use `duplicate(true)` — use `duplicate_deep()`. (ADR-0008)

---

## Acceptance Criteria

*From GDD `design/gdd/enemy-data.md`, scoped to this story:*

- [ ] `GameEnums.EnemyStatus` enum added to `src/data/game_enums.gd` with explicit assignments: `ACTIVE = 0`, `VS_SCOPE = 1`, `INACTIVE = 2`
- [ ] `src/data/enemy_type.gd` exists with `class_name EnemyType extends Resource`
- [ ] 12 `@export` fields declared with correct types:
  - `id: int`
  - `name: String`
  - `archetype: GameEnums.EnemyArchetype`
  - `prana_affiliation: GameEnums.DamageClass` — default `GameEnums.DamageClass.NONE` (TR-ED-004)
  - `base_hp: int`
  - `base_damage: float`
  - `base_move_speed: float`
  - `drop_prana_type: Variant` — `null` for boss (int PranaType ID otherwise)
  - `drop_rate: Variant` — `null` for boss (float 0.0–1.0 otherwise)
  - `wave_threat_value: Variant` — `null` for boss (int otherwise)
  - `sprite_size: Vector2i`
  - `status: GameEnums.EnemyStatus`
- [ ] `@export var scene: PackedScene` field present (TR-ED-003) — used by WaveManager to instantiate enemy scenes
- [ ] Unit test `tests/unit/enemy-data/enemy_type_schema_test.gd` exists and passes — verifies field types and `prana_affiliation` default

---

## Implementation Notes

*Derived from ADR-0006 and ADR-0008 Implementation Guidelines:*

Follow the exact same pattern as `src/data/prana_type.gd` (Story 002 of Prana Data epic).

**Step 1 — Add EnemyStatus to game_enums.gd:**
```gdscript
# ── Enemy catalog status ───────────────────────────────────────────────────────
## Lifecycle status of an EnemyType catalog entry.
## vs_scope = defined but not spawnable at MVP; inactive = deprecated (ID stability only).
enum EnemyStatus { ACTIVE = 0, VS_SCOPE = 1, INACTIVE = 2 }
```
Append after the existing `WaveState` enum. Do not reorder existing values.

**Step 2 — Create EnemyType resource:**
```gdscript
class_name EnemyType
extends Resource

@export var id: int = -1
@export var name: String = ""
@export var archetype: GameEnums.EnemyArchetype = GameEnums.EnemyArchetype.SEEKER
@export var prana_affiliation: GameEnums.DamageClass = GameEnums.DamageClass.NONE
@export var base_hp: int = 0
@export var base_damage: float = 0.0
@export var base_move_speed: float = 0.0
@export var drop_prana_type: Variant = null   # int PranaType ID, or null for boss
@export var drop_rate: Variant = null          # float 0.0–1.0, or null for boss
@export var wave_threat_value: Variant = null  # int, or null for boss
@export var sprite_size: Vector2i = Vector2i(16, 16)
@export var status: GameEnums.EnemyStatus = GameEnums.EnemyStatus.ACTIVE
@export var scene: PackedScene = null
```

**Nullable field reasoning**: `drop_prana_type`, `drop_rate`, `wave_threat_value` are legitimately `null` for the Warped Warden boss (AC-ED-09/10). GDScript typed `int`/`float` cannot hold `null` — use `Variant`. Wave/Encounter System and Prana Drop/Loot must null-check before use (Edge Case 1 in GDD).

**`prana_affiliation` default**: `DamageClass.NONE = -1` is the sentinel for no affiliation (Warped Warden) per TR-ED-004. Never use `null` for this field.

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 002: EnemyCatalog Autoload — implements the catalog that loads and exposes these resources
- Story 003: Four EnemyType .tres Data Files — authors the actual inspector data

---

## QA Test Cases

*Logic story — automated test specs.*

- **AC-1**: EnemyStatus enum exists with correct values
  - Given: `game_enums.gd` loaded
  - When: reading `GameEnums.EnemyStatus.ACTIVE`, `.VS_SCOPE`, `.INACTIVE`
  - Then: values are `0`, `1`, `2` respectively
  - Edge cases: No value equals another; all three constants exist

- **AC-2**: EnemyType resource can be instantiated
  - Given: `EnemyType.new()` called
  - When: instance created
  - Then: instance is not null and `is_instance_of(EnemyType)` returns true

- **AC-3**: `prana_affiliation` defaults to `DamageClass.NONE` (= -1)
  - Given: `EnemyType.new()` with no fields set
  - When: reading `prana_affiliation`
  - Then: equals `GameEnums.DamageClass.NONE` (= -1), not `0` (FIRE)
  - Edge cases: Verify the int value is exactly -1

- **AC-4**: Nullable fields default to null
  - Given: `EnemyType.new()` with no fields set
  - When: reading `drop_prana_type`, `drop_rate`, `wave_threat_value`
  - Then: all three are `null` (strict null check, not `== 0`)

- **AC-5**: `scene` field is `PackedScene` typed and defaults to null
  - Given: `EnemyType.new()` with no fields set
  - When: reading `scene`
  - Then: `scene == null` (not error, not 0)

- **AC-6**: All typed enum fields accept correct enum values without error
  - Given: `EnemyType.new()`
  - When: assigning `archetype = GameEnums.EnemyArchetype.BOSS`, `status = GameEnums.EnemyStatus.VS_SCOPE`
  - Then: read-back matches assigned values; no parse error

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/enemy-data/enemy_type_schema_test.gd` — must exist and all tests pass

**Status**: [x] Created and passing — 18/18 tests pass (2026-05-30)

---

## Dependencies

- Depends on: Story 001 of Prana Data epic — `GameEnums` must exist at `src/data/game_enums.gd` (already DONE)
- Unlocks: Story 002 — EnemyCatalog Autoload (needs EnemyType class to load .tres files)

---

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 5/5 passing (all covered by automated tests)
**Deviations**: None — TR-ED-003, TR-ED-004, ADR-0006 all satisfied
**Test Evidence**: Logic — `tests/unit/enemy-data/enemy_type_schema_test.gd` — 18/18 pass
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (assert_object on Variant nulls; is EnemyType AC-2 check — advisory only, no required changes)
