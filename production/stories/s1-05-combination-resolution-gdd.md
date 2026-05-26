# Story S1-05: Design Combination Resolution GDD

**Sprint**: 1
**Priority**: Should Have
**Status**: Blocked (on S1-04)
**Type**: Config/Data + Logic
**Owner**: (unassigned)
**Estimate**: 2.0 days
**GDD**: `design/gdd/combination-resolution.md` (to be created)

## Description

Author the Combination Resolution GDD using `/design-system combination-resolution`. This system reads the Prana Grid's final arrangement and resolves it into a combo output (spell shape, damage modifier, status effect override). The prototype (`prototypes/rune-grid-concept/REPORT.md`, verdict PROCEED) validated the center-slot + position-based approach — read it before starting.

This is a Should Have story. If S1-04 (Prana Grid) runs long and S1-05 cannot be completed within the sprint, defer to Sprint 2.

## Acceptance Criteria

- [ ] GDD file created at `design/gdd/combination-resolution.md`
- [ ] All 8 required sections present
- [ ] Combination detection rule stated: center-slot, adjacency, row/column pattern, or combined rule?
- [ ] Combination space is bounded: lookup table structure defined with stated upper limit
- [ ] Single-type fallback defined: all 9 slots same type → `base_status` from Prana Data as fallback
- [ ] Multiple same-type rule defined (Prana Data Open Question 3: Ashfire in 2+ slots)
- [ ] Deepfrost + Ashfire dominant pairing acknowledged: designed counter or flagged for encounter design
- [ ] Shatter synergy (Deepfrost root → offensive type → +25%) acknowledged explicitly
- [ ] Combination output contract: what does Combination Resolution emit? (combo id, damage modifier, spell shape, status override)
- [ ] Dependencies: Prana Grid (S1-04), Prana Data (Approved)
- [ ] At least one formula test in ACs: given type IDs in positions → resolved combo is X
- [ ] Prototype findings from `prototypes/rune-grid-concept/REPORT.md` cited or integrated
- [ ] `/design-review` returns APPROVED
- [ ] `systems-index.md` Combination Resolution: status → Approved, doc link added

## QA Test Cases

> **Design sprint:** Verification is the `/design-review` verdict.
> Implementation tests will be authored when Combination Resolution is implemented.

Verification checklist (from `production/qa/qa-plan-sprint-1-2026-05-26.md`):

- [ ] Prototype `REPORT.md` findings cited (center-slot + position-based rule)
- [ ] Combination space bounded — upper limit on unique combos stated
- [ ] No exponential state explosion: rule is deterministic, not combinatorially open-ended
- [ ] Prana Data Open Question 3 resolved (multiple same-type in grid)
- [ ] Deepfrost + Ashfire pairing addressed (dominant synergy from Prana Data Known Design Tensions)
- [ ] At least one concrete formula test in ACs (input grid → output combo)
- [ ] `/design-review` APPROVED

## Test Evidence

> Fill in after completing:

- **Verdict**: ___
- **Session date**: ___
- **Commit SHA**: ___

## Dependencies

- **Blocked by**: S1-04 (Prana Grid GDD) — do not start until Prana Grid is APPROVED
- Prana Data GDD: `design/gdd/prana-data.md` (Approved)
- Prototype findings: `prototypes/rune-grid-concept/REPORT.md` — read at session start

## Cross-System Notes

- Output contract here feeds directly into Spell Casting & Effects (System #10 in design order)
- Prana Data Core Rule 7 — Shatter (Deepfrost → offensive type +25%) must be acknowledged; whether Combination Resolution amplifies this or provides diminishing returns is a key design decision
- Prana Data Known Design Tensions flag: if Deepfrost + Ashfire is not addressed here, it must be in Encounter System GDD or Elemental Affiliation GDD — document the handoff explicitly
