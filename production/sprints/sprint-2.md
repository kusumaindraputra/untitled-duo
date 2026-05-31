# Sprint 2 — 2026-06-01 to 2026-06-14

> **Stage**: Production (First Playable)
> **Generated**: 2026-05-31
> **Review Mode**: lean

## Sprint Goal

Implement the Health & Damage pipeline, Player Controller, and Enemy Instance — the three Core systems needed for a playable (if scripted) combat encounter, and the gate for all subsequent Core systems.

## Capacity

- Total days: 14 (working days, solo dev)
- Buffer (20%): 3 days reserved for unplanned work + engine risk validation
- Available: **11 days**

## Pre-Sprint Requirements (before day 1 of implementation)

- [ ] Run `/create-stories health-damage` → populates `production/epics/health-damage/story-*.md`
- [ ] Run `/create-stories player-controller` → populates `production/epics/player-controller/story-*.md`
- [ ] Run `/create-stories enemy-instance` → populates `production/epics/enemy-instance/story-*.md`
- [ ] Run `/story-readiness [each story]` for all Must Have stories before picking up

## Tasks

### Must Have (Critical Path — H&D gates everything else)

| ID | Task | Epic | Est. Days | Dependencies | Acceptance Criteria |
|----|------|------|-----------|--------------|---------------------|
| S2-01 | Create stories: Health & Damage | production/epics/health-damage/EPIC.md | 0.5 | None | Story files exist; each story passes `/story-readiness` |
| S2-02 | Implement Health & Damage | production/epics/health-damage/story-*.md | 3.0 | S2-01 | All AC-HD unit tests pass headless; `apply_damage()` / `apply_heal()` / all 4 zone signals verified |
| S2-03 | Create stories: Player Controller | production/epics/player-controller/EPIC.md | 0.5 | None | Story files exist; each passes `/story-readiness` |
| S2-04 | Implement Player Controller | production/epics/player-controller/story-*.md | 2.5 | S2-02 (is_invincible API), S2-03 | All AC-PC tests pass; float accumulator dash/iframe/footstep verified; `"player"` group confirmed |
| S2-05 | Create stories: Enemy Instance | production/epics/enemy-instance/EPIC.md | 0.5 | None | Story files exist; each passes `/story-readiness` |
| S2-06 | Implement Enemy Instance | production/epics/enemy-instance/story-*.md | 3.0 | S2-02 (apply_damage), S2-04 (player group lookup), S2-05 | All AC-EAI tests pass; CHASING→DEAD + contact timer + queue_free() lifecycle verified |

**Must Have total: 10.0 days**

### Should Have

| ID | Task | Epic | Est. Days | Dependencies | Acceptance Criteria |
|----|------|------|-----------|--------------|---------------------|
| S2-07 | Create stories: Status Effects | production/epics/status-effects/EPIC.md | 0.5 | None | Story files exist |
| S2-08 | Implement Status Effects | production/epics/status-effects/story-*.md | 2.0 | S2-02 (apply_damage/heal for DoT/Regen), S2-07 | AC-SE unit tests pass; `apply_status()` 4-arg signature, `has_status()` verified; `preparation_started` clears all instances |

**Should Have total: 2.5 days**

> Note: If Must Have runs past day 9, defer Status Effects to Sprint 3. Must Have is the firm commitment.

### Nice to Have

| ID | Task | Epic | Est. Days | Dependencies | Acceptance Criteria |
|----|------|------|-----------|--------------|---------------------|
| S2-09 | Create stories: Combination Resolution | production/epics/combination-resolution/EPIC.md | 0.5 | None | Story files exist |
| S2-10 | Implement Combination Resolution | production/epics/combination-resolution/story-*.md | 2.0 | S2-02, S2-09 | AC-CR unit tests pass; data-driven effect tables load from Resources |

**Nice to Have total: 2.5 days — only begin if Must Have completes by day 9**

## Carryover from Sprint 1

N/A — Sprint 1 was a Systems Design (GDD authoring) sprint. No implementation carryover.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| H&D takes longer than 3 days (most integration surface of any Core system) | Medium | High — gates all other stories | Schedule H&D first; if >2 days in, defer Should Have |
| PranaGrid dual-input HIGH engine risk surfaces during integration | Low (FP scope avoids gamepad grid path) | Medium | PranaGrid epic intentionally excluded from Sprint 2 — validate ADR-0013 before scheduling |
| `/create-stories` sessions consume context budget | Medium | Low | Run one epic per session; each story creation is ~1h |
| No milestone doc means "done" is undefined | High | Medium | Write `production/milestones/first-playable.md` during Sprint 2 — defining FP exit criteria is a sprint output |

## Dependencies on External Factors

- `production/epics/*/story-*.md` files must be created via `/create-stories` before implementation begins (pre-sprint requirement)
- Feature layer (WaveManager) epic not yet created — run `/create-epics layer:feature` before Sprint 3 to unblock enemy spawning integration
- `production/milestones/first-playable.md` does not yet exist — author during Sprint 2

## Definition of Done for Sprint 2

- [ ] All Must Have stories implemented, code-reviewed, and closed via `/story-done`
- [ ] All Logic/Integration stories have passing unit/integration tests (headless GdUnit4)
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] `production/milestones/first-playable.md` authored (defines FP exit criteria)

> ⚠️ **No QA Plan**: This sprint was started without a QA plan. Run `/qa-plan sprint`
> before the last story is implemented. The Production → Polish gate requires a QA
> sign-off report, which requires a QA plan.
