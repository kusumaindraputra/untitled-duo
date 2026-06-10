# Story 004: SpellEffect Payload Assembly

> **Epic**: Combination Resolution
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: ~2 hours
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-10

## Context

**GDD**: `design/gdd/combination-resolution.md`
**Requirement**: `TR-CR-001`, `TR-CR-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008 (PranaCatalog Immutability), ADR-0009 (SC&E Wave-Scoped Stat Broker)
**ADR Decision Summary**: CR reads `base_damage_modifier` and `base_status` via `PranaCatalog.get_type(id)` (always returns `duplicate_deep()`). CR populates `aggregate_stat_bonus` from fragment `stat_property` dictionaries. SpellCastingEffects is the sole reader of `aggregate_stat_bonus` outside CR.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `duplicate_deep()` — introduced Godot 4.5; replaces deprecated `duplicate(true)`. PranaCatalog already uses this (ADR-0008 verified). `Dictionary.merge()` or manual key iteration needed for stat aggregation — `Dictionary.merge()` is available in Godot 4.x; verify it is additive (it is NOT — it overwrites). Use manual loop for additive stat stacking.

**Control Manifest Rules (Core layer)**:
- Required: `PranaCatalog.get_type(id)` for all PranaType data reads — never cache a direct reference
- Forbidden: direct access to `PranaCatalog._types` array; hardcoded `base_damage_modifier` values; `aggregate_stat_bonus` read outside SC&E
- Guardrail: `aggregate_stat_bonus` keys are `StringName` (e.g. `&"ASH_DMG"`) — never `String`

---

## Acceptance Criteria

*From GDD `design/gdd/combination-resolution.md` ACs CR-13 through CR-15 and CR-29:*

- [ ] **AC-CR-13**: slot 4 = Verdant lv.1 (primary); `PranaCatalog.get_type(4)` returns `base_damage_modifier = 0.70` and `base_status = REGENERATE`; `SpellEffect.base_damage_modifier == 0.70`; `SpellEffect.primary_base_status == REGENERATE`
- [ ] **AC-CR-14**: Slot 4 = Ashfire `stat_property = {ASH_DMG: 5}`, slot 0 = Deepfrost `stat_property = {FROST_DMG: 3}`, slot 2 = Verdant `stat_property = {VER_HEAL_FLAT: 2}`; no adjacency conditions satisfied; `aggregate_stat_bonus == {ASH_DMG: 5, FROST_DMG: 3, VER_HEAL_FLAT: 2}`
- [ ] **AC-CR-15**: Slot 4 = Ashfire `stat_property = {ASH_DMG: 5}` + one adjacency effect with `required_neighbors = []` (always fires) + `effect_id = ADJ_STAT_BONUS` carrying `{ASH_DMG: 10}`; `aggregate_stat_bonus["ASH_DMG"] == 15`
- [ ] **AC-CR-29**: slot 4 = Ashfire lv.1, slot 0 = Deepfrost lv.1 (non-primary tier 1); `SpellEffect.primary_base_status == GameEnums.BaseStatus.BURN`; `non_primary_modifiers.size() == 1` with `type_id == 3` and `tier == 1`; confirms SC&E contract — `primary_base_status` is always populated regardless of `non_primary_modifiers` content

---

## Implementation Notes

*From GDD Rules 10–11 and Formulas 5–8:*

**PranaCatalog reads (Rule 11):**
```gdscript
func _populate_from_catalog(effect: SpellEffect, primary_type: int) -> void:
    var prana_type = PranaCatalog.get_type(primary_type)  # always duplicate_deep()
    effect.base_damage_modifier = prana_type.base_damage_modifier
    effect.primary_base_status = prana_type.base_status   # GameEnums.BaseStatus int
```

**Stat aggregation — Rule 10 (always active, all placed fragments):**
```gdscript
func _aggregate_stat_bonus(fragments: Array) -> Dictionary:
    var bonus: Dictionary = {}
    for frag in fragments:
        if frag == null:
            continue
        for key in frag.stat_property:
            if bonus.has(key):
                bonus[key] += frag.stat_property[key]
            else:
                bonus[key] = frag.stat_property[key]
    return bonus
