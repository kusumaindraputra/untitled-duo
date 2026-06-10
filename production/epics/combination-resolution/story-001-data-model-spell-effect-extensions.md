# Story 001: PranaFragment Data Model and SpellEffect Extensions

> **Epic**: Combination Resolution
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: ~2 hours
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-10

## Context

**GDD**: `design/gdd/combination-resolution.md`
**Requirement**: `TR-CR-001`, `TR-CR-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Isometric + Resource Pipeline), ADR-0008 (PranaCatalog Immutability)
**ADR Decision Summary**: All combination data lives in external Resource files — no hardcoded rules in code. SpellEffect is extended as a typed Resource schema carrying all wave-scoped payload fields.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Dictionary[StringName, float]` typed dict requires Godot 4.4+ — satisfied by project pin. Use untyped `Dictionary` for `@export` fields (typed dicts cannot be exported in GDScript 4.6 — see existing SpellEffect comment). `duplicate_deep()` required for any PranaType reads (ADR-0008).

**Control Manifest Rules (Core layer)**:
- Required: all shared enums in `game_enums.gd`, not in system files
- Forbidden: hardcoded PranaType data; `duplicate(true)` (deprecated); class_name matching Autoload node name
- Guardrail: do NOT register new Autoloads — these are plain Resource/RefCounted files

---

## Acceptance Criteria

*Foundation for all subsequent CR stories — no GDD ACs directly tested here; correctness verified by downstream tests.*

- [ ] `PranaFragment` resource exists at `src/data/prana_fragment.gd` with fields: `type_id: int`, `level: int`, `stat_property: Dictionary`, `adjacency_effects: Array`
- [ ] `NeighborCondition` resource exists at `src/data/neighbor_condition.gd` with fields: `direction: int` (enum index), `required_type_id: int` (-1 = wildcard)
- [ ] `AdjacencyEffect` resource exists at `src/data/adjacency_effect.gd` with fields: `required_neighbors: Array[NeighborCondition]`, `effect_id: StringName` (identifies the EffectModifier from pool)
- [ ] `NonPrimaryModifier` resource exists at `src/data/non_primary_modifier.gd` with all fields from GDD Section C Rule 11b: `type_id`, `tier`, `burn_bonus`, `window_extension`, `final_attack_stun`, `heal_amplifier`, `freeze_duration`, `chill_slow_pct`
- [ ] `SpellEffect` extended with: `primary_base_status: int` (GameEnums.BaseStatus enum index, default -1), `non_primary_modifiers: Array` (holds NonPrimaryModifier instances), `active_adjacency_effects: Array` (holds StringName effect IDs)
- [ ] All new files load cleanly in Godot 4.6 without parse errors

---

## Implementation Notes

*From GDD Section C Rules 1, 11, 11b and ADR-0008:*

**PranaFragment** (GDD Rule 1):
```gdscript
class_name PranaFragment
extends Resource

@export var type_id: int = -1         # 0–4; -1 = invalid/empty
@export var level: int = 1            # ≥ 1
@export var stat_property: Dictionary = {}   # {StringName: float}, e.g. {&"ASH_DMG": 5.0}
@export var adjacency_effects: Array = []    # Array[AdjacencyEffect]
```

**NeighborCondition** (GDD Rule 9 — cardinal neighbor lookup):
```gdscript
class_name NeighborCondition
extends Resource

enum Direction { ABOVE = 0, BELOW = 1, LEFT = 2, RIGHT = 3 }

@export var direction: int = Direction.ABOVE
@export var required_type_id: int = -1  # -1 = any type (wildcard)
```

**AdjacencyEffect** (GDD Rule 1 — each fragment carries N of these, N = level):
```gdscript
class_name AdjacencyEffect
extends Resource

@export var required_neighbors: Array = []   # Array[NeighborCondition]; empty = always fires
@export var effect_id: StringName = &""      # e.g. &"ADJ_DOUBLE_HIT"
```

**NonPrimaryModifier** (GDD Rule 11b — defaults match "not active" state):
```gdscript
class_name NonPrimaryModifier
extends Resource

@export var type_id: int = -1
@export var tier: int = 1
@export var burn_bonus: float = 0.0
@export var window_extension: float = 0.0
@export var final_attack_stun: bool = false
@export var heal_amplifier: float = 1.0       # 1.0 = no amplification
@export var freeze_duration: float = 0.0
@export var chill_slow_pct: float = 0.0
```

**SpellEffect extensions** — add to existing `src/data/spell_effect.gd`:
```gdscript
## Primary type's base_status from PranaCatalog (GDD Rule 11).
## GameEnums.BaseStatus enum value. SC&E applies this on every primary attack.
## -1 = unset (invalid SpellEffect).
@export var primary_base_status: int = -1

## Active non-primary type modifiers for this wave (GDD Rule 11).
## Array[NonPrimaryModifier]. Empty if no non-primary types meet threshold.
@export var non_primary_modifiers: Array = []

## Active adjacency effects whose conditions were satisfied (GDD Rule 8).
## Array[StringName] effect IDs — e.g. [&"ADJ_DOUBLE_HIT", &"ADJ_PIERCE"].
@export var active_adjacency_effects: Array = []
```

**Note on EffectModifier pool**: At this story's scope, effect IDs are `StringName` constants (e.g. `&"ADJ_DOUBLE_HIT"`). A typed EffectModifier Resource class may be introduced later when the full adjacency pool is wired to SC&E — out of scope here.

---

## Out of Scope

- [Story 002]: Primary resolution algorithm (uses PranaFragment types defined here)
- [Story 003]: Non-primary modifier resolution (populates non_primary_modifiers)
- [Story 004]: PranaCatalog reads, stat aggregation (populates primary_base_status, aggregate_stat_bonus)
- [Story 005]: Adjacency evaluation algorithm (populates active_adjacency_effects)

---

## QA Test Cases

**Test file**: `tests/unit/combination-resolution/data_model_test.gd`

- **Schema test — PranaFragment defaults**
  - Given: `PranaFragment.new()` called with no arguments
  - When: fields accessed
  - Then: `type_id == -1`, `level == 1`, `stat_property == {}`, `adjacency_effects == []`

- **Schema test — NonPrimaryModifier defaults**
  - Given: `NonPrimaryModifier.new()`
  - Then: `heal_amplifier == 1.0`, `final_attack_stun == false`, `burn_bonus == 0.0`, all floats at 0.0

- **Schema test — SpellEffect extensions**
  - Given: `SpellEffect.new()`
  - Then: `primary_base_status == -1`, `non_primary_modifiers == []`, `active_adjacency_effects == []`

- **Schema test — AdjacencyEffect empty required_neighbors**
  - Given: `AdjacencyEffect.new()` with `required_neighbors = []`
  - Then: no error; `required_neighbors.size() == 0` (vacuously satisfied per GDD Rule 8)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combination-resolution/data_model_test.gd` — must exist and pass headless

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None — this is the foundation story for the CR epic
- Unlocks: Story 002 (primary resolution), Story 003 (non-primary), Story 005 (adjacency)
