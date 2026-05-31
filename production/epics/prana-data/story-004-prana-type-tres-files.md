# Story 004: Five Prana Type .tres Data Files

> **Epic**: Prana Data
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: S (2–3 hours)
> **Manifest Version**: 2026-05-30
> **Last Updated**: 2026-05-30

## Context

**GDD**: `design/gdd/prana-data.md`
**Requirement**: `TR-PD-007` (data-driven workflow — all catalog values inspector-authored, not hardcoded)

*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: N/A — pure data authoring, no architectural pattern required
**Secondary ADRs**: ADR-0006 (enum integer serialization stability must be verified before authoring), ADR-0008 (catalog's `_validate_all()` will catch corrupt files at startup)

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: ⚠️ ADR-0006 `.tres` enum serialization verification gate MUST complete before authoring these files (see Control Manifest cross-cutting constraints). If enum values serialize as integers: explicit integer assignments in `GameEnums` are safety-critical — a reorder would silently corrupt these files. `Color` stores float components in `.tres` — tests must use `Color.is_equal_approx()`, not `==`.

**Control Manifest Rules (Foundation Layer)**:
- Required: All GameEnums enum constants must have explicit integer assignments — new values appended, never reordered. (ADR-0006)
- Required: `PranaCatalog.get_type(id)` validates id, base_damage_modifier > 0, non-empty name, non-null assets on startup. (ADR-0008)
- Guardrail: `duplicate_deep()` is called on every `get_type()` — do not call `get_type()` in `_process()`; cache results. (ADR-0008)

---

## Acceptance Criteria

*From GDD `design/gdd/prana-data.md` Catalog Table, scoped to this story:*

- [ ] **Prerequisite**: ADR-0006 `.tres` enum verification gate completed and result documented (blocks file authoring)
- [ ] 5 files created: `res://assets/data/prana_types/prana_type_0.tres` through `prana_type_4.tres`
- [ ] AC-PD-02: names — ID 0 = "Ashfire", 1 = "Voidblue", 2 = "Stormgold", 3 = "Deepfrost", 4 = "Verdant"
- [ ] AC-PD-08: damage_class — ID 0 = FIRE(0), 1 = SHADOW(1), 2 = LIGHTNING(2), 3 = ICE(3), 4 = NATURE(4)
- [ ] AC-PD-34: base_status — ID 0 = BURN(0), 1 = BLIND(1), 2 = STUN(2), 3 = FREEZE(3), 4 = REGENERATE(4)
- [ ] AC-PD-11–15: base_damage_modifier — Ashfire=1.25, Voidblue=0.90, Stormgold=1.15, Deepfrost=0.80, Verdant=0.70
- [ ] Color values match GDD: Ashfire=#F24C1D, Voidblue=#4A5EF5, Stormgold=#FFCC00, Deepfrost=#3DD9F0, Verdant=#1AC953 — verified using `Color.is_equal_approx()`
- [ ] `PranaCatalog._validate_all()` produces zero `push_error()` calls on startup with these 5 files

---

## Implementation Notes

*From GDD Catalog Table and Implementation Notes:*

Author each file in the Godot Inspector (FileSystem → right-click → New Resource → PranaType). Save at `res://assets/data/prana_types/`. Fill all 12 fields per the GDD catalog table below:

| File | id | name | damage_class | base_status | base_damage_modifier | color |
|------|----|------|-------------|-------------|---------------------|-------|
| `prana_type_0.tres` | 0 | Ashfire | FIRE | BURN | 1.25 | #F24C1D |
| `prana_type_1.tres` | 1 | Voidblue | SHADOW | BLIND | 0.90 | #4A5EF5 |
| `prana_type_2.tres` | 2 | Stormgold | LIGHTNING | STUN | 1.15 | #FFCC00 |
| `prana_type_3.tres` | 3 | Deepfrost | ICE | FREEZE | 0.80 | #3DD9F0 |
| `prana_type_4.tres` | 4 | Verdant | NATURE | REGENERATE | 0.70 | #1AC953 |

Visual/audio fields (`icon`, `vfx_burst_shape`, `audio_signature`, `cast_animation`, `element`, `semantic_identity`): populate with placeholder values for First Playable. The `icon` and `audio_signature` fields must be non-null for `_validate_all()` to pass — use placeholder 8×8 px textures and placeholder AudioStream assets if final art/audio isn't ready.

---

## Out of Scope

*Handled by other epics or other stories:*

- Story 001: GameEnums verification gate (must be completed first)
- Story 002: PranaType schema (must exist before Inspector can display fields)
- Story 003: PranaCatalog Autoload (must be implemented before runtime validation runs)
- Status Effects epic: timer tick parameters (burn_duration, burn_tick_rate, etc.) — these are @export vars in StatusEffectsManager, NOT in PranaType.tres files

---

## QA Test Cases

*Config/Data — smoke check verification. Run after all 5 files are authored.*

- **AC-1**: Catalog integrity smoke check (AC-PD-01)
  - Setup: Launch game from Godot editor with authored .tres files in place
  - Verify: No `push_error()` messages appear in Output panel related to PranaCatalog
  - Pass condition: Editor Output panel shows zero PranaCatalog errors during startup

- **AC-2**: Names roundtrip (AC-PD-02)
  - Setup: GUT test calls `PranaCatalog.get_type(N)` for N = 0–4
  - Verify: names match: 0=Ashfire, 1=Voidblue, 2=Stormgold, 3=Deepfrost, 4=Verdant
  - Pass condition: all 5 name assertions pass

- **AC-3**: Damage modifier values (AC-PD-11–15)
  - Setup: GUT test calls `get_type(N).base_damage_modifier` for each ID
  - Verify: 0→1.25, 1→0.90, 2→1.15, 3→0.80, 4→0.70
  - Pass condition: all 5 float assertions pass (exact equality acceptable for these values)

- **AC-4**: damage_class enum values (AC-PD-08)
  - Setup: GUT test calls `get_type(N).damage_class`
  - Verify: 0→GameEnums.DamageClass.FIRE, 1→SHADOW, 2→LIGHTNING, 3→ICE, 4→NATURE
  - Pass condition: all 5 enum assertions pass

- **AC-5**: base_status enum values (AC-PD-34)
  - Setup: GUT test calls `get_type(N).base_status`
  - Verify: 0→GameEnums.BaseStatus.BURN, 1→BLIND, 2→STUN, 3→FREEZE, 4→REGENERATE
  - Pass condition: all 5 enum assertions pass

- **AC-6**: Color values (GDD Catalog Table)
  - Setup: GUT test calls `get_type(N).color`
  - Verify: `Color.is_equal_approx(get_type(0).color, Color("#F24C1D"))` == true (and similarly for IDs 1–4)
  - Pass condition: all 5 color assertions pass using `is_equal_approx`, NOT `==`
  - Edge cases: Never use `get_type(0).color == Color("#F24C1D")` — float components may not round-trip exactly

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: Smoke check pass — `production/qa/smoke-[date].md` documenting PranaCatalog startup with zero push_error() calls

**Status**: `production/qa/smoke-2026-05-30.md` — PASS

---

## Dependencies

- Depends on: Story 003 (`PranaCatalog` must be implemented and functional before `.tres` files are verified at runtime). Story 001 ADR-0006 verification gate must be documented before authoring `.tres` files.
- Unlocks: Epic complete — Prana Data foundation is functional; downstream epics (Prana Grid, Combination Resolution) can proceed

---

## Completion Notes

**Completed**: 2026-05-30
**Criteria**: 8/8 passing (none deferred)
**Deviations**: ADVISORY — story AC specified `prana_type_0.tres`–`prana_type_4.tres`; actual files authored as `prana_fire.tres`–`prana_nature.tres` (matching catalog's expected paths). Functionally correct. Logged to tech debt register.
**Test Evidence**: Config/Data — smoke check at `production/qa/smoke-2026-05-30.md` (PASS). Unit test file: `tests/unit/prana-data/prana_tres_data_test.gd` (27 test functions — AC-2 through AC-6).
**Code Review**: Complete — `/code-review` passed (approved with suggestions)
