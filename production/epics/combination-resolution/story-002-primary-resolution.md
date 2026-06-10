# Story 002: Primary Count and Tier Resolution

> **Epic**: Combination Resolution
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: ~3 hours
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-10

## Context

**GDD**: `design/gdd/combination-resolution.md`
**Requirement**: `TR-CR-001`, `TR-CR-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Signal-Driven Architecture)
**ADR Decision Summary**: CR reads `PranaGrid.committed_fragments` via direct getter (Pattern 2 — return-value query) after `combat_started` fires. No direct state polling in `_process()`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Signal connections stable since Godot 4.0. `is_instance_valid()` can guard against null array entries if needed — prefer explicit null check (`fragment == null`) for clarity.

**Control Manifest Rules (Core layer)**:
- Required: `_on_combat_started` reads from PranaGrid via direct method call (Pattern 2)
- Forbidden: reading `PranaGrid.committed_fragments` outside signal handler context; hardcoded type IDs or tier thresholds in core logic
- Guardrail: tier thresholds (`PRIMARY_T1_MAX = 2`, `PRIMARY_T2_MAX = 5`) are constants — acceptable as typed constants (not raw literals in comparisons), tuning via GDD

---

## Acceptance Criteria

*From GDD `design/gdd/combination-resolution.md` ACs CR-01 through CR-06 and CR-12:*

- [ ] **AC-CR-01**: slot 4 = Deepfrost (type 3); slots 0, 2 = Ashfire. `SpellEffect.primary_type == 3`
- [ ] **AC-CR-02**: slot 4 = Ashfire lv.2, slot 0 = Ashfire lv.1, slot 7 = Ashfire lv.3; `effective_primary_count = 6`; `primary_tier == 3`
- [ ] **AC-CR-03**: slot 4 = Ashfire lv.1, slot 0 = Ashfire lv.1 (non-centre same type); `effective_primary_count = 2`; `primary_tier == 1`; no Ashfire entry in `non_primary_modifiers`
- [ ] **AC-CR-04**: `effective_primary_count = 2` → `primary_tier == 1`; count = 3 → `primary_tier == 2` (T1/T2 seam)
- [ ] **AC-CR-05**: `effective_primary_count = 5` → `primary_tier == 2`; count = 6 → `primary_tier == 3` (T2/T3 seam)
- [ ] **AC-CR-06**: `effective_primary_count = 10` (lv.5 fragments); `primary_tier == 3`; no error
- [ ] **AC-CR-12**: all 9 slots = Ashfire lv.1; `primary_tier == 3`; `non_primary_modifiers.size() == 0`; no error

---

## Implementation Notes

*From GDD Formulas 1–2 and ADR-0003 Pattern 2:*

**Skeleton to replace** — Story 002 replaces the hardcoded stub in `_on_combat_started`:
```gdscript
# Current FP stub (to be replaced by this story):
func _on_combat_started(_is_boss: bool) -> void:
    var effect: SpellEffect = SpellEffect.new()
    effect.primary_type = 0
    effect.primary_tier = 1
    ...
    combo_resolved.emit(effect)
```

**Formula 1 — Effective primary count:**
```gdscript
# fragments: Array of length 9; null = empty slot
func _compute_effective_primary_count(fragments: Array, primary_type: int) -> int:
    var count: int = 0
    for frag in fragments:
        if frag != null and frag.type_id == primary_type:
            count += frag.level
    return count
```

**Formula 2 — Primary tier lookup:**
```gdscript
const PRIMARY_T1_MAX: int = 2   # tuning knob
const PRIMARY_T2_MAX: int = 5   # tuning knob

func _compute_primary_tier(effective_count: int) -> int:
    if effective_count <= PRIMARY_T1_MAX:
        return 1
    elif effective_count <= PRIMARY_T2_MAX:
        return 2
    else:
        return 3
```

**PranaGrid interface contract** — `PranaGrid` must expose:
```gdscript
func get_committed_fragments() -> Array  # Array length 9, null = empty slot
```
At First Playable scope (PranaGrid not yet implemented), inject fragments via a test double or a mock getter. The story must compile and test without a live PranaGrid — use dependency injection.

**combo_attack_count**: Set to equal `primary_tier` at FP scope (`combo_attack_count = primary_tier`). The GDD formula for `combo_attack_count` from tier is 1:1 at T1/T2/T3 → 1/2/3. Non-primary modifiers may extend this in a later story.

---

## Out of Scope

- [Story 003]: Non-primary modifier count + tier (populates `non_primary_modifiers`)
- [Story 004]: PranaCatalog reads for `base_damage_modifier` + `primary_base_status`
- [Story 005]: Adjacency effect resolution
- [Story 006]: Null-slot edge cases (AC-CR-24, AC-CR-25) and exactly-once signal guard

---

## QA Test Cases

**Test file**: `tests/unit/combination-resolution/primary_resolution_test.gd`

- **AC-CR-01**: Centre type determines primary_type
  - Given: mock fragments array — slot 4 = Deepfrost (3) lv.1, slots 0+2 = Ashfire (0) lv.1, rest null
  - When: `_resolve(fragments)` called
  - Then: `spell_effect.primary_type == 3`
  - Edge: Ashfire in surrounding slots must NOT override centre

- **AC-CR-02**: Effective primary count sums levels
  - Given: slot 4 = Ashfire lv.2, slot 0 = Ashfire lv.1, slot 7 = Ashfire lv.3; rest null
  - When: resolved
  - Then: `primary_tier == 3` (effective count = 6)

- **AC-CR-03**: Non-centre same-type contributes to primary count, not non-primary
  - Given: slot 4 = Ashfire lv.1, slot 0 = Ashfire lv.1; rest null
  - Then: `primary_tier == 1`; `non_primary_modifiers` has no Ashfire entry

- **AC-CR-04**: T1/T2 seam — count 2 → tier 1; count 3 → tier 2
  - Given: two separate arrangements
  - Then: both seam assertions pass

- **AC-CR-05**: T2/T3 seam — count 5 → tier 2; count 6 → tier 3
  - Edge cases: both boundary assertions must pass

- **AC-CR-06**: Count 10 → tier 3; no push_error
  - Given: slot 4 = Ashfire lv.5, slot 0 = Ashfire lv.5

- **AC-CR-12**: All-same-type; tier 3; non_primary_modifiers empty; no error
  - Given: 9 × Ashfire lv.1
  - Then: `primary_tier == 3`, `non_primary_modifiers.size() == 0`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combination-resolution/primary_resolution_test.gd` — must exist and pass headless

**Status**: [x] Created — 10/10 PASSED, 0 orphans, exit code 0 (2026-06-10)

---

## Dependencies

- Depends on: Story 001 DONE (PranaFragment data model must exist)
- Unlocks: Story 003 (non-primary uses same fragment loop), Story 004 (payload assembly needs primary_type and primary_tier)

---

## Completion Notes
**Completed**: 2026-06-10
**Criteria**: 7/7 passing
**Deviations**: None
**Test Evidence**: Logic — `tests/unit/combination-resolution/primary_resolution_test.gd` — 10/10 PASSED
**Code Review**: Skipped (lean mode)
