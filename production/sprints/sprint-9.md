# Sprint 9 — 2026-07-29 to 2026-08-11

> **Stage**: Production — Close carryovers + production tracking backfill
> **Generated**: 2026-06-17
> **Review Mode**: lean

## Sprint Goal

Close three long-running human-gated carryovers, confirm Sprint 8 game feel in Godot, and backfill production tracking so the system reflects what is actually built — enabling accurate next-phase planning.

## Background

Sprint 9 planning audit (2026-06-17) revealed that **all epics in the epics index are implemented** — test files exist for every system. However, ~30+ story files were never stamped with test evidence, epic EPIC.md files still show "Status: Ready", and the epic index is stale. The production tracking state does not reflect the implementation state. This sprint corrects that.

## Capacity

- Total days: 14
- Buffer (20%): 3 days reserved
- Available: **11 days**

## Tasks

### Must Have (Critical Path)

| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|--------------|---------------------|
| S9-01 | **Manual validation in Godot — Sprint 8 DoD gate** (task 0 — no new stories begin until this passes) | 0.5 | Godot open | Dash blink visual confirmed; arena walls contain player; enemy colors differentiated; Rifter fires + projectile despawns on hit/range |
| S9-02 | **ADR-0013 live gamepad gate** (3rd carry — HARD DEADLINE) | 0.5 | Physical gamepad | 6 mandatory checks in `production/qa/evidence/prana-grid-gamepad-adr0013.md` filled; verdict PASS or FAIL documented; if no gamepad → binary decision: acquire OR close ADR-0013 as "theoretical only" |
| S9-03 | **Re-validation playtest** (3rd carry — HARD DEADLINE) | 1.0 | Non-developer tester | Playtest session documented in `production/playtests/`; legibility verdict CONFIRMED or STILL PARTIAL; if no tester → formal descope note in playtest register |
| S9-04 | **Story file backfill pass** — stamp all implemented-but-unstamped story files as Complete | 1.5 | None | All story files with existing test evidence have `Status: Complete` and `Test Evidence: [x]` filled in; covers ~30 story files across HealthDamage, PlayerController, EnemyInstance, CombatHUD, CombinationResolution-005, GameStateSceneFlow-002/003, PranaGrid-001/005, WaveManager-003 |
| S9-05 | **Epic index + EPIC.md backfill** — update epic status fields and `production/epics/index.md` | 0.5 | S9-04 | All fully-implemented epics show `Status: Complete` in their EPIC.md and in the index; index `Last Updated` refreshed |

**Must Have total: ~4.0 days**

### Should Have

| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|--------------|---------------------|
| S9-06 | **Milestone review** — assess current state against First Playable exit criteria now that tracking is accurate | 0.5 | S9-04, S9-05 | `production/milestones/first-playable.md` exit criteria reviewed; each hard criterion marked PASS/FAIL based on implemented code; verdict documented |
| S9-07 | **Next-phase epic creation** — run `/create-epics layer:feature` for any remaining non-trivial features (Audio SFX wiring, result screen, run management UI, wave variety) | 2.0 | S9-06 | At least one new epic created for the next implementation phase; stories created and ready |

**Should Have total: 2.5 days (Must Have + Should Have = 6.5d — well within 11d capacity)**

### Nice to Have

| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|--------------|---------------------|
| S9-08 | **QA plan for next implementation sprint** — once S9-07 creates new stories, generate `/qa-plan` for those | 0.5 | S9-07 | `production/qa/qa-plan-sprint-9-*.md` or sprint-10 plan exists |

---

## Carryover from Sprint 8

| Task | Times Carried | Reason | Sprint 9 Priority |
|------|---------------|--------|-------------------|
| ADR-0013 live gamepad gate (S7-02 → S8-06) | **3** | No physical gamepad in any session | **Must Have — hard deadline. No 4th carry.** |
| Re-validation playtest (S6-07 → S7-10 → S8-07) | **3** | Non-developer tester not available | **Must Have — hard deadline. No 4th carry.** |

---

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Gamepad still unavailable | High | Low | Binary decision required: acquire OR formally close gate |
| Story backfill reveals a genuinely unimplemented story | Low | Medium | Treat as new Must Have story; add to this sprint before closing |
| Milestone review reveals unmet hard exit criteria | Medium | High | Surface as blocker for next phase planning; do not advance to next milestone |

---

## Dependencies on External Factors

- S9-01 requires Godot editor open
- S9-02 requires a physical gamepad
- S9-03 requires a non-developer tester

---

## Definition of Done for Sprint 9

- [ ] S9-01: Manual validation complete — all S8 visual features confirmed in Godot
- [ ] S9-02: ADR-0013 gate filled OR formally closed — no more "evidence file blank"
- [ ] S9-03: Playtest documented OR formally descoped — no 4th carry
- [ ] S9-04: All implemented story files stamped as Complete with test evidence filled
- [ ] S9-05: Epic index and EPIC.md files reflect actual implementation state
- [ ] `sprint-status.yaml` up to date after every story close

---

> ⚠️ **QA Plan**: S9-01/02/03 are validation tasks — no QA plan needed for them. S9-04/05/06 are tracking/docs tasks. QA plan required only if S9-07 creates new implementation stories.
