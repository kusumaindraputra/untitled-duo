# Sprint 1 — 2026-05-26 to 2026-06-05

> **Stage**: Systems Design (Pre-Production)
> **Generated**: 2026-05-26
> **Review Mode**: lean

## Sprint Goal
Close all outstanding Foundation-layer reviews and design the first two Core-layer systems (Player Controller and Prana Grid), establishing the structural foundation of the Prana/spell spine before Combination Resolution can be authored.

## Capacity
- Total days: 10 (working days, solo dev)
- Buffer (20%): 2 days reserved for unplanned work
- Available: **8 days**

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| S1-01 | Close Audio System design-review (round 2 re-review, fresh session) | audio-director | 0.5 | Audio System GDD round 2 revisions (committed) | `/design-review` returns APPROVED or APPROVED WITH CONDITIONS; systems-index status updated |
| S1-02 | Run `/design-review` on Prana Data GDD (fresh session; resolve uncommitted changes first) | game-designer | 0.5 | prana-data.md working-tree changes | `/design-review` returns APPROVED; uncommitted changes committed; systems-index confirmed |
| S1-03 | Design Player Controller GDD (`/design-system player-controller`) | game-designer | 2.0 | Game State & Scene Flow (Approved) | All 8 required GDD sections complete; gamepad movement model addressed; `/design-review` APPROVED; systems-index updated |
| S1-04 | Design Prana Grid GDD (`/design-system prana-grid`) | game-designer + ux-designer | 3.0 | Prana Data (Approved), Game State & Scene Flow (Approved), S1-03 | All 8 required sections including gamepad Prana-selection UX (flagged as known-hard in tech prefs); `/design-review` APPROVED; systems-index updated |

**Must Have total: 6.0 days**

### Should Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| S1-05 | Design Combination Resolution GDD (`/design-system combination-resolution`) | systems-designer | 2.0 | S1-04 (Prana Grid approved) | All 8 required sections; combination rule set defined (no exponential-state explosion); prototype findings from `prototypes/rune-grid-concept/REPORT.md` integrated; `/design-review` APPROVED |

**Should Have total: 2.0 days**

### Nice to Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| S1-06 | Run `/consistency-check` across all approved GDDs | qa-lead | 0.5 | All Must Have tasks complete | Consistency report produced; any cross-document contradictions resolved or tracked |
| S1-07 | Create `production/milestones/mvp.md` milestone document | producer | 0.5 | — | Milestone doc exists with target date, exit criteria, and MVP scope definition |

**Nice to Have total: 1.0 days**

## Carryover from Previous Sprint
N/A — Sprint 1. The following items from session state carry in:

| Task | Reason | Estimate |
|------|--------|----------|
| Audio System round 2 re-review (S1-01) | Last commit message: "18 blockers resolved, pending re-review" | 0.5d |
| Prana Data design-review (S1-02) | session-state/active.md: "must be fresh — reviewing agent must be independent of authoring context"; prana-data.md has uncommitted working-tree changes | 0.5d |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Prana Grid GDD scope creep (gamepad UX is known-hard per technical-preferences.md) | High | Medium | Time-box gamepad section; pair with `/ux-design` spec; flag as open question if unresolved rather than blocking sprint |
| Combination Resolution design complexity delays S1-05 | High | Low | Prototype verdict (PROCEED) is in context; if S1-04 runs long, defer S1-05 to Sprint 2 — it is Should Have |
| Audio System round 2 re-review reveals new blockers | Low | Medium | If new blockers surface, log in systems-index and continue; do not let re-review block S1-03/S1-04 |
| No milestone document exists | Medium | Medium | Sprint has no milestone anchor; S1-07 (Nice to Have) addresses this |

## Dependencies on External Factors
- Art bible Section 5 (Prana-to-color mapping): verify it is written before S1-04 begins — Prana Grid GDD will reference Prana color specs
- Prototype findings (`prototypes/rune-grid-concept/REPORT.md`): read at S1-05 session start to ground Combination Resolution design

> ⚠️ **No QA Plan**: This sprint was started without a QA plan. Run `/qa-plan sprint`
> before the last story is implemented. The Production → Polish gate requires a QA
> sign-off report, which requires a QA plan.

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed and verified via `/design-review` APPROVED verdicts
- [ ] Audio System and Prana Data GDDs: APPROVED status in systems-index.md
- [ ] Player Controller GDD: exists, all 8 sections, APPROVED
- [ ] Prana Grid GDD: exists, all 8 sections, gamepad interaction model included, APPROVED
- [ ] systems-index.md updated with all new Approved statuses and doc links
- [ ] prana-data.md uncommitted changes committed
- [ ] QA plan exists: `production/qa/qa-plan-sprint-1.md`
- [ ] No unresolved BLOCKING findings in any approved GDD
- [ ] All Logic/Integration stories have passing unit/integration tests (N/A this sprint — design work only)
- [ ] No S1 or S2 bugs in delivered features (N/A this sprint — design work only)
- [ ] Design documents updated for any deviations
