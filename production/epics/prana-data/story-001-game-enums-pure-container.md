# Story 001: GameEnums Pure Container

> **Epic**: Prana Data
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (2–3 hours)
> **Manifest Version**: 2026-05-30
> **Last Updated**: 2026-05-30

## Context

**GDD**: `design/gdd/prana-data.md`
**Requirements**: `TR-PD-003`, `TR-PD-004`

*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: GameEnums as Pure Enum Container
**ADR Decision Summary**: `game_enums.gd` uses `class_name GameEnums extends RefCounted`, is NOT an Autoload, and contains only enum definitions with explicit integer assignments for `.tres` serialization stability.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `.tres` enum serialization behavior (int vs string) must be verified before authoring any `.tres` files — create a throwaway Resource with an `@export var` enum field, inspect the saved `.tres` in a text editor, and record whether the value is stored as an integer or a string name. This verification gate is required before Story 004.

**Control Manifest Rules (Foundation Layer)**:
- Required: `game_enums.gd`: `class_name GameEnums extends RefCounted`. NOT an Autoload. Contains only enum definitions. (ADR-0006)
- Required: All GameEnums enum constants must have explicit integer assignments. (ADR-0006)
- Required: New enum values must be appended — existing integer assignments must never be reordered or renumbered. (ADR-0006)
- Forbidden: Never add `extends Node`, `@onready`, `@export`, `preload()`, or `load()` to `game_enums.gd`. (ADR-0006)
- Forbidden: Never register GameEnums as an Autoload. (ADR-0006)
- Forbidden: Never define cross-system enum types in individual system files. (ADR-0006)

---

## Acceptance Criteria

*From GDD `design/gdd/prana-data.md` Implementation Notes and ADR-0006:*

- [x] `src/data/game_enums.gd` exists with `class_name GameEnums` and `extends RefCounted`
- [x] File contains all 11 enum types: `DamageClass`, `DamageSource`, `BaseStatus`, `HPZone`, `GameState`, `RunOutcome`, `EnemyArchetype`, `EnemyState`, `WaveState`, `CastAnimation`, `VfxBurstShape`
- [x] All enum constants have explicit integer assignments (no auto-numbering anywhere in file)
- [x] File contains NO `preload()`, `load()`, `@onready`, `@export`, or `extends` beyond `RefCounted`
- [x] `GameEnums` is NOT listed in Project Settings → AutoLoad
- [?] **Verification gate**: Throwaway `Resource` with `@export var dc: GameEnums.DamageClass` saved as `.tres`, inspected in text editor — result (integer or string) documented in implementation notes — **DEFERRED: manual gate, required before Story 004**

---

## Implementation Notes

*Derived from ADR-0006 Decision section — copy the enum block exactly:*

```gdscript
class_name GameEnums
extends RefCounted

enum DamageClass  { NONE = -1, FIRE = 0, SHADOW = 1, LIGHTNING = 2, ICE = 3, NATURE = 4 }
enum DamageSource { DIRECT = 0, DOT = 1, CONTACT = 2 }
enum BaseStatus   { BURN = 0, BLIND = 1, STUN = 2, FREEZE = 3, REGENERATE = 4,
                    CHILL = 5, STAGGER = 6 }
enum HPZone       { FULL = 0, CAREFUL = 1, DESPERATE = 2 }
enum GameState    { MAIN_MENU = 0, PREPARATION_PHASE = 1, COMBAT_PHASE = 2,
                    PAUSED = 3, RUN_SUMMARY = 4, DEATH_SCREEN = 5 }
enum RunOutcome   { NONE = 0, WIN = 1, LOSS = 2 }
enum EnemyArchetype { SEEKER = 0, RUSHER = 1, SWARMER = 2, BOSS = 3 }
enum EnemyState   { IDLE = 0, PURSUING = 1, ATTACKING = 2, STUNNED = 3, DEAD = 4 }
enum WaveState    { IDLE = 0, WAVE_ACTIVE = 1, WAVE_COMPLETE = 2 }
enum CastAnimation { CAST_THRUST = 0, CAST_REACH = 1, CAST_SNAP = 2,
                     CAST_PUSH = 3, CAST_BLOOM = 4 }
enum VfxBurstShape { BURST_FLAME = 0, BURST_SPIRAL = 1, BURST_LIGHTNING = 2,
                     BURST_CRYSTAL = 3, BURST_VINE = 4 }
```

