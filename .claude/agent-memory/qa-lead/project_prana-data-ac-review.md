---
name: project_prana-data-ac-review
description: Adversarial AC review of Prana Data GDD — Round 4 (2026-05-26); 5 BLOCKING defects survive, 6 RECOMMENDED gaps, 2 ADVISORY items. Prior 10 BLOCKING: 8 confirmed fixed.
metadata:
  type: project
---

Adversarial QA review of `design/gdd/prana-data.md` AC section.
Round 1: 2026-05-23 (4 BLOCKING). Round 2: 2026-05-26 (10 BLOCKING). Round 3: 2026-05-26 (full 44-AC version with conditional depth block). Round 4: 2026-05-26 (re-review of all 48 ACs post-revision).

**Why:** Prana Data is Foundation layer — all downstream systems depend on its test suite being sound. Defects here propagate to Combination Resolution, Spell Casting, Status Effects test suites.

**How to apply:** Before signing off on any Prana Data story as Done, verify all BLOCKING defects are resolved. AC gate requires 5 fixes before Logic/Integration sprint can proceed.

## Round 4 — 5 BLOCKING Defects (5 of 10 prior resolved; 5 survive or are new)

| # | AC | Problem |
|---|---|---|
| BLOCKING-1 | AC-PD-04b | Icon isolation is an untestable instruction ("verify icon property isolation separately") — no discrete THEN assertion, no AC-PD-04c, sub-case can be silently omitted |
| BLOCKING-2 | AC-PD-33b | T_remaining is unconstrained — tester cannot guarantee a Regen tick fires during 0.8s Stun window; WHEN says "enemy is Stunned" without specifying the Stun target is NOT Fayde |
| BLOCKING-3 | AC-PD-43 | `type_modifier` undefined in GDD formulas; integer-only example (20 × 1.0 × 1.25 = 25.0) does not distinguish round() from floor(); no .5 boundary test case |
| BLOCKING-4 | AC-PD-44 | "Moment of impact" is not frame-precise; Discovery Signal Contract requires same-frame tick; deferred-tick implementation passes this AC but violates the contract |
| BLOCKING-5 | AC-PD-27 | "Freeze timer has not reset" has no numeric assertion; no elapsed time in GIVEN; broken reset at T=0 passes as written |

## Round 4 — 6 RECOMMENDED Gaps

| # | Gap |
|---|---|
| REC-01 | No AC for Follow-Through window behavior when Stunned enemy dies during 1.5s window (design gap + coverage gap) |
| REC-03 | No AC for concurrent Burn Contagion transfer to a target that already has Blind + Deepening Doubt active |
| REC-04 | No float-input formula test (e.g., base_damage=7.5) — all ACs use clean integers; intermediate truncation undetected |
| REC-05 | No AC verifying Burn cap startup assert fires when burn_tick_magnitude × burn_tick_count > 0.60 |
| REC-06 | No AC for Lightning Follow-Through window REPLACEMENT (second interrupt resets to 1.5s, no stacking) — mark blocked alongside AC-PD-42 |
| REC-07 | No AC for Burn Contagion chain depth (Contagion-transferred Burn is inert on recipient's death; no cascade) |

## Round 4 — 2 ADVISORY Items

| # | AC | Issue |
|---|---|---|
| ADV-1 | AC-PD-08 | Missing evidence type label `*(Logic — unit test)*` |
| ADV-2 | AC-PD-41 | Attack timing within Blind window not specified; extension-to-current-vs-base ambiguity |

## Prior Round 3 — 10 BLOCKING (Final Status)

| # | AC(s) | Status |
|---|-------|--------|
| B-01 | AC-PD-09, AC-PD-16 | RESOLVED — timer assertions removed; delegated to AC-PD-10/17 |
| B-02 | AC-PD-04b | PARTIALLY RESOLVED — mechanism language removed but icon instruction language introduced; becomes BLOCKING-1 |
| B-03 | AC-PD-06, AC-PD-07 | RESOLVED — GDScript `in` operator specified in both |
| B-04 | AC-PD-20 | RESOLVED — same-frame, named flags, physics step precision specified |
| B-05 | AC-PD-28, 35, 37, 38 | RESOLVED — all four have ±0.05s tolerance clauses |
| B-06 | AC-PD-18 | RESOLVED — 469–531 (95% CI), Advisory classification, GUT skip tag required |
| B-07 | AC-PD-33 | RESOLVED — split into 33a/b/c; each with distinct GIVEN/WHEN/THEN |
| B-08 | AC-PD-40 | RESOLVED — 200px test fixture specified with update note |
| B-09 | AC-PD-42 | RESOLVED — blocked on Enemy AI GDD; excluded from Prana Data gate |
| B-10 | AC-PD-44 | RESOLVED — T_remaining=1.5s GIVEN and ±0.05s THEN added |

## Fresh Defects Found in Round 4

- AC-PD-43: `type_modifier` variable undefined in Formulas section — critical (BLOCKING-3)
- AC-PD-27: No elapsed-time GIVEN, no numeric timer THEN — prior ADV-04 elevated to BLOCKING-5
- AC-PD-44: Frame-precision gap vs. Discovery Signal Contract (BLOCKING-4)
- AC-PD-33b: Unconstrained T_remaining prevents tick-guarantee (BLOCKING-2)

## Structural Issue (unchanged from Round 3)

ACs PD-20 through PD-44 (~30 ACs) test runtime status behavior, not catalog data. GDD preamble marks these "provisional — relocate to Status Effects GDD." No decision made yet on duplication risk.

## Related

- [[project_game-state-gdd-review]] — prior AC review pattern for comparison
