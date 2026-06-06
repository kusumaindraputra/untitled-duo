# Story 001: SpellEffect Resource, Stub CR, and SC&E Autoload Skeleton

> **Epic**: Spell Casting & Effects
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: ~2 hours
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-06

## Context

**GDD**: `design/gdd/spell-casting-effects.md`
**Requirement**: `TR-SC-001`, `TR-SC-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009: SC&E Wave-Scoped Stat Broker (primary)
**ADR Decision Summary**: SpellCastingEffects is the sole owner of the wave's SpellEffect payload and exposes `get_stat_bonus(stat_id: StringName) -> float` as the sole stat query interface. Cache cleared in `_on_preparation_started()`; set in `_on_combo_resolved()`.

**Secondary ADRs**: ADR-0003 (Signal-Driven Architecture — connect in _ready, disconnect in _exit_tree); ADR-0002 (Autoload #8 = CombinationResolution, #9 = SpellCastingEffects — must both be registered)

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Dictionary[StringName, float]` typed dict is post-cutoff (added Godot 4.4); project's 4.6 pin satisfies this per ADR-0009. No class_name may match an Autoload node name — omit class_name from spell_casting_effects.gd (same pattern as HealthAndDamage).

**Control Manifest Rules (Core Layer)**:
- Required: Register SpellCastingEffects as Autoload #9; CombinationResolution as Autoload #8 — both in project.godot
- Required: Connect to signals in `_ready()`, disconnect in `_exit_tree()`
- Required: `get_stat_bonus(stat_id: StringName) -> float` returns 0.0 when `_current_spell_effect == null`
- Forbidden: No other Autoload may subscribe to `combo_resolved` for SpellEffect caching (ADR-0009)
- Forbidden: No class_name that matches the Autoload node name (ADR-0002 parse-error guard)

---

## Acceptance Criteria

*From GDD `design/gdd/spell-casting-effects.md`, scoped to this story:*

- [ ] **AC-SC-01** — IDLE → READY on `_on_combo_resolved(spell_effect)` called with `spell_effect.primary_type >= 0` while `_in_combat == true`: `_state == READY` and `_combo_index == 0`
- [ ] **AC-SC-06** — `_on_preparation_started()` resets all wave state: `_state == IDLE`, `_combo_index == 0`, `_current_spell_effect == null`
- [ ] **AC-SC-24** — `_on_combo_resolved(spell_effect)` with `spell_effect.primary_type == -1`: `push_error()` called; `_state` remains IDLE; subsequent cast press produces no attack

---

## Implementation Notes

*Derived from ADR-0009, ADR-0002, ADR-0003:*

**1. SpellEffect Resource** (`src/data/spell_effect.gd`):
- `class_name SpellEffect extends Resource`
- `@export var primary_type: int = -1` — 0=Ashfire, 1=Voidblue, 2=Stormgold, 3=Deepfrost, 4=Verdant; -1 = invalid
- `@export var primary_tier: int = 1` — 1/2/3 = chain attack count
- `@export var base_damage_modifier: float = 1.0` — per-type multiplier
- `@export var combo_attack_count: int = 1` — mirrors primary_tier at FP
- `@export var aggregate_stat_bonus: Dictionary = {}` — stat deltas; empty at FP (CR not yet implemented)

**2. FP Stub CombinationResolution** (`src/systems/combination_resolution.gd`):
- `extends Node` (no class_name — Autoload node name collision guard)
- Declares `signal combo_resolved(spell_effect: SpellEffect)`
- Connects to `GameStateManager.combat_started` in `_ready()`; disconnects in `_exit_tree()`
- On `_on_combat_started(is_boss: bool)`: creates and emits a hardcoded Ashfire T1 SpellEffect (primary_type=0, primary_tier=1, base_damage_modifier=1.25, combo_attack_count=1, aggregate_stat_bonus={})
- Purpose: satisfies control-manifest rule (all 10 Autoloads registered), enables SC&E to transition from IDLE to READY during FP gameplay

