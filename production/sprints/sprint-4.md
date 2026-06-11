# Sprint 4 — 2026-06-12 to 2026-06-25

> **Stage**: Production (First Playable → Fun Hypothesis Validation)
> **Generated**: 2026-06-11
> **Review Mode**: lean

## Sprint Goal

Ship PranaGrid and validate the fun hypothesis with an external human tester — completing the First Playable milestone and establishing the verdict that gates all further Feature-layer scope.

## Capacity

- Total days: 14
- Buffer (20%): 3 days reserved (ADR-0013 HIGH engine risk absorbed here)
- Available: **11 days**

## Tasks

### Must Have (Critical Path)

| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|--------------|---------------------|
| S4-01 | Run `/qa-plan sprint` — Sprint 4 QA plan **(DAY 1 GATE — before any story work)** | 0.5 | None | `production/qa/qa-plan-sprint-4-*.md` exists before first story begins |
| S4-02 | Create PranaGrid stories (`/create-stories prana-grid`) | 0.5 | S4-01 | Story files in `production/epics/prana-grid/`; each passes `/story-readiness` |
| S4-03 | Implement PranaGrid — skeleton + phase gating (ARRANGEMENT / LOCKED / HIDDEN) | 0.75 | S4-02 | State transitions on `preparation_started` / `grid_locked` / `grid_hidden`; slots array resets on ARRANGEMENT entry; tests pass headless |
| S4-04 | Implement PranaGrid — mouse drag-and-drop input + confirm validation | 2.5 | S4-03 | Drag token from selector → slot; slot-to-slot swap; right-click clear; centre-slot confirm guard; Confirm button greyed when slot 4 empty; `arrangement_confirmed` emits; ADR-0013 mouse path validated manually |
| S4-05 | Implement PranaGrid — `committed_fragments` → CR + SCE integration | 0.75 | S4-04 | `committed_fragments` getter wired; CombinationResolution reads arrangement on `combat_started`; full prep→confirm→cast loop runs end-to-end; integration test passes |
| S4-06 | External human playtest — fun hypothesis final verdict | 1.0 | S4-05 | ≥1 session with a non-developer tester documented in `production/playtests/`; fun hypothesis verdict: CONFIRMED / PARTIALLY / NOT CONFIRMED recorded |

**Must Have total: 6.0 days** *(S4-04 uses ×2.5 adjusted estimate — UI story with HIGH engine risk; 3-day buffer absorbs overrun)*

### Should Have

| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|--------------|---------------------|
| S4-07 | Implement PranaGrid — gamepad input (ADR-0013 HIGH risk path) | 2.5 | S4-04 | D-pad slot navigation; type-cycle control; Place + Clear actions; Confirm via gamepad; ADR-0013 gamepad path manually validated independently from mouse path |
| S4-08 | Tech debt review pass — close or formally accept 39 open entries | 0.5 | None | Run `/tech-debt`; each entry marked RESOLVED, ACCEPTED, or SCHEDULED; register count reduced or entries dated |

**Should Have total: 3.0 days**

### Nice to Have

| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|--------------|---------------------|
| S4-09 | Isometric visual pass — player/enemy placeholder art + lighting tweak | 2.0 | None | Player and enemies visually distinguishable from floor; improves external playtest quality |

**Nice to Have total: 2.0 days — begin only if Must Have + Should Have complete and buffer not consumed**

## Carryover from Sprint 3

| Task | Original Sprint | Reason | Sprint 4 Priority |
|------|----------------|--------|-------------------|
| S3-17: Implement PranaGrid | Sprint 3 Nice to Have | CR completion required first; time constraint | Must Have (S4-02–05) |
| eai/006: Death Animation Timing | Sprint 2 Advisory | BLOCKED on art assets + GDD OQ#3 | Still deferred — backlog |
| CH-004 evidence fill-in | Sprint 3 Advisory | Deferred to external playtest session | Resolve during S4-06 playtest |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| ADR-0013 dual-input focus fails in Godot 4.6 | Medium | High | 3-day buffer reserved; gamepad is Should Have (fallback: KB/M only for external playtest) |
| Fun hypothesis NOT CONFIRMED | Low–Medium | Very High | If not confirmed: halt Feature layer; redesign Prana loop before any new epics |
| Mouse drag-and-drop underestimated | Medium | Medium | ×2.5 estimate applied; buffer available; gamepad is Should Have (can defer) |
| External tester unavailable before sprint end | Low | Medium | Line up tester early (day 1); S4-06 is blocking for fun hypothesis verdict |

## Dependencies on External Factors

- External human tester must be available — schedule before sprint start (before S4-05 completes)
- Art assets for isometric visual pass (S4-09) — only attempt if assets exist

## Definition of Done for Sprint 4

- [ ] All Must Have stories implemented, code-reviewed, and closed via `/story-done`
- [ ] QA plan exists (`production/qa/qa-plan-sprint-4-*.md`) — **S4-01 gates all implementation**
- [ ] All Logic/Integration stories have passing headless tests
- [ ] ADR-0013 mouse path manually validated (PranaGrid S4-04 gate)
- [ ] Fun hypothesis verdict recorded (CONFIRMED / PARTIALLY / NOT CONFIRMED) in playtest doc
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] No critical/blocker bugs in delivered features
- [ ] Design documents updated for any deviations

> ⚠️ **QA Plan Required First**: Run `/qa-plan sprint` (S4-01) before starting any implementation story. This is Must Have — not optional.
