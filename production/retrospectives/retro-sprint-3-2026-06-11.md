# Retrospective: Sprint 3

**Period**: 2026-06-04 – 2026-06-11 (early close — all Must Have + Should Have + 1 Nice-to-Have complete)
**Generated**: 2026-06-11
**Sprint Goal**: Implement remaining First Playable systems (StatusEffects, WaveManager, SpellCastingEffects, CombatHUD, RunManager) and run the first internal playtest to validate the fun hypothesis.

---

## Metrics

| Metric | Planned | Actual | Delta |
|--------|---------|--------|-------|
| Must Have tasks | 11 | 11 | 0 |
| Should Have tasks | 4 | 4 | 0 |
| Nice to Have tasks | 2 | 1 | −1 (PranaGrid deferred) |
| Must Have completion rate | — | 100% | — |
| Overall task completion | — | 94% (16/17) | — |
| Effort days (Must Have est.) | 11.0d | ~8 calendar days elapsed | −6d vs window |
| Automated tests at sprint end | — | 539 | +251 vs sprint start |
| New tests added this sprint | — | 251 | — |
| Commits | — | 41 | — |
| Playtest bugs found | — | 8 | — |
| Playtest bugs unresolved | — | 0 | — |
| TODO/FIXME/HACK in src/ | 0 | 0 | 0 |
| Tech debt entries (cumulative) | — | 39 | +19 vs Sprint 2 close |

---

## Velocity Trend

| Sprint | Type | Planned Tasks | Completed | Rate | Tests | Commits |
|--------|------|--------------|-----------|------|-------|---------|
| Sprint 1 | Systems Design (GDD) | N/A | N/A | — | 0 | — |
| Sprint 2 | Implementation | 10 | 6 | 60% | 288 | 16 |
| **Sprint 3** | **Implementation** | **17** | **16** | **94%** | **539** | **41** |

**Trend**: Sharply increasing. Sprint 3 carried nearly twice the task count, delivered at 94% vs Sprint 2's 60%, and added 251 tests in 8 of 14 available days. First Playable goal achieved.

---

## What Went Well

- **Full Must Have + Should Have delivery**: All 11 Must Have and all 4 Should Have tasks completed. Zero carryover from this tier. First Playable milestone achieved.
- **CombinationResolution pulled in from Nice-to-Have**: CR was a 2.0d Nice-to-Have; it was fully implemented with 79 tests (6 stories) after the Must Have tier cleared. Completing it unblocks PranaGrid integration next sprint.
- **539 tests, 0 failures at sprint close**: Added 251 tests this sprint with zero failures and zero orphan warnings. Test discipline held across 5 new epics.
- **First Playable internal playtest achieved**: 11/11 hard criteria passed. 8 bugs found and resolved in the same session. The two-phase loop is functional.
- **ADR-0013 verified SAFE early (day 2)**: PranaGrid path unblocked on day 2 instead of lingering as a risk. This enabled CombinationResolution to be completed with confidence it will have something to resolve against.
- **Retro action items 2, 3, 4 all closed on day 1**: The GdUnit4 teardown rule (S3-12), flaky test fix (S3-14), and is_alive() contract (S3-13, day 7) were all resolved this sprint — zero carryover debt from Sprint 2's process issues.

---

## What Went Poorly

- **`/qa-plan sprint` run on day 7, not day 1**: Sprint 2 Action Item #1 explicitly required QA plan on day 1 before first story. It was run on day 7 (2026-06-10), after most stories were already done. This did not block anything this sprint, but the QA plan was written post-hoc rather than driving implementation. Third time this rule has appeared — needs a process hook, not just a reminder.
- **CombatHUD estimation: 1.0d estimated, ~4 days actual**: Stories 001–003 spanned June 7–10. Story 003 (damage numbers) required two commits (fix commit `ad08b7e` after an initial bad draft `a35976b`). Underestimated visual/interaction complexity of HUD features vs pure Logic stories.
- **Fun hypothesis only PARTIALLY ASSESSABLE**: The playtest confirmed the combat feel works, but the core hypothesis (does the Prana grid decision feel meaningful?) can't be validated without PranaGrid. The external human tester validation was always post-FP in scope, but the partial verdict creates a pending question that Sprint 4 must resolve.
- **Tech debt grew by 19 entries** (20 → 39): SpellCastingEffects alone added 5 entries. The register is being used correctly (active tracking), but the growth rate needs watching — this sprint added more debt entries than Sprint 2 cumulatively.

---

## Blockers Encountered

| Blocker | Duration | Resolution | Prevention |
|---------|----------|------------|------------|
| PranaGrid path uncertainty (ADR-0013) | Day 1–2 | ADR-0013 verified SAFE; path confirmed | Already resolved — documented in ADR |
| CombatHUD Story 003 bad draft | 1 commit cycle | Fix commit `ad08b7e` | Better WIP review before committing; check render output before story-done |
| Fun hypothesis partial only | Whole sprint | Documented as PARTIALLY ASSESSABLE; external tester deferred post-PranaGrid | PranaGrid must ship before hypothesis is fully evaluable |

