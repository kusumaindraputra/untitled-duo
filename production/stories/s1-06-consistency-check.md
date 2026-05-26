# Story S1-06: Run /consistency-check Across Approved GDDs

**Sprint**: 1
**Priority**: Nice to Have
**Status**: Backlog
**Type**: Config/Data
**Owner**: (unassigned)
**Estimate**: 0.5 days

## Description

Run `/consistency-check` across all approved GDDs to surface cross-document contradictions before implementation sprints begin. This is best run after all Must Have stories are complete so the full Sprint 1 GDD set is available.

## Acceptance Criteria

- [ ] `/consistency-check` completes without error
- [ ] Report produced and written to output path
- [ ] All contradictions categorized: resolved (decision logged) or tracked (owner + GDD reference)
- [ ] No silent contradictions — every discrepancy acknowledged

## QA Test Cases

Verification checklist (from `production/qa/qa-plan-sprint-1-2026-05-26.md`):

- [ ] Signal contracts verified: Game State & Scene Flow emits `death_started` — Audio System depends on this signal (confirmed added in round 3 GDD update)
- [ ] `preparation_started` signal: present in Game State GDD and matches Audio System COMBAT→PREPARATION trigger
- [ ] Bidirectional dependency declarations: Health & Damage lists Audio System as downstream; check all approved GDDs have reciprocal dependency declarations
- [ ] Any contradictions between Prana Data status effect rules and Health & Damage GDD formulas flagged (if Health & Damage is in scope)

## Test Evidence

> Fill in after completing:

- **Consistency report path**: ___
- **Contradictions found**: ___
- **Session date**: ___

## Dependencies

- Best run after: S1-01, S1-02, S1-03, S1-04 complete
- Checks: all GDDs in `design/gdd/` with Approved status in systems-index
