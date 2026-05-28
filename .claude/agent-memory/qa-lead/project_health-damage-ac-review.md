---
name: health-damage-ac-review
description: Adversarial AC re-review of Health & Damage GDD (2026-05-27 revision); 6 BLOCKING, 4 RECOMMENDED, 5 ADVISORY — NOT READY FOR APPROVED STATUS
metadata:
  type: project
---

Re-review of all 31 ACs in `design/gdd/health-damage.md` (status: In Review, post-round-2 revision).

**Result: 6 BLOCKING, 4 RECOMMENDED, 5 ADVISORY — NOT READY FOR APPROVED STATUS**

**Why:** Two prior blockers were correctly fixed (AC-HD-22 partial re-arm via new AC-HD-26; AC-HD-25 same-frame non-determinism via AC-HD-25a). Three prior blockers are unresolved or only partially addressed. Six new blockers identified including: missing signal-emission negative assertion on blocked i-frame hits, untestable signal-ordering clause in AC-HD-28, zone-tracker fixture defect in AC-HD-20/21, and a completely missing AC for i-frame re-arm behavior.

**How to apply:** Block /design-review approval until all 6 BLOCKING defects are resolved. Priority order: BLOCKER-1 (elevate force_end_iframe_window to binding Rule 3 requirement), BLOCKER-6 (add i-frame re-arm AC), then BLOCKER-4/5 (fix zone-tracker fixture defect in AC-HD-20/21).

## Prior-Review Fix Status (2026-05-23 blockers)

| Prior Blocker | Fix Status |
|---|---|
| AC-HD-22 partial recovery re-arm | FIXED — AC-HD-26 added |
| AC-HD-25 same-frame non-determinism | FIXED — AC-HD-25a uses sequential calls |
| AC-HD-07 timer untestable | PARTIAL — note added but seam not elevated to binding Rule 3 requirement |
| AC-HD-06 is_invincible step-1a gap | NOT FIXED — Rule 2 pipeline still lacks step 1a; new distinct defect raised (BLOCKER-2) |
| AC-HD-23 ordering false-positive | NOT FIXED — structural ambiguity unchanged |

## BLOCKING Defects (this review)

| Tag | AC(s) | Defect |
|---|---|---|
| BLOCKER-1 | AC-HD-07 | Test seam is AC note only; Rule 3 has no binding seam requirement; programmer can implement bare Timer with no test hook and legally satisfy Rule 3 |
| BLOCKER-2 | AC-HD-06 | Missing negative assertion: `damage_taken` NOT emitted during blocked CONTACT hit; HP-unchanged alone insufficient — broken impl that emits spurious signal passes AC |
| BLOCKER-3 | AC-HD-28 | "After damage_taken" ordering clause untestable in standard GUT; no harness guidance for signal ordering; GUT watch_signals captures order but has no built-in ordering assertion |
| BLOCKER-4 | AC-HD-20 | GIVEN "current_hp=35" set directly, not via apply_damage; zone tracker uninitialized; test either vacuously passes or fails for wrong reason |
| BLOCKER-5 | AC-HD-21 | Same fixture defect as BLOCKER-4: CAREFUL zone entry not established via damage pipeline before the test hit |
| BLOCKER-6 | (none) | No AC for i-frame re-arm: Rule 3 explicitly states windows re-trigger on each qualifying CONTACT hit after previous expires; no AC covers third CONTACT hit being blocked by second window |

## RECOMMENDED Gaps

1. `damage_taken` NOT-emitted negative assertion missing for blocked contact hits (overlaps BLOCKER-2 but distinct story)
2. No AC: second hit on dead enemy must not re-emit `enemy_killed` (dead-target guard for enemies — only player side tested in AC-HD-15)
3. No boundary-value AC: `heavy_hit` exactly at `final_damage == HEAVY_HIT_THRESHOLD` (15) — `>=` vs `>` bug not caught
4. No AC: `first_run_active=true` + source=DOT or source=DIRECT does NOT apply mercy; only CONTACT triggers mercy step

## ADVISORY Gaps

- AC-HD-02: EA&W call path untested; injected multiplier bypasses integration contract — broken always-1.0 implementation passes
- AC-HD-13: `prana_affiliation` value not validated; null-always bug passes AC while breaking Audio System
- AC-HD-03: `round(18.0)` tests no rounding at all; documented banker's rounding trap (round(34.5)=34) has no AC
- AC-HD-17: `run_started` trigger mechanism unspecified; vacuous pass risk if node spawned without scene tree
- AC-HD-16: Story type not classified; Integration-type AC with no Integration test requirement enforced

## Related

- [[player-controller-ac-review]] — established is_invincible() step 1a contract that H&D Rule 2 pipeline still does not reflect
