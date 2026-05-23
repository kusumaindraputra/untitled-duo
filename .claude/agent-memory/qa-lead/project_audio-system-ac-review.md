---
name: project_audio-system-ac-review
description: Two-round adversarial AC review of Audio System GDD; Round 1 (2026-05-23): 8 BLOCKING defects. Round 2 (2026-05-23): 6 new/surviving BLOCKING defects after revision
metadata:
  type: project
---

Adversarial QA review of `design/gdd/audio-system.md` AC section, conducted 2026-05-23 (two rounds).

**Why:** Audio System is Foundation layer — all sound-emitting systems (Game Feel, Spell Casting, Health & Damage, Enemy AI, UI) depend on this system. If the test suite is wrong, audio regressions cannot be caught automatically.

**How to apply:** Before any Audio System story is marked Done, verify all BLOCKING defects are resolved. Round 2 found that Tween.custom_step() does not exist in Godot 4 — this is a critical constraint affecting AC-AS-14, AC-AS-24, AC-AS-25, and AC-AS-28. All time-advance assertions must use pure functions or be downgraded to manual tests.

## Round 1 — 8 BLOCKING Defects (original review)

All 8 were addressed in the revision. Round 2 found 6 new/surviving blockers introduced by that revision.

## Round 2 — 6 BLOCKING Defects (second re-review, 2026-05-23)

| ID | AC | Problem |
|----|-----|---------|
| R2-01 | AC-AS-04 | `playing == true` still unassertable in headless GUT — audio thread not running in CI. Fix accepted wrong assertion. Must assert `stream == dummy` and `bus == &"SFX"` instead. |
| R2-02 | AC-AS-11 | Double-trigger scenario (both wave_ended and preparation_started firing while in COMBAT) not tested. AC masks the bug; does not catch a double-crossfade start. New AC-AS-33 required. |
| R2-03 | AC-AS-14, AC-AS-24, AC-AS-28 | `Tween.custom_step()` does not exist in Godot 4 — Tween is a reference-counted object, not a node. Three ACs are unimplementable. Solution: test state transitions only; volume midpoint covered by AC-AS-16 pure function. |
| R2-04 | AC-AS-25 | Mid-fade volume assertion immediately after second `play_ambient()` call is impossible — tween has not advanced. Must assert tween property targets, not current volume values. |
| R2-05 | AC-AS-26 | `finished` signal emitted before `_on_end_crossfade_complete` connects it via CONNECT_ONE_SHOT. Signal is not connected at test time. Must call `_on_end_crossfade_complete()` directly first. |
| R2-08 | MISSING | No AC for `play_event()` with `bus = &"AMB"` — must log error and not start playback (GDD Core Rule 3). New AC-AS-34 required. |

## Round 2 — 2 RECOMMENDED Gaps

| ID | AC | Problem |
|----|-----|---------|
| R2-06 | AC-AS-06 Test C | "The LOW slot" ambiguous with 15 LOW slots. Timestamps not set to identify which specific slot should be evicted. |
| R2-07 | AC-AS-15 | State not asserted after each individual signal call. A transition to a different END state would not be caught by the single final assertion. |

## Round 2 — 2 ADVISORY Items

| ID | AC | Problem |
|----|-----|---------|
| R2-09 | AC-AS-07, AC-AS-23 | `playing == true` assertions share same headless-GUT problem as AC-AS-04. |
| R2-10 | AC-AS-18, AC-AS-19 | Float equality tolerance not specified; AC-AS-17 uses `is_equal_approx()` but 18/19 do not. |

## Key Engine Constraint Discovered in Round 2

`Tween.custom_step()` does NOT exist in Godot 4. In Godot 4, Tween is a reference-counted object (not a node) with no time-injection API. Any AC requiring deterministic tween advancement must either: (a) test a pure function instead, or (b) use real-time `await` (flaky in CI), or (c) be downgraded to a manual/visual test. This affects AC-AS-14, AC-AS-24, AC-AS-25, AC-AS-28 and any future tween-dependent ACs.

## Related
- [[project_prana-data-ac-review]] — prior adversarial AC review pattern
- [[project_game-state-gdd-review]] — prior AC review pattern
