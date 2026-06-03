# Retrospective: Sprint 2

**Period**: 2026-06-01 – 2026-06-03 (early close — all Must Have complete)
**Generated**: 2026-06-03
**Sprint Goal**: Implement Health & Damage pipeline, Player Controller, and Enemy Instance — the three Core systems needed for a playable combat encounter.

---

## Metrics

| Metric | Planned | Actual | Delta |
|--------|---------|--------|-------|
| Must Have tasks | 6 | 6 | 0 |
| Should Have tasks | 2 | 0 | −2 (deferred to Sprint 3) |
| Nice to Have tasks | 2 | 0 | −2 (deferred) |
| Must Have completion rate | — | 100% | — |
| Overall task completion | — | 60% (6/10) | — |
| Effort days (Must Have) | 10.0d | ~3d elapsed | −7d vs window |
| Commits (sprint period) | — | 16 | — |
| CI fix commits | — | 3 | — |
| Automated test assertion failures | — | 0 | — |
| Tests run | — | 288 | — |
| Tech debt entries (cumulative) | — | 20 | — |
| TODO/FIXME/HACK in src/ | — | 0 | — |

---

## Velocity Trend

| Sprint | Type | Must Have Planned | Must Have Completed | Rate |
|--------|------|-------------------|---------------------|------|
| Sprint 1 | Systems Design (GDD authoring) | N/A | N/A | — |
| **Sprint 2** | **Implementation** | **6 tasks / 10.0d** | **6 tasks** | **100%** |

**Trend**: Baseline established. First implementation sprint — no prior velocity to compare against. Strong first data point.

---

## What Went Well

