# Story 003: Non-Primary Modifier Resolution

> **Epic**: Combination Resolution
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: ~2 hours
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-10

## Context

**GDD**: `design/gdd/combination-resolution.md`
**Requirement**: `TR-CR-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Signal-Driven Architecture)
**ADR Decision Summary**: Non-primary modifier data passes through `combo_resolved(spell_effect)` in the `non_primary_modifiers` array — no direct cross-system queries. SpellCastingEffects reads the modifier fields from this payload.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: All required GDScript patterns (loops, typed arrays, dictionary checks) are unchanged since Godot 4.0.

**Control Manifest Rules (Core layer)**:
- Required: non-primary types evaluated independently per type (no interaction between types at CR level)
- Forbidden: hardcoded Prana type IDs or tier values in conditional branches; non-primary thresholds must be constants
- Guardrail: `NP_TIER2_MIN = 3` is a tuning knob — must be a named constant, not a raw literal

---

## Acceptance Criteria

*From GDD `design/gdd/combination-resolution.md` ACs CR-07 through CR-11:*

- [ ] **AC-CR-07**: slot 4 = Ashfire lv.1 (primary), slot 0 = Deepfrost lv.2 (non-centre); `effective_nonprimary_count(Deepfrost) = 2`; `non_primary_modifiers` contains Deepfrost at `tier == 1`
- [ ] **AC-CR-08**: Stormgold primary; no Deepfrost in non-centre slots; `non_primary_modifiers` contains no Deepfrost entry
- [ ] **AC-CR-09**: (a) Deepfrost count 1 → tier 1; (b) Deepfrost count 2 → tier 1 (both count 1 and count 2 produce tier 1)
- [ ] **AC-CR-10**: (a) Deepfrost effective count 2 → `NonPrimaryModifier.tier == 1`; (b) count 3 → `tier == 2` (T1/T2 seam)
- [ ] **AC-CR-11**: Stormgold primary; Ashfire lv.2 in slot 0 (count 2 → tier 1); Deepfrost lv.1 in slot 1 (count 1 → tier 1); Verdant lv.1 in slot 2 (count 1 → tier 1); `non_primary_modifiers.size() == 3`; no Stormgold entry

---

## Implementation Notes

*From GDD Formulas 3–4 and Rule 7 (multiple types stack):*

**Formula 3 — Effective non-primary count per type:**
```gdscript
# NON_CENTRE_SLOTS excludes index 4 (centre)
const NON_CENTRE_SLOTS: Array[int] = [0, 1, 2, 3, 5, 6, 7, 8]

func _compute_nonprimary_count(fragments: Array, type_t: int, primary_type: int) -> int:
    if type_t == primary_type:
        return 0  # primary-type fragments never count as non-primary
    var count: int = 0
    for i in NON_CENTRE_SLOTS:
        var frag = fragments[i]
        if frag != null and frag.type_id == type_t:
            count += frag.level
    return count
```

**Formula 4 — Non-primary tier lookup:**
```gdscript
const NP_TIER2_MIN: int = 3   # tuning knob

func _compute_nonprimary_tier(effective_count: int) -> int:
    if effective_count <= 0:
        return 0  # inactive
    elif effective_count < NP_TIER2_MIN:
        return 1
    else:
        return 2
```

**Building non_primary_modifiers array:**
```gdscript
# Iterate all 5 Prana types; skip primary type
const ALL_TYPES: Array[int] = [0, 1, 2, 3, 4]

func _build_nonprimary_modifiers(fragments: Array, primary_type: int) -> Array:
    var modifiers: Array = []
    for t in ALL_TYPES:
        if t == primary_type:
            continue
        var count: int = _compute_nonprimary_count(fragments, t, primary_type)
        var tier: int = _compute_nonprimary_tier(count)
        if tier == 0:
            continue  # inactive — no modifier entry
        var mod: NonPrimaryModifier = NonPrimaryModifier.new()
        mod.type_id = t
        mod.tier = tier
        # burn_bonus, window_extension, etc. are set in Story 004 (payload assembly)
        # where type-specific modifier values are filled from GDD Formula 6
        modifiers.append(mod)
    return modifiers
```

**Type-specific modifier field values** (GDD Formula 6) are filled in Story 004's payload assembly step — this story only populates `type_id` and `tier`. The fields for `burn_bonus`, `window_extension`, etc. default to 0.0/false per NonPrimaryModifier defaults.

---

## Out of Scope

- [Story 004]: Filling type-specific modifier field values (burn_bonus, window_extension, etc.) from GDD Formula 6
- [Story 001]: NonPrimaryModifier class definition

---

## QA Test Cases

**Test file**: `tests/unit/combination-resolution/nonprimary_resolution_test.gd`

- **AC-CR-07**: Non-centre fragment contributes to non-primary count
  - Given: slot 4 = Ashfire (0) lv.1, slot 0 = Deepfrost (3) lv.2; rest null
  - Then: `non_primary_modifiers` has Deepfrost entry with `tier == 1`
  - Edge: `effective_nonprimary_count(Deepfrost) = 2` → tier 1 (not tier 2)

- **AC-CR-08**: Absent non-primary type produces no entry
  - Given: Stormgold primary; no Deepfrost in non-centre slots
  - Then: no Deepfrost `NonPrimaryModifier` in result

- **AC-CR-09**: Count 1 and count 2 both → tier 1
  - Given: (a) one Deepfrost lv.1, (b) two Deepfrost lv.1 fragments in non-centre
  - Then: both produce `tier == 1`

- **AC-CR-10**: T1/T2 seam at count 3
  - Given: (a) Deepfrost levels summing to 2; (b) summing to 3
  - Then: (a) tier 1; (b) tier 2

- **AC-CR-11**: Three non-primaries active simultaneously
  - Given: Stormgold primary; Ashfire tier 1 (count 2); Deepfrost tier 1 (count 1); Verdant tier 1 (count 1)
  - Then: `non_primary_modifiers.size() == 3`; no Stormgold entry
  - Edge: exactly three entries — not four, not two

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combination-resolution/nonprimary_resolution_test.gd` — must exist and pass headless

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 DONE (NonPrimaryModifier class), Story 002 DONE (primary_type established before non-primary loop runs)
- Unlocks: Story 004 (fills type-specific modifier field values on top of tier)
