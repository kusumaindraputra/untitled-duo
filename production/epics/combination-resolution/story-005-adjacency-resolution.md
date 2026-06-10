# Story 005: Adjacency Effect Resolution

> **Epic**: Combination Resolution
> **Status**: Done
> **Layer**: Core
> **Type**: Logic
> **Estimate**: ~3 hours
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-10

## Context

**GDD**: `design/gdd/combination-resolution.md`
**Requirement**: `TR-CR-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Signal-Driven Architecture)
**ADR Decision Summary**: Adjacency effects are collected by CR and delivered in `SpellEffect.active_adjacency_effects` via `combo_resolved`. SpellCastingEffects is responsible for applying them during chain execution — CR only evaluates and collects.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Integer division (`/`) and modulo (`%`) for row/col calculation are stable in GDScript. Array index bounds checking with explicit `if` guards (not try/catch) is the correct GDScript pattern.

**Control Manifest Rules (Core layer)**:
- Required: cardinal neighbor calculation must use the GDD's exact slot-to-row/col formula (Rule 9)
- Forbidden: any adjacency condition that relies on SceneTree state (nodes, positions); conditions are pure data — no engine calls
- Guardrail: out-of-bounds neighbor = condition unsatisfied, NOT an error (GDD Rule 9 explicitly)

---

## Acceptance Criteria

*From GDD `design/gdd/combination-resolution.md` ACs CR-16 through CR-23:*

- [x] **AC-CR-16**: slot 4 = Ashfire with one adjacency effect `required_neighbors = []`, `effect_id = ADJ_DOUBLE_HIT`; all surrounding slots null; `active_adjacency_effects` contains `&"ADJ_DOUBLE_HIT"`
- [x] **AC-CR-17**: slot 4 with `required_neighbors = [{ABOVE, type 0}, {BELOW, type 0}]`, effect = ADJ_BURN_INTENSIFY; slot 1 (ABOVE) = Ashfire; slot 7 (BELOW) = Ashfire; `active_adjacency_effects` contains `&"ADJ_BURN_INTENSIFY"`
- [x] **AC-CR-18**: Same fragment as AC-CR-17 but slot 7 = null or Deepfrost; `active_adjacency_effects` does NOT contain `&"ADJ_BURN_INTENSIFY"` (partial AND not satisfied)
- [x] **AC-CR-19**: slot 0 (top-left corner, row 0) with `required_neighbors = [{ABOVE, type -1}]`; no row above slot 0; effect absent from `active_adjacency_effects`; no `push_error`
- [x] **AC-CR-20**: slot 4 with `required_neighbors = [{LEFT, type -1}]`; slot 3 = null; effect absent (null occupant does not satisfy any condition)
- [x] **AC-CR-21**: slot 4 with `required_neighbors = [{RIGHT, type 2}]` (requires Stormgold); slot 5 = Deepfrost; effect absent (wrong type)
- [x] **AC-CR-22**: slot 4 with `required_neighbors = [{RIGHT, type -1}]`; slot 5 = Deepfrost lv.1; effect present (wildcard accepts any non-null type)
- [x] **AC-CR-23**: slot 4 = ADJ_DOUBLE_HIT (no condition); slot 0 = Deepfrost with ADJ_STATUS_EXTEND requiring `{BELOW: any type}`; slot 3 (BELOW slot 0) = Ashfire lv.1; `active_adjacency_effects.size() == 2` containing both effects

---

## Implementation Notes

*From GDD Rule 8 (adjacency evaluation loop) and Rule 9 (cardinal neighbor lookup):*

**Cardinal neighbor lookup (GDD Rule 9):**
```gdscript
# Slot i → row r = i / 3 (integer div), col c = i % 3
const DIRECTION_ABOVE: int = 0
const DIRECTION_BELOW: int = 1
const DIRECTION_LEFT: int = 2
const DIRECTION_RIGHT: int = 3

func _get_neighbor_slot(slot: int, direction: int) -> int:
    var r: int = slot / 3
    var c: int = slot % 3
    match direction:
        DIRECTION_ABOVE:
            if r <= 0: return -1        # out of bounds
            return slot - 3
        DIRECTION_BELOW:
            if r >= 2: return -1
            return slot + 3
        DIRECTION_LEFT:
            if c <= 0: return -1
            return slot - 1
        DIRECTION_RIGHT:
            if c >= 2: return -1
            return slot + 1
    return -1  # invalid direction
