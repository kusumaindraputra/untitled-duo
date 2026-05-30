# Story 002: PranaType Resource Schema

> **Epic**: Prana Data
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (1–2 hours)
> **Manifest Version**: 2026-05-30
> **Last Updated**: 2026-05-30

## Context

**GDD**: `design/gdd/prana-data.md`
**Requirement**: `TR-PD-007`

*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: PranaCatalog Immutability via duplicate_deep()
**ADR Decision Summary**: PranaType properties must be `@export var` (not `const` — invalid GDScript syntax and incompatible with inspector/`.tres` workflow); `duplicate_deep()` on a Resource copies property values but shares file-backed asset data by reference.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `@export const` is invalid GDScript — only `@export var` works for inspector-editable `.tres` properties. `Color` values stored in `.tres` as float components — always use `Color.is_equal_approx()` in tests, never `==` with a hex string.

**Control Manifest Rules (Foundation Layer)**:
- Required: `PranaCatalog.get_type(id)` always returns `original.duplicate_deep()` — PranaType must support deep copy (ADR-0008)
- Forbidden: Never return a direct reference from `PranaCatalog.get_type()` (ADR-0008)

---

## Acceptance Criteria

*From GDD `design/gdd/prana-data.md` Property Table, scoped to this story:*

- [ ] `src/data/prana_type.gd` exists with `class_name PranaType extends Resource`
- [ ] All 12 properties declared as `@export var`: `id`, `name`, `element`, `semantic_identity`, `color`, `icon`, `vfx_burst_shape`, `audio_signature`, `cast_animation`, `damage_class`, `base_status`, `base_damage_modifier`
- [ ] Enum fields use `GameEnums.*` types: `vfx_burst_shape: GameEnums.VfxBurstShape`, `cast_animation: GameEnums.CastAnimation`, `damage_class: GameEnums.DamageClass`, `base_status: GameEnums.BaseStatus`
- [ ] AC-PD-03: a loaded PranaType instance returns non-null values for all 12 properties (null check passes for scalar defaults; asset fields `icon`/`audio_signature` are null until .tres file authored in Story 004 — Story 003 validates non-null at load time)
- [ ] AC-PD-06: `PranaType` has no `targeting_shape`, `cast_shape`, or `spell_shape` property (`"targeting_shape" in prana_type` evaluates to false)
- [ ] AC-PD-07: `PranaType` has no `resonance` or `resonance_weight` property

---

## Implementation Notes

*Derived from ADR-0008 and GDD Property Table:*

```gdscript
class_name PranaType
extends Resource

@export var id: int = 0
@export var name: String = ""
@export var element: String = ""
@export var semantic_identity: String = ""
@export var color: Color = Color.WHITE
@export var icon: Texture2D
@export var vfx_burst_shape: GameEnums.VfxBurstShape = GameEnums.VfxBurstShape.BURST_FLAME
@export var audio_signature: AudioStream
@export var cast_animation: GameEnums.CastAnimation = GameEnums.CastAnimation.CAST_THRUST
@export var damage_class: GameEnums.DamageClass = GameEnums.DamageClass.FIRE
@export var base_status: GameEnums.BaseStatus = GameEnums.BaseStatus.BURN
@export var base_damage_modifier: float = 1.0
```

`@export const` is invalid GDScript syntax — always `@export var`. `AudioStream` and `Texture2D` fields default to `null` here; they are populated in Inspector when authoring `.tres` files (Story 004).

`duplicate_deep()` on a PranaType: copies all property values (including Color as struct, enums as int). `icon` and `audio_signature` fields share underlying engine asset data by reference — reassigning `my_copy.icon = other_texture` affects only `my_copy`, not the original.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: GameEnums definitions (PranaType uses these; must exist first)
- Story 003: PranaCatalog Autoload (loads and serves PranaType instances)
- Story 004: .tres file authoring (populates all 12 fields in Inspector)

---

## QA Test Cases

*Written at story creation. Implement against these — do not invent new test cases during implementation.*

- **AC-1**: All 12 properties accessible on a default PranaType instance
  - Given: A PranaType instantiated with `PranaType.new()`
  - When: Each property is accessed by name
  - Then: `id == 0`, `name == ""`, `element == ""`, `semantic_identity == ""`, `color.is_equal_approx(Color.WHITE)`, `vfx_burst_shape == 0`, `cast_animation == 0`, `damage_class == 0`, `base_status == 0`, `base_damage_modifier == 1.0` — icon and audio_signature are null (expected default; Story 003 validates non-null on loaded .tres)
  - Edge cases: Accessing a property by wrong type (e.g., casting `id` as String) should produce a GDScript error, not silently return 0

- **AC-2**: No targeting shape property (AC-PD-06)
  - Given: A PranaType instance
  - When: `"targeting_shape" in prana_type`, `"cast_shape" in prana_type`, `"spell_shape" in prana_type` using GDScript `in` operator
  - Then: All three evaluate to `false`
  - Edge cases: Direct property access on non-existent field (`prana_type.targeting_shape`) throws a GDScript error — always use `in` operator to test for absence, never direct access

- **AC-3**: No resonance property (AC-PD-07)
  - Given: A PranaType instance
  - When: `"resonance" in prana_type` and `"resonance_weight" in prana_type`
  - Then: Both evaluate to `false`

- **AC-4**: .tres roundtrip preserves base_damage_modifier
  - Given: A PranaType resource saved to a temp `.tres` with `base_damage_modifier = 1.25`
  - When: Loaded via `ResourceLoader.load()` from that `.tres`
  - Then: `loaded.base_damage_modifier == 1.25`
  - Edge cases: Confirms `@export var` serialization works end-to-end; failures here indicate a `.tres` save/load regression

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/prana-data/prana_type_schema_test.gd` — must exist and pass in GUT

**Status**: [x] Passed — 18/18 PASSED (2026-05-30)

---

## Dependencies

- Depends on: Story 001 (`game_enums.gd` must exist — PranaType uses `GameEnums.*` enum types)
- Unlocks: Story 003 (PranaCatalog loads PranaType instances), Story 004 (.tres authoring requires this schema)

---

## Completion Notes

**Completed**: 2026-05-30
**Criteria**: 6/6 passing (0 deferred)
**Deviations**: Advisory — `@export_range(0.5, 2.0, 0.05)` hint literals on `base_damage_modifier` are Inspector constraints, not hardcoded gameplay data. Acceptable per ADR-0008 + GDD.
**Test Evidence**: Logic — `tests/unit/prana-data/prana_type_schema_test.gd` — 18/18 PASSED (GdUnit4 v6.1.3, Godot 4.6.2, 2026-05-30)
**Code Review**: Deferred — to be run (`/code-review src/data/prana_type.gd tests/unit/prana-data/prana_type_schema_test.gd`) before sprint close-out
