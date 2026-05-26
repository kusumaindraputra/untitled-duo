# Story S1-01: Close Audio System Design-Review (Round 2)

**Sprint**: 1
**Priority**: Must Have
**Status**: Ready
**Type**: Config/Data
**Owner**: (unassigned)
**Estimate**: 0.5 days
**GDD**: `design/gdd/audio-system.md`

## Description

Run `/design-review design/gdd/audio-system.md` in a **fresh Claude Code session** (reviewing agent must be independent of authoring context). The GDD has been revised after round 1 — 18 blockers were resolved per commit `c092530`. This story closes the review loop and promotes Audio System to Approved status.

## Acceptance Criteria

- [ ] `/design-review` verdict is APPROVED or APPROVED WITH CONDITIONS (not BLOCKED)
- [ ] `systems-index.md` Audio System status updated to `Approved`
- [ ] Review session committed to git with `docs:` prefix

## Instructions

1. Open a **fresh** Claude Code session
2. Run: `/design-review design/gdd/audio-system.md`
3. Address any new BLOCKING findings before marking DONE
4. Commit the result

## QA Test Cases

> **Design sprint:** Verification is the `/design-review` verdict itself, not automated tests.
> Future implementation tests seeded by this GDD: ~38 ACs in `tests/unit/audio-system/` and `tests/integration/audio-system/`.

Verification checklist (from `production/qa/qa-plan-sprint-1-2026-05-26.md`):

- [ ] All 18 round-1 blockers confirmed resolved in GDD text
- [ ] DYING minimum hold (`DYING_MIN_HOLD_SEC = 1.5s`) specified and testable
- [ ] Stinger priority (NARRATIVE > COMBAT; last-caller-wins at same priority) unambiguous
- [ ] Music bus upper-bound clamped at −3.0 dB (SFX headroom invariant)
- [ ] AMB bus upper-bound clamped at −10.0 dB ("world breathes softly" invariant)
- [ ] Crossfade zero-guard (`fade_duration <= 0.0` → instant cut) stated
- [ ] `finished` signal for END states: `CONNECT_ONE_SHOT` at crossfade initiation (not in callback)
- [ ] Pool eviction "oldest" = smallest stored `Time.get_ticks_msec()` value; tie-break = lowest slot index
- [ ] `wave_ended` NOT connected to music state — `preparation_started` is sole trigger
- [ ] All ACs use `Time.get_ticks_msec()` (not deprecated `OS.get_ticks_msec()`)
- [ ] 7-step `AudioServer` teardown for integration tests specified in AC block
- [ ] Open Question 3 (footstep audio ownership) resolved or flagged for Player Controller GDD

## Test Evidence

> Fill in after completing the review:

- **Verdict**: ___
- **Session date**: ___
- **New blockers found**: ___
- **Commit SHA**: ___

## Dependencies

- Audio System GDD: `design/gdd/audio-system.md` (round 2 revisions committed)
