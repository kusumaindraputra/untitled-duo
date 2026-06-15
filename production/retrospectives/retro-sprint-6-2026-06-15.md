# Retrospective: Sprint 6
**Period**: 2026-06-15 (planned 2026-06-16 – 2026-06-30; completed in one session)
**Generated**: 2026-06-15
**Sprint Goal**: Close post-First Playable housekeeping (test count integrity, tech debt, scene wiring docs), complete PranaGrid gamepad input, and begin Audio System to unblock the Feature layer.

---

## Metrics

| Metric | Planned | Actual | Delta |
|--------|---------|--------|-------|
| Must Have stories | 5 | 5 | 0 |
| Should Have stories | 2 | 0 | −2 (not started) |
| Nice to Have stories | 2 | 0 | −2 (not started) |
| Must Have completion rate | — | 100% | — |
| Overall task completion | — | 56% (5/9) | — |
| Effort days estimated (Must Have) | 4.25d | ~2.5d | −1.75d |
| Unit tests at sprint end | 535 | 535 | 0 |
| Full suite (unit + integration) | — | 623 | — |
| TODO count in src/ | 1 | 1 | 0 |
| FIXME/HACK count | 0 | 0 | 0 |
| Sprint 6 commits | — | 8 | — |
| Code review bugs caught | — | 2 | — |

---

## Velocity Trend

| Sprint | Must Have Planned | Completed | Must Have Rate | Unit Tests | Commits |
|--------|-------------------|-----------|---------------|------------|---------|
| Sprint 3 | 17 | 16 | 100% | 539 | 41 |
| Sprint 4 | 9 | 6 | 100% | 585 | ~15 |
| Sprint 5 | 6 | 6 | 100% | 535 | 12 |
| **Sprint 6** | **5** | **5** | **100%** | **535** | **8** |

**Trend**: Must Have delivery stable at 100% for four consecutive sprints. Should Have/Nice-to-Have delivery remains 0% — S6-06/07/08/09 not started. The sprint was completed in a single extended session (~2.5 actual effort days vs 4.25 estimated), continuing the pattern from Sprint 5.

---

## What Went Well

