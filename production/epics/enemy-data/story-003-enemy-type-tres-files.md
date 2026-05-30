# Story 003: Four EnemyType .tres Data Files

> **Epic**: Enemy Data
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: S (1–2 hours)
> **Manifest Version**: 2026-05-30
> **Last Updated**: —

## Context

**GDD**: `design/gdd/enemy-data.md`
**Requirements**: `TR-ED-001`, `TR-ED-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: N/A — pure data authoring, no architectural pattern required
**Secondary ADRs**:
- ADR-0006: Enum integer serialization stability — explicit assignments in `GameEnums` are safety-critical here. Reordering enum values would silently corrupt `.tres` files.
- ADR-0008: `EnemyCatalog._validate_all()` catches corrupt or incomplete entries at startup.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: ⚠️ ADR-0006 `.tres` enum serialization verification gate **must complete before authoring these files** — same gate as Prana Data Story 004. If enum values serialize as integers (expected), the explicit integer assignments in `GameEnums` are the single safety net against silent data corruption. `Variant`-typed fields (`drop_prana_type`, `drop_rate`, `wave_threat_value`) serialize as `null` in `.tres` for the Warped Warden — verify this round-trips correctly before authoring.

**Control Manifest Rules (Foundation Layer)**:
- Required: All GameEnums enum constants must have explicit integer assignments — new values appended, never reordered. (ADR-0006)
- Required: `EnemyCatalog.get_type(id)` validates id, name non-empty, valid archetype, on startup. (ADR-0008)
- Guardrail: `duplicate_deep()` is called on every `get_type()` — do not call `get_type()` in `_process()`; cache results. (ADR-0008)

---

## Acceptance Criteria

*From GDD `design/gdd/enemy-data.md` Catalog Table, scoped to this story:*

- [ ] **Prerequisite**: ADR-0006 `.tres` enum serialization verification gate completed and result documented (blocks file authoring — same gate as Prana Data Story 004, may reuse result if already done)
- [ ] 4 files created: `res://assets/data/enemy_types/enemy_type_0.tres` through `enemy_type_3.tres`
- [ ] **AC-ED-04**: Names — ID 0 = "Drifter", ID 1 = "Charger", ID 2 = "Cluster", ID 3 = "Warped Warden"
- [ ] **AC-ED-05**: `prana_affiliation` — ID 0 = SHADOW(1), ID 1 = FIRE(0), ID 2 = LIGHTNING(2), ID 3 = NONE(-1)
- [ ] **AC-ED-06**: `archetype` — ID 0 = SEEKER(0), ID 1 = RUSHER(1), ID 2 = SWARMER(2), ID 3 = BOSS(3)
- [ ] **AC-ED-09**: Warped Warden `wave_threat_value` returns `null` — strict null, not `0`
- [ ] **AC-ED-10**: Warped Warden `drop_prana_type` returns `null` — strict null
- [ ] **AC-ED-14**: `sprite_size` — Drifter = Vector2i(16, 16), Charger = Vector2i(12, 20), Cluster = Vector2i(24, 24), Warped Warden = Vector2i(48, 48)
- [ ] **AC-ED-01**: `EnemyCatalog.get_active_types()` returns exactly 3 entries (IDs 0, 1, 2)
- [ ] **AC-ED-02**: Exactly 1 entry with `status = VS_SCOPE` (ID 3 — Warped Warden)
- [ ] `EnemyCatalog._validate_all()` produces zero `push_error()` calls on startup with all 4 files in place

---

## Implementation Notes

*From GDD Catalog Table:*

Author each file in the Godot Inspector (FileSystem → right-click → New Resource → EnemyType). Save at `res://assets/data/enemy_types/`. Fill all 13 fields per the catalog table:

| File | id | name | archetype | prana_affiliation | base_hp | base_damage | base_move_speed | drop_prana_type | drop_rate | wave_threat_value | sprite_size | status |
|------|----|------|-----------|-------------------|---------|-------------|-----------------|-----------------|-----------|-------------------|-------------|--------|
| `enemy_type_0.tres` | 0 | Drifter | SEEKER | SHADOW | 20 | 8.0 | 80.0 | 1 | 0.50 | 1 | 16×16 | ACTIVE |
| `enemy_type_1.tres` | 1 | Charger | RUSHER | FIRE | 35 | 20.0 | 50.0 | 0 | 0.40 | 2 | 12×20 | ACTIVE |
| `enemy_type_2.tres` | 2 | Cluster | SWARMER | LIGHTNING | 12 | 4.0 | 70.0 | 2 | 0.60 | 1 | 24×24 | ACTIVE |
| `enemy_type_3.tres` | 3 | Warped Warden | BOSS | NONE | 500 | 25.0 | 40.0 | null | null | null | 48×48 | VS_SCOPE |

