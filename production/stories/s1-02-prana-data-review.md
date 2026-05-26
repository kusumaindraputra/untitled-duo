# Story S1-02: Prana Data Design-Review (Fresh Session)

**Sprint**: 1
**Priority**: Must Have
**Status**: Ready
**Type**: Config/Data
**Owner**: (unassigned)
**Estimate**: 0.5 days
**GDD**: `design/gdd/prana-data.md`

## Description

Run `/design-review design/gdd/prana-data.md` in a **fresh Claude Code session**. The GDD has uncommitted working-tree changes — commit those first. The session state (`production/session-state/active.md`) notes the review must be independent of the authoring context.

## Acceptance Criteria

- [ ] `design/gdd/prana-data.md` uncommitted working-tree changes committed before opening review session
- [ ] `.claude/agent-memory/qa-lead/project_prana-data-ac-review.md` uncommitted changes committed
- [ ] `/design-review` verdict is APPROVED (no BLOCKING findings)
- [ ] `systems-index.md` Prana Data status confirmed as `Approved`
- [ ] Session committed to git with `docs:` prefix

## Instructions

1. Commit any working-tree changes to `prana-data.md` and agent memory
2. Open a **fresh** Claude Code session
3. Run: `/design-review design/gdd/prana-data.md`
4. Address any BLOCKING findings before marking DONE

## QA Test Cases

> **Design sprint:** Verification is the `/design-review` verdict itself.
> Future implementation tests seeded by this GDD: 46 active ACs in `tests/unit/prana-data/` and `tests/integration/prana-data/`.

Verification checklist (from `production/qa/qa-plan-sprint-1-2026-05-26.md`):

- [ ] Stun duration 0.8s minimum confirmed (perceptibility constraint, not tuning preference)
- [ ] `DamageSource` enum (`DIRECT`, `DOT`, `CONTACT`) defined in `src/data/game_enums.gd`
- [ ] `duplicate_deep()` used (not deprecated `duplicate(true)`) in Implementation Notes
- [ ] `@export var` used (not invalid `@export const`) for tuning knob properties
- [ ] Autoload initialization guard (`_initialized` flag + `assert()` in `get_type()`) present
- [ ] Injury Bloom i-frame exclusion rule in Edge Cases
- [ ] Burn Contagion chain depth rule (Contagion-inert on transferred Burn) in Edge Cases
- [ ] Lightning Follow-Through window replacement (reset, not stack) in Edge Cases
- [ ] Discovery Signal Contract table present (visual requirements per conditional behavior)
- [ ] Burn cap `assert` call specified for Status Effects implementation
- [ ] AC-PD-42 blocked on Enemy AI GDD — removed from Prana Data BLOCKING gate
- [ ] AC-PD-18 Advisory with corrected 95% CI (469–531 misses per 1,000 trials)

Key implementation sprint test notes:
- **AC-PD-04b**: `duplicate_deep()` mutation isolation — test BOTH scalar and reference property isolation
- **AC-PD-10 / AC-PD-17**: Timer-driven tick behavior requires running SceneTree (integration test, not unit)
- **AC-PD-28**: Stun pauses Freeze; assert ±0.05s tolerance, NOT exact float equality
- **AC-PD-44 / 44b / 44c**: Injury Bloom i-frame exclusion — edge case most likely to be missed

## Test Evidence

> Fill in after completing the review:

- **Verdict**: ___
- **Session date**: ___
- **New blockers found**: ___
- **Commit SHA**: ___

## Dependencies

- `design/gdd/prana-data.md` (uncommitted changes must be committed first)
