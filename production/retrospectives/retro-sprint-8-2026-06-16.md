# Retrospective: Sprint 8
**Period**: 2026-07-15 – 2026-07-28 (completed 2026-06-16 — pre-sprint-window pattern continues)
**Generated**: 2026-06-16
**Sprint Goal**: Perkuat game feel (dash i-frame, arena bounds, enemy variety + shooter) untuk memvalidasi fun hypothesis pada external playtest.

---

## Metrics

| Metric | Planned | Actual | Delta |
|--------|---------|--------|-------|
| Must Have stories | 5 | 5 | 0 |
| Should Have stories | 2 | 0 | −2 (human-gated) |
| Must Have completion rate | — | 100% | — |
| Overall task completion | — | 71% (5/7) | — |
| Effort days estimated (Must Have) | 3.0d | ~1.5d | −1.5d |
| Unit tests at sprint end | — | 566 | +31 vs Sprint 6 (535) |
| Unit tests passing (headless) | — | 566/566 | 0 failures, 1 skipped |
| TODO count in src/ | 1 | 1 | 0 |
| FIXME/HACK count | 0 | 0 | 0 |
| Sprint 8 commits | — | 5 | — |
| Sprint-status.yaml discrepancy | — | 1 | S8-01 shows "ready-for-dev" but QA plan file exists |

---

## Velocity Trend

| Sprint | Must Have Planned | Must Have Done | Must Have Rate | Unit Tests | Commits |
|--------|-------------------|----------------|---------------|------------|---------|
| Sprint 5 | 6 | 6 | 100% | 535 | 12 |
| Sprint 6 | 5 | 5 | 100% | 535 | 8 |
| Sprint 7 | 6 | 5 | 83% (S7-02 hardware-gated) | ~535–566 | ~10 |
| **Sprint 8** | **5** | **5** | **100%** | **566** | **5** |

**Trend**: Stable at 100% Must Have delivery for non-hardware-gated stories. Sprint 8 was the most compact sprint in effort-to-output ratio — 3 new systems (projectile, arena walls, enemy archetype color) delivered in ~1.5 actual days against a 3.0d estimate. The +31 unit test gain (535 → 566) is the strongest single-sprint test growth since Sprint 3.

---

## What Went Well

- **100% Must Have for the fifth time in six sprints**: S8-02 through S8-05 all committed on the same day with no rework. Dash i-frame, arena walls, enemy color, and Shooter archetype + Projectile system all landed clean.
- **Projectile system scoped correctly**: S8-05 was the highest-risk story (1.5d estimate, new archetype + new node type + range gating). Scope was held to straight-shot-only (no homing), and 13/13 tests passed first run. The complexity gate in the risk register worked.
- **Test suite grew by 31 cases with zero regressions**: 566/566 passed headless with 0 orphans. Every S8 story that had logic-type acceptance criteria shipped with automated coverage.
- **Arena wall implementation was trivial**: S8-03 was estimated at 0.25d and delivered faster — SegmentShape2D StaticBody2D walls at 512×384px required no design revision.
- **Enemy color system is easily extensible**: `debug_color` field on `EnemyType` resource means future archetypes get color for free — no code change needed, just set the field.

---

## What Went Poorly

- **S8-01 sprint-status.yaml not updated**: The QA plan (`production/qa/qa-plan-sprint-8-2026-06-16.md`) exists and session state says S8-01 is DONE, but `sprint-status.yaml` still shows `status: ready-for-dev`. The yaml is supposed to be the authoritative source for completion status. This discrepancy would mislead a future `/sprint-status` run.
- **Manual validation deferred before sprint 9 can start**: Dash blink visual, arena walls, enemy colors, and Rifter shooting all need visual confirmation in Godot. Sprint 9 is blocked on this until Godot can be opened. The dependency should have been clearer in the DoD.
- **ADR-0013 gamepad gate at third carry**: S7-02 → S8-06 → (will be S9-XX). The blocker (no physical gamepad) has been known since Sprint 6. Three carries with no alternate plan (e.g., record a session on another machine, reschedule for a specific date) means this gate will never close at the current rate.
- **Re-validation playtest at third total carry**: S6-07 → S7-10 → S8-07. The Sprint 7 plan explicitly noted "a 4th deferral is not permitted" for the isometric visual pass (S7-12 was resolved). The same pressure now applies to S8-07: if this carries to Sprint 10, it becomes a systemic planning failure.
- **Sprint completed before sprint window opens** (again): All S8 work was done on 2026-06-16; sprint starts 2026-07-15. The two-week sprint cadence does not match actual velocity. Either the sprint window should be shortened, or Should Have stories need a dedicated session before sprint close.

---

## Blockers Encountered

| Blocker | Duration | Resolution | Prevention |
|---------|----------|------------|------------|
| Manual validation requires Godot open | End of session | Deferred to Sprint 9 task 1 | Add "Godot session required" as explicit DoD gate; plan it at sprint start |
| Physical gamepad unavailable (ADR-0013 gate) | 3 sprints | Not resolved — S8-06 backlog | Set a hard deadline: Sprint 9 Must Have regardless of hardware access; if no gamepad by planning date, decide to descope ADR-0013 live gate entirely |
| Non-developer tester unavailable (re-validation) | 3 carries | Not resolved — S8-07 backlog | Same as above — Must Have Sprint 9 or formally descope |