```

**Condition satisfaction check (GDD Rule 8):**
```gdscript
func _is_condition_satisfied(fragments: Array, slot: int, condition: NeighborCondition) -> bool:
    var neighbor_slot: int = _get_neighbor_slot(slot, condition.direction)
    if neighbor_slot == -1:                             # out of bounds
        return false
    var neighbor = fragments[neighbor_slot]
    if neighbor == null:                                # empty slot
        return false
    if condition.required_type_id != -1:               # typed condition
        if neighbor.type_id != condition.required_type_id:
            return false
    return true                                         # wildcard or matched type
```

**Main adjacency resolution loop (GDD Rule 8):**
```gdscript
func _collect_adjacency_effects(fragments: Array) -> Array:
    var collected: Array = []
    for i in range(9):
        var frag = fragments[i]
        if frag == null:
            continue
        for adj_effect in frag.adjacency_effects:
            var satisfied: bool = true
            for condition in adj_effect.required_neighbors:  # AND logic
                if not _is_condition_satisfied(fragments, i, condition):
                    satisfied = false
                    break
            if satisfied:
                collected.append(adj_effect.effect_id)  # StringName
    return collected
```

**Empty `required_neighbors` = vacuously satisfied** (GDD Rule 8 note): the inner `for condition` loop never executes; `satisfied` remains `true`. `ADJ_DOUBLE_HIT` uses this pattern.

**Multiple effects from multiple fragments**: all satisfied effects across all fragments are collected. No deduplication — two instances of the same effect_id both appear (e.g., two ADJ_DOUBLE_HIT effects from two separate fragments both collect).

---

## Out of Scope

- [Story 001]: AdjacencyEffect, NeighborCondition class definitions
- [Story 004]: STAT_BONUS adjacency effects contributing to aggregate_stat_bonus
- [Story 006]: ADJ_ECHO mid-delay cancel (requires timer, not pure data resolution)
- SC&E: applying adjacency effects during chain execution — CR only collects

---

## QA Test Cases

**Test file**: `tests/unit/combination-resolution/adjacency_resolution_test.gd`

- **AC-CR-16**: No-condition effect always fires
  - Given: slot 4 + ADJ_DOUBLE_HIT with empty required_neighbors; all other slots null
  - Then: `active_adjacency_effects` contains `&"ADJ_DOUBLE_HIT"`

- **AC-CR-17**: AND conditions — all satisfied → effect fires
  - Given: slot 4 requires ABOVE=Ashfire AND BELOW=Ashfire; slot 1 = Ashfire; slot 7 = Ashfire
  - Then: ADJ_BURN_INTENSIFY in active_adjacency_effects

- **AC-CR-18**: AND conditions — partial satisfaction → effect does NOT fire
  - Given: same fragment; slot 7 = null or Deepfrost
  - Then: ADJ_BURN_INTENSIFY absent
  - Edge: must not trigger with only one of two AND conditions met

- **AC-CR-19**: Out-of-bounds direction → unsatisfied, no error
  - Given: slot 0 (top row), ABOVE condition
  - Then: effect absent; no push_error output

- **AC-CR-20**: Null neighbor does not satisfy any condition
  - Given: slot 4, LEFT condition, slot 3 = null
  - Then: effect absent

- **AC-CR-21**: Wrong type does not satisfy typed condition
  - Given: RIGHT = Stormgold (type 2) required; slot 5 = Deepfrost (type 3)
  - Then: effect absent

- **AC-CR-22**: Wildcard (-1) accepts any present non-null type
  - Given: RIGHT = type -1; slot 5 = Deepfrost lv.1
  - Then: effect present

- **AC-CR-23**: Multiple fragments, multiple effects collected
  - Given: slot 4 ADJ_DOUBLE_HIT (no condition) + slot 0 ADJ_STATUS_EXTEND (BELOW=any, satisfied by slot 3)
  - Then: `active_adjacency_effects.size() == 2`, both effects present

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combination-resolution/adjacency_resolution_test.gd` — must exist and pass headless

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 DONE (AdjacencyEffect, NeighborCondition classes)
- Unlocks: Story 006 (integration test validates the full pipeline including adjacency collection)