```
**Important:** do NOT use `Dictionary.merge()` for additive stacking — it overwrites existing keys. Use the manual `has()` / `+=` loop above.

**Triggered adjacency STAT_BONUS (AC-CR-15):**
When `active_adjacency_effects` (from Story 005) contains an effect of type `STAT_BONUS`, its key/value must be added to `aggregate_stat_bonus`. At this story's scope, this can be structured as: adjacency effects that carry `effect_id == &"ADJ_STAT_BONUS"` also carry a `stat_key: StringName` and `stat_value: float` — or defer to Story 005's adjacency resolution. The AC-CR-15 test must pass with Story 005's integration.

**Non-primary modifier field values (GDD Formula 6):**
After Story 003 builds `non_primary_modifiers` with `type_id` and `tier`, this story fills the type-specific fields:
```gdscript
# Example for Stormgold T1 non-primary:
mod.window_extension = STORMGOLD_NP_WINDOW_T1  # 0.3s
# Stormgold T2 additionally:
mod.final_attack_stun = true

# Ashfire T2:
mod.burn_bonus = ASHFIRE_NP_BONUS  # 0.15

# Deepfrost T1:
mod.chill_slow_pct = CHILL_SLOW_PCT  # 0.15
# Deepfrost T2:
mod.freeze_duration = NONPRIMARY_FREEZE_DURATION  # 1.0

# Verdant T2:
mod.heal_amplifier = VERDANT_NP_HEAL_AMP  # 1.25
```
All modifier constants are `const` values — not magic numbers.

---

## Out of Scope

- [Story 005]: Adjacency effect condition evaluation (populates `active_adjacency_effects`)
- [Story 006]: Null-slot edge cases; signal emission guard

---

## QA Test Cases

**Test file**: `tests/unit/combination-resolution/payload_assembly_test.gd`

- **AC-CR-13**: PranaCatalog fields populate SpellEffect correctly
  - Given: mock PranaCatalog returning `{base_damage_modifier: 0.70, base_status: REGENERATE}` for type 4
  - When: Verdant primary resolved
  - Then: `spell_effect.base_damage_modifier == 0.70`, `spell_effect.primary_base_status == GameEnums.BaseStatus.REGENERATE`
  - Use a test double for PranaCatalog returning known values

- **AC-CR-14**: Stat aggregation sums all fragment stat_properties
  - Given: 3 fragments with distinct stat keys, no adjacency conditions
  - Then: `aggregate_stat_bonus == {ASH_DMG: 5, FROST_DMG: 3, VER_HEAL_FLAT: 2}`; no extra keys

- **AC-CR-14 additive stacking**: Two fragments with same stat key
  - Given: slot 4 = Ashfire `{ASH_DMG: 5}`, slot 0 = Ashfire `{ASH_DMG: 3}`
  - Then: `aggregate_stat_bonus["ASH_DMG"] == 8` (additive, not overwrite)

- **AC-CR-15**: Triggered adjacency STAT_BONUS adds to aggregate
  - Given: slot 4 with `stat_property = {ASH_DMG: 5}` + `required_neighbors = []` adjacency with `{ASH_DMG: 10}`
  - Then: `aggregate_stat_bonus["ASH_DMG"] == 15`

- **AC-CR-29**: primary_base_status populated alongside non_primary_modifiers
  - Given: Ashfire primary + Deepfrost non-primary tier 1
  - Then: `primary_base_status == BURN`, `non_primary_modifiers.size() == 1` with `type_id == 3, tier == 1`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combination-resolution/payload_assembly_test.gd` — must exist and pass headless

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 DONE (NonPrimaryModifier, PranaFragment), Story 002 DONE (primary_type resolved), Story 003 DONE (non_primary_modifiers tier populated)
- Unlocks: Story 005 (adjacency STAT_BONUS contributes to aggregate), Story 006 (full payload ready for integration test)
