# Sprint 3 — 2026-06-04 to 2026-06-17

> **Stage**: Production (First Playable)
> **Generated**: 2026-06-03
> **Review Mode**: lean

## Sprint Goal

Implement the remaining First Playable systems (WaveManager, SpellCastingEffects, CombatHUD minimal, RunManager minimal, StatusEffects) and run the first internal playtest to validate the fun hypothesis.

## Capacity

- Total days: 14 (working days, solo dev)
- Buffer (20%): 3 days reserved for unplanned work + engine risk
- Available: **11 days**

## Pre-Sprint Requirements (before S3-04)

- [ ] S3-03: Run `/qa-plan sprint` → generates `production/qa/qa-plan-sprint-3-*.md`
- [ ] S3-01: Architecture housekeeping — fix `architecture.md` L110, regenerate control-manifest, mark ADR-0001 verified
- [ ] S3-02: Verify ADR-0013 engine risk → determines if PranaGrid is FP-path or keyboard-shortcut-fallback path

## Tasks

### Must Have (Critical Path to First Playable)

| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|--------------|---------------------|
| S3-01 | Architecture housekeeping: fix `architecture.md` L110 (4-arg apply_status + has_status); regenerate control-manifest; mark ADR-0001 verified | 0.5 | None | L110 shows ADR-0011 API; manifest includes ADR-0014; ADR-0001 verification flag cleared |
| S3-02 | ADR-0013 engine verification — PranaGrid dual-input focus model | 0.5 | None | Verification Required flag resolved; result documented in ADR-0013; PranaGrid path or keyboard fallback confirmed |
| S3-03 | Run `/qa-plan sprint` — generate Sprint 3 QA plan | 0.5 | S3-01 (must run before first story) | `production/qa/qa-plan-sprint-3-*.md` exists with test cases per story |
| S3-04 | Create stories: StatusEffects | 0.5 | S3-01, S3-03 | Story files exist in `production/epics/status-effects/`; each passes `/story-readiness` |
| S3-05 | Implement StatusEffects (Freeze + Burn, Stun stub) | 2.0 | S3-04; S2-02 (H&D apply_damage complete) | `apply_status()` 4-arg, `has_status()`, `check_and_apply_shatter()` pass headless; `preparation_started` clears all instances |
| S3-06 | Create stories: WaveManager (1 hardcoded wave, 10 enemies, win condition) | 0.5 | S3-03 | Story files exist; pass `/story-readiness` |
| S3-07 | Implement WaveManager | 2.0 | S3-06; S2-06 (EnemyInstance complete) | 10 enemies spawn on `combat_started`; `enemy_killed` decrements counter; `all_waves_cleared` fires at 0; unit/integration tests pass |
| S3-08 | Create + Implement minimal SpellCastingEffects | 2.0 | S3-05; S2-02 (H&D) | Player input triggers `apply_damage`; elemental 2× affiliation bonus applies; `cast_hit_started` fires; tests pass |
| S3-09 | Create + Implement minimal CombatHUD | 1.0 | S2-02 (H&D signals); S3-07 | HP bar updates on `damage_taken`/`health_restored`; wave-cleared message on `wave_ended`; no crash |
| S3-10 | Create + Implement minimal RunManager | 0.5 | S3-07; S2-02 (player_died) | `run_ended(win)` shows result screen; no softlock; complete run (start → result screen) works |
| S3-11 | First Playable internal playtest — validate fun hypothesis | 1.0 | S3-05–S3-10 all done | ≥1 session in `production/playtests/`; all Hard criteria from `first-playable.md` checked; fun hypothesis confirmed or falsified |

**Must Have total: 11.0 days**

### Should Have

| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|--------------|---------------------|
| S3-12 | Retro fix: add `free()` vs `queue_free()` teardown rule to `test-standards.md` | 0.25 | None | Rule + example documented |
| S3-13 | Retro fix: resolve `is_alive()` contract — align `enemy_instance.gd` and ADR-0011 spec | 0.25 | None | One form used consistently; ADR-0011 comment updated |
| S3-14 | Retro fix: fix flaky headless test in `enemy_instance_skeleton_test` | 0.25 | None | `test_enemy_instance_combat_started_sets_combat_active_true` passes cleanly headless |
| S3-15 | Create stories: CombinationResolution | 0.5 | S3-02 (ADR-0013 result) | Story files exist; pass `/story-readiness` |

**Should Have total: 1.25 days**

### Nice to Have

| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|--------------|---------------------|
| S3-16 | Implement CombinationResolution | 2.0 | S3-15, S3-08 | Combo table data-driven; `combo_resolved` emits correct SpellEffect |
| S3-17 | Implement PranaGrid (only if ADR-0013 returns SAFE) | 2.5 | S3-02 (SAFE verdict); ADR-0013 Accepted | Tokens placeable in 3×3 grid; `arrangement_confirmed` emits; keyboard fallback retained |

**Nice to Have total: 4.5 days — only begin if Must Have + Should Have complete by day 9**

## Carryover from Sprint 2

| Task | Original Sprint | Reason | Sprint 3 Priority |
|------|----------------|--------|-------------------|
| Create/Implement StatusEffects (S2-07/08) | Sprint 2 Should Have | Capacity exhausted after Must Have | S3-04/05 Must Have |
| Create/Implement CombinationResolution (S2-09/10) | Sprint 2 Nice to Have | Never scheduled | S3-15/16 Should/Nice-to-Have |
| eai/006: Death Animation Timing | Sprint 2 Advisory | BLOCKED on art assets + GDD OQ#3 | Backlog |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| ADR-0013 engine verification fails | Medium | High | Keyboard-shortcut fallback confirmed in `first-playable.md`; PranaGrid moves to post-FP |
| SpellCastingEffects scope pulls in full combo pipeline | Medium | Medium | Scope to "basic cast → apply_damage" only; full pipeline is S3-16 Nice-to-Have |
| WaveManager signal ordering surprises | Low | Medium | ADR-0014 H&D contract fully specifies registration sequence; follow `register_enemy()` before `add_child()` |
| Playtest reveals fun hypothesis false | Low | **Very High** | If false: stop FP sign-off; redesign Prana loop before any further Feature-layer work |
| FP target 2026-06-14 not achievable | High | Low | Sprint ends 2026-06-17; update `first-playable.md` target date accordingly |

## Dependencies on External Factors

- ADR-0013 verification result (S3-02) gates PranaGrid epic creation and scheduling
- First playtest (S3-11) requires all of S3-05–S3-10 complete — end-to-end build must exist
- Art pipeline: GDD Open Question #3 (death animation timing) not blocking Sprint 3; backlog item

## Definition of Done for Sprint 3

- [ ] All Must Have stories implemented, code-reviewed, and closed via `/story-done`
- [ ] All Logic/Integration stories have passing unit/integration tests (headless GdUnit4)
- [ ] QA plan exists (`production/qa/qa-plan-sprint-3-*.md`) — **S3-03 gates all implementation**
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] At least 1 playtest session documented in `production/playtests/`
- [ ] First Playable hard criteria from `first-playable.md` all checked
- [ ] Fun hypothesis explicitly confirmed or falsified in playtest report
- [ ] No critical/blocker bugs in delivered features
- [ ] Design documents updated for any deviations

> ⚠️ **QA Plan Required First**: Run `/qa-plan sprint` (S3-03) before starting any implementation story. This is Must Have — not optional.
