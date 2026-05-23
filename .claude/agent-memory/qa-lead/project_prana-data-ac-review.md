---
name: project_prana-data-ac-review
description: Adversarial AC review of Prana Data GDD (2026-05-23); 4 BLOCKING defects, 2 RECOMMENDED gaps, 2 ADVISORY gaps — GDD claim of "32/32 independently verifiable" is incorrect
metadata:
  type: project
---

Adversarial QA review of `design/gdd/prana-data.md` AC section, conducted 2026-05-23. GDD claims "all 32 criteria are Logic-type unit tests." That claim is wrong on 4 counts.

**Why:** Prana Data is Foundation layer — all downstream systems depend on its test suite being sound. Defects here propagate to Combination Resolution, Spell Casting, Status Effects test suites.

**How to apply:** Before signing off on any Prana Data story as Done, verify these 4 BLOCKING defects are resolved in the GDD and corresponding tests are rewritten.

## 4 BLOCKING Defects

| AC | Problem |
|----|---------|
| AC-PD-04 | Requires "at least one full combat encounter" — Integration test disguised as unit test. Cannot satisfy isolation rule. Reclassify as Integration-type; rewrite Given to use mock consumer. |
| AC-PD-05 | Tests whether consuming systems (Combination Resolution, Elemental Affiliation, Prana Drop) pass integer IDs — wrong owner. Move to those systems' test suites. Replace with unit AC verifying no public string-name lookup API exists on Prana Data. |
| AC-PD-18 | Statistical range test (450–550/1000) violates project determinism standard. Blocked until Open Question 1 (seeded vs. unseeded RNG) is resolved. Must rewrite for determinism: use fixed seed + exact count, OR reclassify as Integration with manual playtest evidence. |
| AC-PD-25 | "`regen_tick_magnitude` remains 0.02 × fayde_max_hp" conflates the fraction (0.02) with the computed heal value. Programmer will store the wrong type. Rewrite to "remains 0.02 (the fraction)." Compare correct pattern in AC-PD-24: "`burn_tick_magnitude` remains 0.08." |

## 2 RECOMMENDED Coverage Gaps

- **Gap 1**: No AC verifying `base_damage_modifier` is sourced from Prana Data at the call site (not recomputed in Spell Casting & Effects). Needs Integration AC in Spell Casting test suite.
- **Gap 2**: No AC verifying `base_status` field routes to a Status Effect instantiation. AC-PD-09–22 test what statuses do, not whether the `base_status` property is what triggers them. Needs Integration AC.

## 2 ADVISORY Items

- **AC-PD-28**: "Freeze resumes with exactly 1.5s remaining" is not assertable against a frame-based timer (60 FPS = 16.67ms granularity). Add ±16.67ms tolerance or specify mocked delta-time injection.
- **Gap 3**: Stun + Burn concurrency unspecified. AC-PD-27 covers Burn+Freeze (independent), AC-PD-28 covers Stun+Freeze (timer pauses), but Stun+Burn has no AC. Programmer will guess. Add AC to disambiguate.

## Related
- [[project_game-state-gdd-review]] — prior AC review pattern for comparison