**3. SpellCastingEffects skeleton** (`src/systems/spell_casting_effects.gd`):
- `extends Node` (no class_name — Autoload node name collision; accessed as `SpellCastingEffects` global)
- State enum: `enum SCEState { IDLE = 0, READY = 1, CHAINING = 2, CAST_LOCKED = 3 }`
- Declare signals: `signal spell_hit_element(target: Node, prana_type_id: int)`, `signal cast_hit_started(lock_duration: float)`, `signal chain_index_changed(combo_index: int, combo_attack_count: int)`
- Private state vars: `_state: SCEState = SCEState.IDLE`, `_combo_index: int = 0`, `_current_spell_effect: SpellEffect = null`, `_in_combat: bool = false`
- `process_mode = PROCESS_MODE_PAUSABLE` (rule from control manifest + ADR-0004)
- `_ready()`: connect to `GameStateManager.preparation_started`, `GameStateManager.combat_started`, `CombinationResolution.combo_resolved`
- `_exit_tree()`: disconnect all three with `is_connected()` guards (ADR-0003 Rule 4)
- `_on_preparation_started(_idx: int, _rem: int)`: reset `_state = IDLE`, `_combo_index = 0`, `_in_combat = false`, `_current_spell_effect = null`
- `_on_combat_started(_is_boss: bool)`: set `_in_combat = true`
- `_on_combo_resolved(spell_effect: SpellEffect)`: guard `primary_type == -1` → push_error + return; else `_current_spell_effect = spell_effect`, `_state = SCEState.READY`, `_combo_index = 0`
- `get_stat_bonus(stat_id: StringName) -> float`: per ADR-0009 — return 0.0 if null, else `_current_spell_effect.aggregate_stat_bonus.get(stat_id, 0.0)`

**4. Autoload registration in project.godot**:
- Add CombinationResolution: `[autoload] CombinationResolution="*res://src/systems/combination_resolution.gd"`
- Add SpellCastingEffects: `[autoload] SpellCastingEffects="*res://src/systems/spell_casting_effects.gd"`
- Confirm ordering: #8 CombinationResolution, #9 SpellCastingEffects

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 002]: _process() input loop, float accumulators, cast_hit_started, chain_index_changed
- [Story 003]: ATTACK_DATA, _fire_attack(), damage formula, spell_hit_element
- [Story 004]: Integration test

---

## QA Test Cases

*From qa-plan-sprint-3-2026-06-03.md (S3-08 section). Implement against these.*

**Test file**: `tests/unit/spell-casting-effects/sce_skeleton_test.gd`

- **AC-SC-01**: IDLE → READY on combo_resolved
  - Given: SC&E in IDLE, `_in_combat = true` (set via `_on_combat_started(false)`)
  - When: `_on_combo_resolved(SpellEffect.new() with primary_type=0)` called
  - Then: `_state == READY`, `_combo_index == 0`
  - Edge cases: primary_type=4 (Verdant) — still transitions to READY

- **AC-SC-06**: preparation_started resets all state
  - Given: SC&E in CHAINING state, `_combo_index=1`, `_current_spell_effect` non-null
  - When: `_on_preparation_started(0, 1)` called
  - Then: `_state == IDLE`, `_combo_index == 0`, `_current_spell_effect == null`

- **AC-SC-24**: combo_resolved with primary_type == -1 does not enter READY
  - Given: SC&E in IDLE
  - When: `_on_combo_resolved(SpellEffect with primary_type=-1)` called
  - Then: `_state == IDLE`; subsequent simulated cast produces no attack
  - Edge cases: push_error was called (cannot assert directly; verify state is the observable contract)

- **Additional**: get_stat_bonus() returns 0.0 when cache is null
  - Given: SC&E with `_current_spell_effect = null`
  - When: `get_stat_bonus(&"ASH_DMG")` called
  - Then: returns `0.0`

- **Additional**: get_stat_bonus() returns correct value from cached SpellEffect
  - Given: `_current_spell_effect.aggregate_stat_bonus = {"ASH_DMG": 5.0}`
  - When: `get_stat_bonus(&"ASH_DMG")` called
  - Then: returns `5.0`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/spell-casting-effects/sce_skeleton_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: WaveManager S3-07 DONE (confirms Autoload chain up to #7 stable); GameStateManager Story 001 DONE (preparation_started, combat_started signals)
- Unlocks: Story 002 (needs SC&E state machine + _in_combat flag to implement cast gating)
