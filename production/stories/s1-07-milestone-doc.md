# Story S1-07: Create production/milestones/mvp.md

**Sprint**: 1
**Priority**: Nice to Have
**Status**: Backlog
**Type**: Config/Data
**Owner**: (unassigned)
**Estimate**: 0.5 days

## Description

Create the project milestone document for the MVP milestone. No milestones directory or document currently exists. This gives the sprint plan a milestone anchor and defines exit criteria for the MVP gate check.

## Acceptance Criteria

- [ ] `production/milestones/` directory created
- [ ] File exists at `production/milestones/mvp.md`
- [ ] Target date defined (absolute date, derived from game-concept.md scope: 3–5 weeks from project start 2026-05-20)
- [ ] Exit criteria defined: what does "MVP done" mean?
- [ ] MVP scope boundary defined: matches game-concept.md (1 layer, 5 Prana types, 3 enemy types, 1 boss, Memo, 3–5 memory fragments, plot twist)
- [ ] "Explicitly NOT in scope" list present (matches game-concept.md)
- [ ] Committed to git with `docs:` prefix

## QA Test Cases

Verification checklist (from `production/qa/qa-plan-sprint-1-2026-05-26.md`):

- [ ] File exists at `production/milestones/mvp.md`
- [ ] Target date is an absolute date (e.g., 2026-06-20, not "3–5 weeks")
- [ ] Exit criteria include: all 21 MVP-tier GDDs approved + implementation complete + smoke check PASS + QA sign-off
- [ ] Scope matches game-concept.md Scope Tiers table exactly
- [ ] Not-in-scope list matches game-concept.md "Explicitly NOT in MVP" section

## Test Evidence

> Fill in after completing:

- **File path**: `production/milestones/mvp.md`
- **Target date set**: ___
- **Commit SHA**: ___

## Dependencies

- No upstream dependencies — can be done in any order
- Source: `design/gdd/game-concept.md` Scope Tiers and MVP Definition sections