---

## Estimation Accuracy

| Task | Estimated | Actual | Variance | Likely Cause |
|------|-----------|--------|----------|--------------|
| S8-02: Dash i-frame + blink | 0.5d | ~0.25d | −0.25d | Collision layer toggle is a 2-line change; blink visual was a Tween loop pattern already used elsewhere |
| S8-03: Arena walls | 0.25d | ~0.1d | −0.15d | StaticBody2D with SegmentShape2D — no design ambiguity |
| S8-04: Enemy debug_color | 0.25d | ~0.1d | −0.15d | Adding one exported field to a Resource; trivial |
| S8-05: Shooter + Projectile | 1.5d | ~1.0d | −0.5d | Straight-shot scope held; test infra already established from prior systems |

**Overall**: Must Have estimated at 3.0d, delivered in ~1.5d (50% faster). Consistent with the pattern from Sprints 5 and 6 — estimates carry 30–50% buffer that is never consumed. Consider applying a 0.6× deflation factor to future mechanical-change stories (i.e., if it feels like 1d of work, estimate 0.6d). Documentation and hardware-gated stories should remain at face value.

---

## Carryover Analysis

| Task | Original Sprint | Times Carried | Reason | Action |
|------|----------------|---------------|--------|--------|
| ADR-0013 gamepad gate | Sprint 6 (S6-05) | **3** | No physical gamepad available | **Must Have Sprint 9** — if gamepad not available by S9 planning date, descope live gate; accept theoretical validation only |
| Re-validation playtest | Sprint 6 (S6-07) | **3** | Non-developer tester not available | **Must Have Sprint 9** — book tester now, not at sprint end |

---

## Technical Debt Status

- **src/ TODO count**: 1 (unchanged since Sprint 5)
  - `combat_hud.gd:73` — `# TODO(l10n): localize before shipping` (DASH_HINT_TEXT)
- **FIXME/HACK**: 0
- **Trend**: Stable. No new debt introduced in Sprint 8. Existing tracked debt is pre-launch l10n work (appropriate to defer).
- **Test count**: 566 unit tests — highest count to date. Fully headless-green.

---

## Previous Action Items Follow-Up (from Sprint 6 Retro)

| Action Item | Status | Notes |
|-------------|--------|-------|
| ADR-0013 live gamepad gate (day 1 of S7) | **NOT DONE** | Now third carry — S8-06 backlog. Never had gamepad in any session since |
| Audio System skeleton (S6-06 → S7 Must Have) | **DONE** | S7-06 commit cd79320 — Autoload #5, 4-bus, play_event() stub |
| Formally decide on isometric visual pass | **DONE** | S7-12: `feat(s7-12): wire iso_floor_stone.png into TileSet` — binary decision made, visual pass shipped |
| Re-validation playtest (book tester at sprint start) | **NOT DONE** | Third total carry. Tester not booked. Same gap repeated |
| TR-PG-001 registry text fix | **Unknown** | Not verified in this session — low-priority item, may still be stale |

---

## Action Items for Next Iteration

| # | Action | Priority | Deadline |
|---|--------|----------|----------|
| 1 | **Manual validation in Godot** — open game, verify: dash blink visual, arena walls contain player, enemy color differentiation visible, Rifter fires and despawns projectiles. This is Sprint 9 task 0 before any new story work | High | Sprint 9 day 1 |
| 2 | **ADR-0013 gamepad gate — hard deadline** — Must Have Sprint 9. If gamepad not available by S9 planning date, make a binary decision: acquire one OR formally close ADR-0013 live gate as "theoretical validation only." Three carries is the limit | High | Sprint 9 (hard) |
| 3 | **Re-validation playtest — Must Have Sprint 9** — book a non-developer tester before sprint planning. If no tester by end of Sprint 9, descope the story and add a formal note to the playtest register | High | Sprint 9 (hard) |
| 4 | **Fix sprint-status.yaml S8-01 discrepancy** — update S8-01 status to `done` and set `completed: "2026-06-16"` | Low | Immediately (before S9 plan) |
| 5 | **Shorten sprint window or add a Should Have session** — either reduce sprint duration to match actual velocity (~3–4 day windows), or commit to a dedicated Should Have block after Must Have closes before declaring sprint done | Medium | Sprint 9 planning |

---

## Process Improvements

- **Add "Godot session required" as explicit DoD gate**: Every sprint that includes visual/feel stories should have a mandatory in-engine verification step tracked in the DoD checklist — not as an afterthought. The sprint cannot be declared done until a human has seen the features run.
- **Hardware-gated stories need a booking, not a backlog entry**: ADR-0013 and the re-validation playtest have been backlog items for three sprints. They are not "not started" — they are blocked by scheduling. Treat them as calendar items: pick a date, not a sprint slot.

---

## Summary

Sprint 8 delivered 100% of Must Have stories in a single session — the fifth at-100% sprint in six. The Projectile system (S8-05) was the headline feature and landed correctly within scope. Test count grew by 31 to 566, all green. The persistent failures are structural: ADR-0013 and the re-validation playtest have now been deferred three times each and must be Must Have in Sprint 9 or formally descoped. Manual validation in Godot is the hard gate before any Sprint 9 story can begin.