- **100% Must Have for the fourth consecutive sprint**: All five S6-01–S6-05 stories closed on time with code review. The action items from Sprint 5 retrospective were addressed almost one-for-one: test count investigation done (S6-02), scene wiring rule documented (S6-03), tech debt reviewed (S6-04), PranaGrid gamepad implemented (S6-05).
- **Sprint 5 action items had a 4/5 close rate**: Only the isometric visual pass decision (S5 Action Item #5) remains unresolved. This is the highest action-item close rate across all retrospectives reviewed.
- **Code review caught a real correctness bug**: The `is_action_pressed` → `is_action_just_pressed` issue would have caused OS key-repeat to rapid-fire d-pad navigation and place/clear actions when a button was held. Hardware-dependent UI can't be caught by headless tests — code review was the only gate that could find this. Validates running `/code-review` on UI stories even when no automated tests exist.
- **S6-02 root cause found quickly**: The 585→535 test count drop that went unresolved from Sprint 5 was traced to a runner scope difference (unit: 535 vs full suite: 623) in ~15 minutes. No tests were missing. Documentation filed; the discrepancy had a mundane explanation.
- **Tech debt register fully actioned (S6-04)**: 38 entries reviewed — 1 RESOLVED, 12 ACCEPTED, 25 SCHEDULED. The register had been deferred for 3+ sprints. Now current with a `Last reviewed: 2026-06-15` date stamp.
- **ADR-0013 implementation followed the spec precisely**: `_selected_slot_index`, `_gamepad_cursor` overlay, `MOUSE_FILTER_IGNORE`, `await process_frame` positioning, event-driven mode detection — all confirmed present and correct by the godot-specialist review.

---

## What Went Poorly

- **Should Have stories untouched again**: S6-06 (Audio System skeleton) and S6-07 (re-validation playtest) were not started. This follows the same pattern as Sprints 4 and 5 — Should Have stories accumulate in backlog. The sprint goal included "begin Audio System"; it was not begun.
- **S6-08/09 still deferring without a decision**: Isometric visual pass (S4-09 → S5-09 → S6-08) has now been carried three times. No formal decision to descope or schedule. This is scope ambiguity masquerading as backlog management.
- **ADR live gate not completed in session**: AC-0013-01a, 01c, 02, 05 require a physical gamepad. The story closed COMPLETE WITH NOTES with the ADR-0013 evidence file blank. This is acceptable for the sprint close, but the gate has been open since the story was written. If gamepad testing is repeatedly deferred, the ADR validation is purely theoretical.
- **Sprint completed before it officially started**: All Must Have work was done on 2026-06-15; sprint officially starts 2026-06-16. The 14-day sprint window is not being used. Either sprint cadence should be shortened to match actual velocity, or Should Have / Nice to Have should be given a dedicated block before the sprint is "closed."
- **TR-PG-001 registry text stale**: The registry says "Sprite2D cursor" while ADR-0013 Decision says "Control overlay" — the implementation correctly followed the ADR, but the registry diverged from the ADR without a revision entry. A stale TR can mislead the next developer who reads it.

---

## Blockers Encountered

| Blocker | Duration | Resolution | Prevention |
|---------|----------|------------|------------|
| `is_action_pressed` API misuse (holds repeat) | Caught in code review | Replaced all 8 calls with `is_action_just_pressed` | Always run `/code-review` before `/story-done` on UI stories |
| Duplicate TYPE_NAMES/TYPE_COLORS constants | Caught in code review | Replaced with `PranaTypeToken.TYPE_NAMES[n]` references | Single-source-of-truth rule in manifest; code review catches violations |
| ADR-0013 live gamepad gate not achievable in session | Ongoing | Story closed COMPLETE WITH NOTES; evidence file pending | Schedule gamepad session at sprint start, not as a close-out item |

---

## Estimation Accuracy

| Task | Estimated | Actual | Variance | Likely Cause |
|------|-----------|--------|----------|--------------|
| S6-01: QA plan | 0.5d | ~0.25d | −0.25d | Automated skill, minimal manual input required |
| S6-02: Test count investigation | 0.5d | ~0.25d | −0.25d | Root cause was simpler than feared (scope mismatch, not missing tests) |
| S6-03: Scene wiring doc | 0.25d | ~0.1d | −0.15d | One-section doc edit; pattern was already understood |
| S6-04: Tech debt review | 0.5d | ~0.5d | 0 | Accurate estimate — 38 entries required methodical one-by-one review |
| S6-05: PranaGrid gamepad | 2.5d | ~1.5d | −1.0d | ADR-0013 HIGH risk buffer not consumed; engine risk materialised as 2 code review fixes, not a design rethink |

**Overall**: Must Have stories estimated at 4.25d, delivered in ~2.5d (41% faster). The HIGH risk buffer for S6-05 was not consumed; ADR-0013 risk resolved as fixable code review issues rather than architectural unknowns. Estimation continues to over-estimate for housekeeping and documentation tasks.

---

## Carryover Analysis

| Task | Original Sprint | Times Carried | Reason | Action |
|------|----------------|---------------|--------|--------|
| S6-06: Audio System skeleton | Sprint 6 (new) | 0 | Not started; Should Have not reached | Must Have in Sprint 7 — Audio System unblocks Feature layer sound |
| S6-07: Re-validation playtest | Sprint 6 (new) | 0 | Not started; requires non-developer tester | Schedule tester before Sprint 7 starts |
| S6-08: Isometric visual pass | S4-09 / S5-09 / S6-08 | **3** | Always nice-to-have, never prioritised | Formally decide: schedule Sprint 7 with art assets OR descope to post-Feature-layer |
| S6-09: Audio System SFX pool | Depends on S6-06 | — | S6-06 not done | Remains Sprint 7 Should Have once S6-06 is promoted to Must Have |
| ADR-0013 live gamepad gate | S6-05 COMPLETE WITH NOTES | 0 | No gamepad in session | Do in Sprint 7 day 1 (connect gamepad, fill evidence file) |

---

## Technical Debt Status

- **src/ TODO count**: 1 (unchanged from Sprint 5)
  - `combat_hud.gd:73` — `# TODO(l10n): localize before shipping` (DASH_HINT_TEXT)
  - Now formally tracked in `docs/tech-debt-register.md` (added during S6-04)
- **FIXME/HACK**: 0
- **Trend**: Stable — no new debt introduced in Sprint 6. The tech debt register is now current for the first time since Sprint 3.
- **TR registry drift**: TR-PG-001 says "Sprite2D cursor" but ADR-0013 and implementation use Control/Panel overlay. Low-priority text fix for Sprint 7.

---

## Previous Action Items Follow-Up

| Action Item (from Sprint 5) | Status | Notes |
|-----------------------------|--------|-------|
| Investigate test count drop (585→535) | **DONE** | S6-02: scope mismatch, not missing tests. Documented in production/qa/test-count-delta-s4-s6.md |
| Document Godot 4 scene wiring rule | **DONE** | S6-03: committed to .claude/docs/coding-standards.md |
| Tech debt review (S5-08) | **DONE** | S6-04: 38 entries actioned, register updated |
| PranaGrid gamepad (S5-07) | **DONE** | S6-05: COMPLETE WITH NOTES — implementation merged; ADR-0013 live gate pending |
| Decide on isometric visual pass | **NOT DONE** | Still S6-08 Nice to Have with no formal decision |

---

## Action Items for Next Iteration

| # | Action | Priority | Deadline |
|---|--------|----------|----------|
| 1 | **ADR-0013 live gamepad gate** — connect gamepad, run game, fill in `production/qa/evidence/prana-grid-gamepad-adr0013.md` (6 mandatory checks). Do this Sprint 7 day 1 before any new story work | High | Sprint 7 day 1 |
| 2 | **Audio System skeleton (S6-06)** — promote to Sprint 7 Must Have. Autoload #5, 4-bus setup, `play_event()` stub. Audio blocks Feature layer sound integration | High | Sprint 7 |
| 3 | **Formally decide on isometric visual pass** — after 3 deferrals, make a binary choice: schedule with art assets in Sprint 7, or move to post-Feature-layer. Ambiguity is not a decision | Medium | Sprint 7 planning |
| 4 | **Re-validation playtest (S6-07)** — schedule non-developer tester at the start of Sprint 7, not the end. Tester availability has been the blocker twice | Medium | Sprint 7 |
| 5 | **Fix TR-PG-001 registry text** — update "Sprite2D cursor" to "Control overlay" to match ADR-0013 Decision section | Low | Sprint 7 |

---

## Process Improvements

- **Pull Should Have stories into session before declaring sprint done**: The pattern of "Must Have done in one session → sprint declared complete" means Should Have never gets touched. Try: after Must Have closes, immediately start S6-06 skeleton rather than queuing it for the next sprint.
- **Book the ADR live gate at story start, not story end**: ADR-0013 required a physical gamepad. This was known from the story's inception. Scheduling it as a close-out step (at the end of a session where a gamepad may not be available) is why it's still open. When a story has a hardware dependency, the test session should be the first thing booked.

---

## Summary

Sprint 6 delivered 100% of Must Have stories in a single session — the fourth consecutive sprint at 100% Must Have rate. All five Sprint 5 action items with clear code deliverables (test investigation, scene wiring doc, tech debt review, gamepad implementation) were closed. The pattern of Should Have stories not being touched continues: S6-06 (Audio System) and S6-07 (re-validation playtest) carry into Sprint 7. The most important change for Sprint 7 is to treat the ADR-0013 live gamepad session and the Audio System skeleton as day-1 items, not sprint-end items, and to formally resolve the three-sprint-old isometric visual pass deferral.