- **100% Must Have delivery**: All three Core systems (HealthAndDamage, PlayerController, EnemyInstance) completed well inside the 14-day sprint window. Sprint goal achieved.
- **Zero assertion failures across 288 tests**: Every Logic and Integration story has automated test coverage. Test-first approach (writing tests alongside implementation) caught the `queue_free`/`free()` orphan node pattern before it reached CI.
- **ADR-driven development**: ADR-0003 (signals), ADR-0004 (float accumulators), ADR-0007 (H&D pipeline) gave unambiguous implementation guidance. No architecture debates mid-sprint.
- **Zero hardcoded values in src/**: All gameplay constants externalized. 0 TODO/FIXME/HACK in production code.
- **Integration test design (Story 005)**: HP-delta tracking workaround for GdUnit4 Autoload freeing is documented in the test file header — a reusable pattern for future multi-system integration tests.

---

## What Went Poorly

- **CI pipeline needed 3 iterations** (commits `c264db4`, `e55eb84`, `d9229e0`) before stabilizing on `version='installed'` + full semver Godot pin. Cost: multiple push-wait-fail cycles early in the sprint.
- **sprint-status.yaml went stale**: S2-01, S2-02, S2-03, S2-05, S2-06 all showed wrong statuses at retrospective time. `/story-done` updates story files but doesn't reliably propagate to the YAML for pre-done tasks.
- **No Sprint 2 QA plan**: `/qa-plan sprint` was flagged as needed in the sprint plan but never run. Manual smoke checks were not performed this session. Smoke check report shows NOT CHECKED for all interactive tests.
- **Test naming convention violations**: Story 005's 4 integration test names don't follow `test_[system]_[scenario]_[expected_result]`. Logged to tech debt but should have been caught at code review.
- **Story 006 art dependency not surfaced early**: The Death Animation Timing story was always going to be BLOCKED on art assets and GDD Open Question #3. Should have been flagged as `BLOCKED-ART` at sprint planning, not discovered at implementation time.

---

## Blockers Encountered

| Blocker | Duration | Resolution | Prevention |
|---------|----------|------------|------------|
| CI: GdUnit4 action version conflict | ~1 session | `version='installed'` + full semver pin in `.github/workflows/tests.yml` | Document CI setup in project memory (done) |
| GdUnit4 orphan node pattern (queue_free vs free()) | ~2 commits | `free()` in `after_test()` teardown for manually added nodes | Add explicit rule to `test-standards.md` |
| Story 006 blocked on art assets | Whole sprint | Deferred to art pipeline | Flag art-dependency stories as `BLOCKED-ART` at story creation |

---

## Estimation Accuracy

| Task | Estimated | Status | Notes |
|------|-----------|--------|-------|
| H&D (5 stories) | 3.0d | Complete | On track — most complex system; estimates held |
| PlayerController (4 stories) | 2.5d | Complete | Slightly under — footstep shuffle-bag simpler than feared |
| EnemyInstance (5 blocking stories) | 3.0d | Complete | On track — integration test design added unexpected complexity |
| Story creation (3 × 0.5d) | 1.5d | Complete | Accurate |

**Overall estimation accuracy**: Strong for Must Have scope. Should Have and Nice to Have were never attempted — no variance data. Recommend re-evaluating Status Effects estimate with actual H&D knowledge before Sprint 3.

---

## Carryover Analysis

| Task | Priority | Reason | Action |
|------|----------|--------|--------|
| S2-07: Create Status Effects stories | Should Have | Sprint capacity exhausted after Must Have | Sprint 3 Must Have |
| S2-08: Implement Status Effects | Should Have | Depends on S2-07; capacity | Sprint 3 Must Have — H&D gate cleared |
| S2-09: Create Combo Resolution stories | Nice to Have | Never scheduled | Sprint 3 Should Have |
| S2-10: Implement Combo Resolution | Nice to Have | Depends on S2-09 | Sprint 3 Should Have |
| eai/006: Death Animation Timing | Advisory | BLOCKED on art assets + GDD OQ #3 | Schedule after art direction resolved |

---

## Technical Debt Status

- **Tech debt entries**: 20 total (cumulative since project start)
- **src/ TODO/FIXME/HACK**: 0 (clean)
- **Sprint 2 additions**: 5 entries (flaky headless test, is_alive contract, TR numbering, test naming, eai/006 evidence)
- **Trend**: Growing by design — register is being actively used to track known-acceptable deviations. Zero TODOs in production code is the stronger quality signal.

**Items requiring action before StatusEffectsManager epic**:
- `is_alive()` contract ambiguity (`!= DEAD` vs `== CHASING`) — must resolve before SEM stories begin
- `enemy_instance_skeleton_test` headless flake — fix `set_physics_process(false)` guard

---

## Previous Action Items Follow-Up

No prior sprint retrospectives. Sprint 1 was Systems Design — no implementation action items to follow up on.

---

## Action Items for Next Iteration

| # | Action | Priority | Deadline |
|---|--------|----------|----------|
| 1 | Run `/qa-plan sprint` at Sprint 3 start before first story | High | Sprint 3 day 1 |
| 2 | Fix flaky headless test: add `set_physics_process(false)` after `add_child()` in `enemy_instance_skeleton_test._make_enemy()` | High | Sprint 3 start |
| 3 | Resolve `is_alive()` contract (`!= DEAD` vs `== CHASING`) in `enemy_instance.gd` and story spec before SEM stories | High | Before first SEM story |
| 4 | Add "GdUnit4 teardown: use `free()` not `queue_free()` for manually added nodes" to `test-standards.md` | Medium | Sprint 3 start |
| 5 | Resolve GDD Open Question #3 (enemy animation art direction) to unblock Story 006 | Low | When art pipeline begins |

---

## Process Improvements

- **Run `/qa-plan sprint` before the first implementation story** each sprint. A QA plan written during sprint planning produces better test cases than one written during close-out.
- **Flag art/asset dependencies at story creation time**: stories requiring art deliverables should be tagged `BLOCKED-ART` with the specific GDD open question as the blocker reference, so they don't appear as "Ready" in the sprint board when they aren't.

---

## Summary

Sprint 2 delivered its full Must Have commitment — HealthAndDamage, PlayerController, and EnemyInstance are all implemented, tested (288 tests, 0 assertion failures), and closed. The sprint ran fast: all blocking work completed in approximately 3 calendar days of a 14-day window. The main process gaps were CI setup friction (3 fix commits to stabilize), a missing QA plan, and the sprint-status.yaml going stale mid-sprint. Status Effects is the logical Sprint 3 Must Have, now that H&D is the gate for it and the API contract (ADR-0011) is fully implemented on both EnemyInstance and PlayerController sides.