---

## Estimation Accuracy

| Task | Estimated | Actual | Variance | Likely Cause |
|------|-----------|--------|----------|--------------|
| CombatHUD (S3-09) | 1.0d | ~4d | +3d | Visual/UI stories consistently harder than Logic; story 003 required two passes |
| SpellCastingEffects (S3-08) | 2.0d | ~2d + 2 fix commits | ~on track | Code review iterations not in estimate; on track in substance |
| StatusEffects (S3-05) | 2.0d | ~2d | On track | H&D API was solid; no surprises |
| WaveManager (S3-07) | 2.0d | ~1d | Under | Signal ordering simpler than feared; ADR-0014 contract well-specified |
| CombinationResolution (S3-16) | 2.0d | ~2d | On track | Well-scoped stories; each built cleanly on the previous |

**Overall estimation accuracy**: Strong for Logic stories. UI/Visual stories (CombatHUD) run 3–4× over estimate. Apply a **×3 multiplier to UI/visual story estimates** going forward.

---

## Carryover Analysis

| Task | Priority | Reason | Action |
|------|----------|--------|--------|
| S3-17: PranaGrid | Nice to Have | Depended on CR being done first; time constraint | Sprint 4 Must Have — top priority |
| eai/006: Death Animation Timing | Advisory | BLOCKED on art assets + GDD OQ#3 | Still deferred; re-evaluate when art direction resolves |

---

## Technical Debt Status

- **Tech debt entries**: 39 total (was 20 at Sprint 2 close, +19 this sprint)
- **src/ TODO/FIXME/HACK**: 0 (clean)
- **Trend**: Growing — 19 new entries this sprint vs 20 cumulative before. SpellCastingEffects was the largest contributor (5 entries). Growth is largely acceptable (tracked deviations, not unplanned shortcuts), but the rate warrants a debt-reduction story in Sprint 4.
- **Action required**: Schedule one `/tech-debt` review pass in Sprint 4 to close or accept the oldest entries.

---

## Previous Action Items Follow-Up

| Action Item (from Sprint 2) | Status | Notes |
|-----------------------------|--------|-------|
| Run `/qa-plan sprint` before first story | PARTIAL | Run day 7 instead of day 1; did happen but didn't drive implementation |
| Fix flaky headless test (S3-14) | DONE | Day 1; closed in first commit batch |
| Resolve `is_alive()` contract (S3-13) | DONE | Day 7; 3 contract tests added; 36/36 enemy-instance tests passing |
| Add GdUnit4 teardown rule to test-standards.md (S3-12) | DONE | Day 1 |
| Resolve GDD OQ#3 enemy animation | NOT STARTED | Still low priority; art pipeline not started |

---

## Action Items for Next Iteration

| # | Action | Priority | Deadline |
|---|--------|----------|----------|
| 1 | **Run `/qa-plan sprint` on Sprint 4 day 1** — before any story work begins. Third time this item appears; treat as a sprint entry gate, not a reminder. | High | Sprint 4 day 1 |
| 2 | **Implement PranaGrid** (S3-17 → Sprint 4 Must Have) — ADR-0013 verified SAFE, CR complete; grid is the missing piece for the full fun hypothesis test. | High | Sprint 4 |
| 3 | **Schedule external human playtest** after PranaGrid ships — fun hypothesis requires a non-developer tester; developer self-test is not sufficient evidence. | High | Post-PranaGrid |
| 4 | **Apply ×3 multiplier to UI/visual story estimates** — CombatHUD ran 4× over. Revise sprint capacity math for any UI story going forward. | Medium | Sprint 4 planning |
| 5 | **Tech debt review pass** — 39 entries, +19 this sprint. Schedule one `/tech-debt` review in Sprint 4 to close or formally accept the oldest open entries. | Low | Sprint 4 |

---

## Process Improvements

- **Make `/qa-plan sprint` a hard sprint gate**: The plan should exist before story-001 of any epic is started. Consider adding a checklist item to the sprint plan template so it can't be missed again.
- **Tag UI stories with a ×3 estimate multiplier by default**: Every UI/visual story this sprint ran longer than estimated. Logic stories are well-calibrated; UI stories need a systematic adjustment at planning time, not post-hoc.

---

## Summary

Sprint 3 delivered all 11 Must Have and all 4 Should Have stories, pulled in CombinationResolution from Nice-to-Have, ran the first internal playtest (11/11 hard criteria), and closed 8 bugs same session — all in 8 of 14 available days. The sprint goal is fully met. The one unresolved item is the fun hypothesis: it is structurally sound but requires PranaGrid to be testable with a real user. Sprint 4 has one clear priority: ship PranaGrid and run an external playtest to get the definitive verdict before committing further Feature-layer scope.
