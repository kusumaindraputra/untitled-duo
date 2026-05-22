---
name: project_game-state-gdd-review
description: QA adversarial review of Game State & Scene Flow GDD ACs — post-revision findings (2026-05-22 revised GDD, 9 MVP + 16 VS ACs)
metadata:
  type: project
---

Adversarial AC review completed 2026-05-22 on the revised Game State & Scene Flow GDD (Foundation layer). GDD status: "In Design (Revised — Post-Review 2026-05-22)". 9 MVP ACs + 16 VS ACs + 1 CI lint rule.

**BLOCKING findings:**

- AC-06 [U] label is wrong — GDScript has no caller-identity API; the authorized-caller guard is already covered by the CI grep lint rule; no additional GUT test is implementable. Must either retag [CI] or rewrite to test an injectable authorization hook.
- AC-07 "same frame" is meaningless in a synchronous GUT test — both calls are trivially in the same frame. Rewrite as a re-entrancy guard test without frame-boundary language.
- AC-08 asserts `visible = true` but intent is "present in scene tree" — wrong property (`is_inside_tree()` needed). Also the [I] scope requires a nearly full scene stack, making it a playtest-equivalent rather than a narrow integration test. Should split into [U] node presence check + merge with [M] AC-09.
- Core Rule 4 (payload-based transitions) has no AC for null/invalid payload rejection. Missing error-path guard for VS payload routing.

**RECOMMENDED findings:**

- AC-03 has no over-emission guard: no AC covers calling `start_run()` a second time while already in-run.
- ACs 04, 06, 07, VS-15 reference "validation error is recorded" but GDD never defines the error-recording interface. Test cannot assert against an unspecified mechanism.
- AC-09 partially duplicates the AC-08 walkthrough scenario — should cross-reference.

**ADVISORY findings:**

- `run_ended(win: bool)` payload correctness (true vs false) is never asserted in any AC.
- `state_changed(old_state, new_state)` payload values are never asserted.
- AC-VS-14 is labeled [U] but requires a graph fixture with edges — retag [I].

**Why:** Foundation layer — every downstream system subscribes to these signals. AC gaps here become silent assumptions in every GDD that follows.

**How to apply:** When reviewing downstream GDDs (Prana Grid, Player Controller, Health & Damage), verify their ACs do not rely on the untested behaviors above. Block sprint review on any Logic/Integration story that exercises AC-06, AC-07, or Core Rule 4 payload routing until those ACs are rewritten and tests exist.
