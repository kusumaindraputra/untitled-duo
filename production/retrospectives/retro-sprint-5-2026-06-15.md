# Retrospective: Sprint 5
**Period**: 2026-06-12 – 2026-06-15 (4 calendar days; started ~2 weeks ahead of planned date 2026-06-26)
**Generated**: 2026-06-15
**Sprint Goal**: Address playtest legibility failures — Prana visual differentiation, PranaGrid compact mode, dash feedback, chain dots — before Feature layer expansion.

---

## Metrics

| Metric | Planned | Actual | Delta |
|--------|---------|--------|-------|
| Must Have stories | 6 | 6 | 0 |
| Should Have stories | 3 | 0 | −3 (all deferred) |
| Must Have completion rate | — | 100% | — |
| Overall task completion | — | 67% (6/9) | — |
| Effort days estimated (Must Have) | 6.75d | ~4 calendar days | −2.75d |
| Automated tests at sprint end | — | 535 (534 pass, 1 skip) | −50 vs Sprint 4 ⚠ |
| Commits this sprint | — | 12 | — |
| Scene-wiring fix attempts | — | 3 | Unplanned |
| TODO/FIXME/HACK in src/ | 0 | 1 | +1 (l10n TODO) |

---

## Velocity Trend

| Sprint | Planned | Completed | Must Have Rate | Tests | Commits |
|--------|---------|-----------|---------------|-------|---------|
| Sprint 2 | 10 | 6 | N/A | 288 | 16 |
| Sprint 3 | 17 | 16 | 100% | 539 | 41 |
| Sprint 4 | 9 | 6 | 100% | 585 | ~15 |
| **Sprint 5** | **9** | **6** | **100%** | **535** | **12** |

**Trend**: Must Have delivery is stable at 100% for three consecutive sprints. Should Have/Nice-to-Have delivery is 0% for two consecutive sprints — the same three stories (S4/5-07, S4/5-08, S4/5-09) have been deferred twice. Test count decreased by 50 vs Sprint 4 — cause unknown, requires investigation.

---

## What Went Well

- **100% Must Have for third consecutive sprint**: All six S5-01–S5-06 stories closed on time. The legibility failures from the playtest (combination visuals, compact PranaGrid, dash hint, chain dots) are fully addressed.
- **QA plan gate ran on day 1**: Sprint 3 Action Item #1 (run `/qa-plan sprint` before any story work) finally landed correctly. S5-01 was the first story completed (2026-06-12). Three sprints to close this action item; it's now a habit.
- **Sprint 5 delivered in 4 calendar days** vs the 14-day window: the focused, well-scoped legibility pass was achievable quickly because the implementation paths were clear from the playtest evidence.
- **AC-HUD-27 assertion strengthened in code review**: The initial chain-dot position test only checked "above Fayde" (any Y < Fayde Y passes). Code review caught this and changed it to assert the full 48px offset magnitude — a real quality improvement that makes the test meaningful.
- **Screen-space tracking implementation clean**: The `get_viewport().get_canvas_transform() * fayde_node.global_position` pattern + `maxf()` clamp is 5 lines and handles all four AC-HUD-27–30 criteria without additional state.

---

## What Went Poorly

- **Scene wiring required 3 fix commits**: After implementing S5-05 and S5-06 with `@export var` for testability, the live scene wiring failed silently in-game. First attempt: `.tscn NodePath` override with `../../PlayerController` (wrong path direction assumption). Second attempt: `NodePath("PlayerController")` (correct path from owner, but still failed). Root cause: Godot 4 initializes nodes in scene-file order — CombatHUD enters the tree before PlayerController is added, so NodePath resolution at that moment returns null. Fix: wire in `debug_game_loop._ready()` which fires after all siblings are in the tree. This wasted ~0.5d and 3 commits.
- **No documentation of Godot 4 scene ordering** in coding standards: this was a discoverable rule (sibling ordering matters for NodePath resolution) but it wasn't written down anywhere, causing the same mis-assumption to be tried twice.
- **Test count dropped by 50** (585 → 535): Sprint 4 smoke check reported 585 tests; Sprint 5 closes with 535. The cause is not identified. No tests were intentionally removed this sprint. This could indicate a test runner configuration change, a test file that stopped being discovered, or tests consolidated during S5-03 SpellVFX work. Unresolved going into Sprint 6.
- **S5-07/08/09 deferred for the second sprint in a row**: PranaGrid gamepad (ADR-0013 HIGH risk), tech debt review, and isometric visual pass have now been carried over from S4 → S5 → S6. Tech debt review in particular has appeared in action items since Sprint 2.

---

## Blockers Encountered

| Blocker | Duration | Resolution | Prevention |
|---------|----------|------------|------------|
| `@export` NodePath cross-sibling resolution fails when target node appears later in .tscn order | ~0.5d, 3 commits | Wire in `debug_game_loop._ready()` — parent fires after all children | Document Godot 4 scene ordering rule in coding standards |
| Smoke check FAIL on first run (scene wiring silent failure) | 1 session | Root cause diagnosed from Debugger warning + in-game behaviour | The NodePath approach should have been validated against scene order first |

