---
name: player-controller-ac-review
description: Adversarial AC review of Player Controller GDD (2026-05-27 GDD); Round 1: 6 BLOCKING resolved; Round 2 (2026-05-28): 4 BLOCKING, 5 ADVISORY, 1 PASS
metadata:
  type: project
---

Adversarial review of all 19 ACs in `design/gdd/player-controller.md`.

## Round 1 (2026-05-27) — RESOLVED

All 6 prior BLOCKINGs were fixed in the current GDD revision:
- AC-PC-02: Convergence formula corrected to use log() convergence bound
- AC-PC-10/12: Same-frame timing restated as "before next _physics_process invocation"
- AC-PC-13/14: _compute_dash_distance() and _compute_steps_per_second() defined in UI Requirements testability interface
- AC-PC-17: WHEN clause added (dash action pressed)

## Round 2 (2026-05-28)

**Result: 4 BLOCKING, 5 ADVISORY, 1 PASS**

**Why:** Revised GDD resolved all round-1 defects but exposed new testability gaps: log(0) at MOVE_FRICTION boundary, velocity assertion timing vs. move_and_slide(), i-frame clear timing not implementation-specified, and timer advancement mechanism unspecified for timer-based ACs.

**How to apply:** Block /design-review approval until all 4 BLOCKING defects are resolved. Timer implementation must be committed (Timer node vs float accumulator) to unblock AC-PC-15/16/18 test setup.

### BLOCKING Defects

| AC | Defect |
|---|---|
| AC-PC-02 | log(1.0 - MOVE_FRICTION) = log(0) = -inf at MOVE_FRICTION = 1.0 (documented valid tuning value); formula undefined; AC needs MOVE_FRICTION < 1.0 precondition or clamp |
| AC-PC-05c | velocity.length() check timing relative to move_and_slide() unspecified; vacuously true in unit test without physics scene; need explicit "before move_and_slide()" or "in wall-free physics scene" |
| AC-PC-12c | is_invincible() == false timing assumes signal handler clears flag directly; GDD does not specify this — _is_invincible clear is on timer expiry path inside _physics_process, not necessarily in signal handler |
| AC-PC-15/16 | Timer advancement mechanism unspecified; Timer node vs float accumulator require different test setups; AC cannot be written deterministically without committing to one |

### ADVISORY Defects

| AC | Issue |
|---|---|
| AC-PC-08 | "No stored last-moved direction" may be unreachable if _last_facing_dir defaults to Vector2.RIGHT at construction; GDD must specify initial value |
| AC-PC-19 | No AC covers facing direction post-snap from diagonal input; _last_facing_dir stored post-snap but snap behavior untested |
| AC-PC-18 | "Used 0.6s ago" has same timer-injection gap as AC-PC-15/16; ADVISORY due to ±0.05s tolerance |
| Missing | No AC for footstep timer suspended during DASHING (Core Rule 6 explicitly states this) |
| Missing | No AC for Edge Case 8: cooldown expires in DISABLED, available immediately on next combat_started |

### PASS

- AC-PC-16 boundary: strict > in Core Rule 6 matches explicit == FOOTSTEP_VELOCITY_THRESHOLD must-not-fire test. Correctly specified.
