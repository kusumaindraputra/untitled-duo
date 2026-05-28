---
name: project_audio-system-ac-review
description: Four-round adversarial AC review of Audio System GDD; Round 4 (2026-05-26): 3 BLOCKING (stinger priority 3 branches uncovered, DYING duck suppression uncovered, AC-AS-36 vacuous restore assertion), 4 RECOMMENDED, 5 ADVISORY
metadata:
  type: project
---

Adversarial QA review of `design/gdd/audio-system.md` AC section, conducted 2026-05-23 (rounds 1-2), 2026-05-26 (round 3), and 2026-05-26 (round 4 — fresh pass on revised document).

**Why:** Audio System is Foundation layer — all sound-emitting systems (Game Feel, Spell Casting, Health & Damage, Enemy AI, UI) depend on this system. If the test suite is wrong, audio regressions cannot be caught automatically.

**How to apply:** Before any Audio System story is marked Done, verify all BLOCKING defects are resolved. Round 2 found that Tween.custom_step() does not exist in Godot 4 — this is a critical constraint affecting AC-AS-14, AC-AS-24, AC-AS-25, and AC-AS-28. All time-advance assertions must use pure functions or be downgraded to manual tests. Round 3 found 6 new BLOCKINGs in the stinger ACs and DYING hold guard.

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

## Round 3 — 6 BLOCKING Defects (2026-05-26)

| ID | AC | Problem |
|----|----|---------|
| R3-01 | AC-AS-35 | Duck volume assert reads AudioServer bus before tween advances (0.1s fade-in) — always passes even if duck tween never created. Replace with `_active_stinger_tween non-null` assertion. |
| R3-02 | AC-AS-36 | "stream null or reassigned" vacuously passes since stop() doesn't null the stream. Missing assertion: `_stinger_player.finished.is_connected(_on_stinger_finished) == false`. |
| R3-03 | AC-AS-26 | "Incoming player" identification unspecified — test may emit finished on wrong A/B player, missing the CONNECT_ONE_SHOT handler. Fix: assert which player has END_DEFEAT stream assigned before emitting. |
| R3-04 | AC-AS-29 Test B | `_set_dying_elapsed()` injection doesn't guarantee state transition without triggering evaluation loop. Timer callback never fires in headless GUT. Accessor must call pending-transition check inline. |
| R3-05 | AC-AS-15 | Single final assert can't identify which of 4 signals broke the END guard. Assert state after each individual signal call. |
| R3-06 | AC-AS-29 Test A | "or equivalent" accessor for `_pending_defeat_transition` leaves assertion unimplementable. Remove queued-flag assertion; state-is-DYING is sufficient; Test B covers the queuing behavior. |

## Round 3 — 4 RECOMMENDED Gaps

| ID | AC | Problem |
|----|-----|---------|
| R3-07 | MISSING | No AC for DYING-state stinger duck suppression (Core Rule 12 named exception — duck tween must NOT be created when music_state == DYING). |
| R3-08 | MISSING | No AC for stinger priority policy (3 branches: NARRATIVE blocks COMBAT, COMBAT yields to NARRATIVE, same-priority last-caller-wins). |
| R3-09 | AC-AS-06 Test C | "a LOW slot evicted" doesn't verify oldest-first — must designate and assert specific slot via `_set_slot_timestamp`. (Carried from R2-06.) |
| R3-10 | MISSING | No AC for Edge Case 14: out-of-range priority clamped to NORMAL at registration with push_error(). |

## Round 4 — 3 BLOCKING Defects (2026-05-26, fresh pass on revision 3)

| ID | AC | Problem |
|----|----|---------|
| R4-01 | MISSING (35a/35b/35c) | No AC for stinger priority policy: 3 branches (NARRATIVE blocks COMBAT, COMBAT yields to NARRATIVE, same-priority last-caller-wins) have zero coverage. Any priority comparison inversion passes all tests. |
| R4-02 | MISSING | No AC for DYING-state duck suppression. Missing guard → `_prior_music_volume_db` captured at −80 dB → restore to −80 dB → END_DEFEAT music never plays. |
| R4-03 | AC-AS-36 | `_active_stinger_tween is non-null` assertion is vacuous. Does not prove tween targets `prior_music_volume_db`. A tween targeting 0.0 dB passes the AC but snaps music to max on every stinger end. Add `get_stinger_restore_target()` accessor assertion or promote Manual QA to REQUIRED. |

## Round 4 — 4 RECOMMENDED Gaps (2026-05-26)

| ID | AC | Problem |
|----|-----|---------|
| R4-04 | MISSING | No AC for `duck_depth_db = 0.0` (sfx_stinger_run_start). Duck guard must produce no tween — untested interaction with DYING-state suppression logic. |
| R4-05 | MISSING | No AC for startup validate-on-register malformed entry (non-AudioEventData value). S1 crash risk if type guard missing; untested despite being explicitly specced. |
| R4-06 | MISSING | No AC for interrupted stinger baseline re-capture (Edge Case 15). Stale `_prior_music_volume_db` → restores to wrong volume after stinger-interrupts-stinger. |
| R4-07 | MISSING | No AC for priority out-of-range clamp to NORMAL (Edge Case 14). Carried from R3-10. |

## Round 4 — 5 ADVISORY Items (2026-05-26)

| ID | AC | Problem |
|----|-----|---------|
| R4-08 | AC-AS-22, AC-AS-05, AC-AS-34 | `push_error()` assertion not implementable in headless GUT without a wrapper. Tests pass even if logging removed. |
| R4-09 | Teardown step 6 | Tween kill should be step 1 (before stream/bus resets), not step 6. Mid-execution restore tween may overwrite bus volume reset. |
| R4-10 | Teardown | `_pending_defeat_transition` flag not cleared in teardown. Stale flag causes false END_DEFEAT transitions in subsequent tests after AC-AS-29 Test A. |
| R4-11 | Teardown | `_prior_music_volume_db` not cleared in teardown. Stale baseline readable by accessors in subsequent tests. |
| R4-12 | AC numbering | All 38 ACs present (01–38). AC-AS-32 misplaced in Volume section structurally. AC-AS-33 intentionally placed with AC-AS-11. No orphaned numbers. |

## Round 3 — 4 MINOR Observations

| ID | AC | Problem |
|----|-----|---------|
| R3-11 | AC-AS-36 manual QA | Restore target should be `prior_music_volume_db` (exact reference), not "approximately". |
| R3-12 | AC-AS-20 | Missing upper-bound round-trip test for Music bus −3.0 ceiling; cross-reference AC-AS-37. |
| R3-13 | Teardown | Kill tweens before resetting streams; current order risks null-dereference in tween completion callbacks during cleanup. |
| R3-14 | AC-AS-18, AC-AS-19 | Exact float == inconsistent with AC-AS-17's is_equal_approx(). |

## Key Engine Constraint Discovered in Round 2

`Tween.custom_step()` does NOT exist in Godot 4. In Godot 4, Tween is a reference-counted object (not a node) with no time-injection API. Any AC requiring deterministic tween advancement must either: (a) test a pure function instead, or (b) use real-time `await` (flaky in CI), or (c) be downgraded to a manual/visual test. This affects AC-AS-14, AC-AS-24, AC-AS-25, AC-AS-28 and any future tween-dependent ACs.

## Related
- [[project_prana-data-ac-review]] — prior adversarial AC review pattern
- [[project_game-state-gdd-review]] — prior AC review pattern