---

## Estimation Accuracy

| Task | Estimated | Actual | Variance | Likely Cause |
|------|-----------|--------|----------|--------------|
| S5-03: Prana visual differentiation | 2.5d | ~0.5d | −2d | SpellVFX Autoload is signal routing only — lighter than a full gameplay system |
| S5-04: PranaGrid compact mode | 1.5d | ~0.5d | −1d | Pattern already established from PranaGrid base; compact mode was a state variant |
| S5-06: Chain dots above player | 0.75d | ~1.25d | +0.5d | Scene wiring debug added ~0.5d beyond implementation |
| S5-05: Dash hint + cooldown | 1.0d | ~1d | on track | Estimate accurate |

**Overall**: Must Have estimates were collectively over-estimated. Visual/feel work was faster than S3's CombatHUD baseline suggested (S3's ×3 multiplier was applied but not needed at this scope). Scene-wiring debugging ate the recovered time from S5-03/04 underruns.

---

## Carryover Analysis

| Task | Original Sprint | Times Carried | Reason | Action |
|------|----------------|---------------|--------|--------|
| PranaGrid gamepad (S5-07) | S4-07 | 2 | ADR-0013 HIGH engine risk; crowded out by playtest fixes | Must schedule in Sprint 6 — gamepad players can't complete the loop |
| Tech debt review (S5-08) | S4-08 (from S3 action item) | 2+ | Low priority, always below the sprint line | Escalate to Sprint 6 Must Have; 3 sprints of deferral is a smell |
| Isometric visual pass (S5-09) | S4-09 | 2 | Art/asset work, not on critical path | Nice-to-have; decide whether to buy/make assets or formally descope |

---

## Technical Debt Status

- **src/ TODO count**: 1 (was 0 at Sprint 3 close, 0 at Sprint 4 close)
  - `combat_hud.gd:73` — `# TODO(l10n): localize before shipping` (DASH_HINT_TEXT)
- **FIXME/HACK**: 0
- **Trend**: Stable with one new TODO. Acceptable for pre-alpha; should be added to the tech debt register before any localisation work begins.
- **Formal tech debt register**: Not reviewed since Sprint 3. S5-08 deferred again.

---

## Previous Action Items Follow-Up

| Action Item (Sprint 3) | Status | Notes |
|------------------------|--------|-------|
| Run `/qa-plan sprint` before first story | **DONE** | S5-01 first story completed day 1. First time this rule was fully honoured. |
| Implement PranaGrid | **DONE** | Shipped in Sprint 4 |
| External human playtest | **DONE** | Sprint 4 — PARTIALLY CONFIRMED verdict |
| Apply ×3 multiplier to UI/visual estimates | **PARTIAL** | Estimates adjusted; delivered faster than expected — multiplier may be too conservative for signal-routing visual work |
| Tech debt review pass | **NOT DONE** | Now 3 sprints deferred — S5-08 backlog again |

---

## Action Items for Next Iteration

| # | Action | Priority | Deadline |
|---|--------|----------|----------|
| 1 | **Investigate test count drop** — run full suite with directory listing to find what 50 tests went missing between Sprint 4 (585) and Sprint 5 (535) | High | Sprint 6 day 1 |
| 2 | **Document Godot 4 scene wiring rule** in `coding-standards.md`: cross-sibling `@export Node` references must be wired in parent `_ready()`, not via NodePath in `.tscn`, when scene ordering isn't guaranteed | High | Sprint 6 day 1 |
| 3 | **Tech debt review (S5-08)** — 3 sprints deferred; promote to Sprint 6 Must Have. Run `/tech-debt` to close or formally accept all open entries | High | Sprint 6 |
| 4 | **PranaGrid gamepad (S5-07)** — 2 sprint carryover; ADR-0013 HIGH risk path still unvalidated. Gamepad players cannot complete the full loop without this | Medium | Sprint 6 |
| 5 | **Decide on S5-09 isometric visual pass** — either schedule with art assets or formally descope. 2 deferrals without a decision is scope ambiguity | Low | Sprint 6 planning |

---

## Process Improvements

- **Add Godot 4 scene ordering rule to coding standards**: When `@export var x: Node` references a sibling in the parent scene, wire it in the parent's `_ready()` (not via `.tscn` NodePath override). Now documented in `debug_game_loop.gd` comments but must be in shared standards so the next system doesn't rediscover it.
- **Verify test count at sprint start**: Check suite count against the previous sprint's smoke report before any story work begins. A silent drop of 50 tests should be caught on day 1, not at sprint close.

---

## Summary

Sprint 5 delivered all six Must Have legibility fixes in 4 calendar days — 100% Must Have rate for the third consecutive sprint. The playtest failures (Prana type confusion, hidden dash, chain dots in wrong position) are addressed and smoke-checked PASS. The main friction point was scene wiring: a Godot 4 node ordering rule that caused three fix commits and a smoke FAIL on first run. Two recurring deferred items (tech debt review, gamepad input) must be elevated to Must Have in Sprint 6 or formally descoped — three-sprint deferral without a decision is the primary process risk going into the next cycle.