Adding new shared enums: append to this file only. When adding values to an existing enum, append with the next integer — never reorder. `match` statements on `BaseStatus` that lack arms for `CHILL` and `STAGGER` will produce silent fall-throughs; add to code review checklist when touching this file.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: PranaType Resource schema (uses GameEnums enum types defined here)
- Story 003: PranaCatalog Autoload (validates catalog entries against GameEnums)
- Story 004: Five Prana Type .tres files (enum fields serialized as integers per verification gate above)

---

## QA Test Cases

*Written at story creation. Implement against these — do not invent new test cases during implementation.*

- **AC-1**: DamageClass enum values are stable
  - Given: game_enums.gd loaded in GUT
  - When: each DamageClass constant accessed
  - Then: `NONE == -1`, `FIRE == 0`, `SHADOW == 1`, `LIGHTNING == 2`, `ICE == 3`, `NATURE == 4`
  - Edge cases: NONE = -1 is the sentinel for unaffiliated enemies (must be negative — test explicitly)

- **AC-2**: BaseStatus includes CHILL and STAGGER at correct positions
  - Given: game_enums.gd loaded
  - When: `BaseStatus.CHILL` and `BaseStatus.STAGGER` accessed
  - Then: `CHILL == 5`, `STAGGER == 6`
  - Edge cases: Existing values BURN=0 through REGENERATE=4 unchanged — assert all five

- **AC-3**: GameState covers all 6 states
  - Given: game_enums.gd loaded
  - When: all 6 GameState constants accessed
  - Then: `MAIN_MENU == 0`, `PREPARATION_PHASE == 1`, `COMBAT_PHASE == 2`, `PAUSED == 3`, `RUN_SUMMARY == 4`, `DEATH_SCREEN == 5`

- **AC-4**: No forbidden patterns in file (CI grep, not GUT)
  - Given: game_enums.gd source file
  - When: file is grepped for `preload(`, `load(`, `@onready`, `@export`, `extends Node`
  - Then: zero matches found for all five patterns
  - Edge cases: `extends RefCounted` must be present (not just absence of forbidden patterns)

- **AC-5**: .tres verification gate documented (manual, blocks Story 004)
  - Given: Throwaway `TestResource extends Resource` with `@export var dc: GameEnums.DamageClass`
  - When: saved as `.tres` and opened in a text editor
  - Then: the value is stored as an integer (e.g., `0`) — not as a string name (`"FIRE"`)
  - Edge cases: If stored as string name, explicit integer assignments are still best practice; if integer (expected), they are safety-critical

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/prana-data/game_enums_test.gd` — must exist and pass in GUT

**Status**: [x] EXISTS — `tests/unit/prana-data/game_enums_test.gd` — 22 tests, 21 PASSED, 1 SKIPPED (AC-6 manual gate) — verified 2026-05-30 with GdUnit4 v6.1.3 + Godot 4.6.2

---

## Dependencies

- Depends on: None
- Unlocks: Story 002 (PranaType Resource Schema), Story 003 (PranaCatalog Autoload), Story 004 (verification gate result)

---

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 5/6 passing — AC-6 DEFERRED (manual .tres verification gate, blocks Story 004)
**Deviations**: ADVISORY (resolved) — `gdunit4_runner.gd` path case mismatch fixed 2026-05-30; file is now documentation-only, no load path issue
**Test Evidence**: Logic — `tests/unit/prana-data/game_enums_test.gd` — 22 tests, 21 PASSED, 1 SKIPPED (manual gate AC-6) — GdUnit4 v6.1.3, Godot 4.6.2
**Code Review**: APPROVED WITH SUGGESTIONS — applied 2026-05-30 (added GameState+EnemyState count tests, corrected RunOutcome sentinel comment)
**Infrastructure**: project.godot created 2026-05-30 (GL Compatibility renderer); GdUnit4 v6.1.3 installed; CI command: `godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a <path> --ignoreHeadlessMode`