*All `base_hp`, `base_damage`, `base_move_speed` values are provisional — subject to revision after the Health & Damage GDD is authored.*

**`scene` field**: Set to `null` (no placeholder scene exists yet). `_validate_all()` must not treat a null scene as a fatal error at MVP — it is expected for all entries until enemy scenes are implemented in the Enemy AI epic.

**`drop_prana_type`** values map to Prana IDs: 0 = Ashfire, 1 = Voidblue, 2 = Stormgold (from Prana Data catalog).

**Null fields for Warped Warden**: Use the Inspector to set `drop_prana_type`, `drop_rate`, and `wave_threat_value` to null (leave blank in Inspector — `Variant`-typed fields default to null). Verify the round-trip by running the game and checking the GUT test output.

---

## Out of Scope

*Handled by other epics or other stories:*

- Story 001: EnemyType schema (must exist before Inspector can display fields)
- Story 002: EnemyCatalog Autoload (must be implemented before runtime validation runs)
- Enemy AI epic: enemy scene assets (`scene: PackedScene`) — not authored here
- Status Effects epic: slow/stun parameters (`base_move_speed` is read-only here)

---

## QA Test Cases

*Config/Data — smoke check verification. Run after all 4 files are authored.*

- **AC-1**: Catalog integrity smoke check (AC-ED-01, AC-ED-02)
  - Setup: Launch game from Godot editor with all 4 .tres files in place
  - Verify: No `push_error()` messages in Output panel related to EnemyCatalog
  - Pass condition: Editor Output panel shows zero EnemyCatalog errors during startup

- **AC-2**: Names round-trip (AC-ED-04)
  - Setup: GUT test calls `EnemyCatalog.get_type(N)` for N = 0–3
  - Verify: names match: 0=Drifter, 1=Charger, 2=Cluster, 3=Warped Warden
  - Pass condition: all 4 name assertions pass

- **AC-3**: Prana affiliation values (AC-ED-05)
  - Setup: GUT test calls `get_type(N).prana_affiliation` for each ID
  - Verify: 0→SHADOW(1), 1→FIRE(0), 2→LIGHTNING(2), 3→NONE(-1)
  - Pass condition: all 4 enum assertions pass

- **AC-4**: Archetype values (AC-ED-06)
  - Setup: GUT test calls `get_type(N).archetype`
  - Verify: 0→SEEKER(0), 1→RUSHER(1), 2→SWARMER(2), 3→BOSS(3)
  - Pass condition: all 4 enum assertions pass

- **AC-5**: Warped Warden null fields (AC-ED-09, AC-ED-10)
  - Setup: GUT test calls `get_type(3).wave_threat_value` and `get_type(3).drop_prana_type`
  - Verify: both are strictly `null` — `assert(result == null)`, not `assert(not result)`
  - Pass condition: strict null assertions pass for both fields

- **AC-6**: Sprite sizes (AC-ED-14)
  - Setup: GUT test calls `get_type(N).sprite_size` for each ID
  - Verify: 0→Vector2i(16,16), 1→Vector2i(12,20), 2→Vector2i(24,24), 3→Vector2i(48,48)
  - Pass condition: all 4 Vector2i equality assertions pass

- **AC-7**: Active entry count (AC-ED-01)
  - Setup: GUT test calls `EnemyCatalog.get_active_types()`
  - Verify: result has exactly 3 entries with IDs {0, 1, 2}
  - Pass condition: `len(result) == 3` and IDs match

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: Smoke check pass — `production/qa/smoke-[date].md` documenting EnemyCatalog startup with zero `push_error()` calls

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (EnemyCatalog must be implemented and functional before `.tres` files are verified at runtime); ADR-0006 `.tres` enum verification gate must be documented before authoring `.tres` files
- Unlocks: Epic complete — Enemy Data foundation is functional; downstream epics (Enemy AI, Wave/Encounter System) can consume EnemyCatalog
