# Story S1-03: Close Player Controller Design-Review (Round 3)

**Sprint**: 1
**Priority**: Must Have
**Status**: Ready
**Type**: Config/Data
**Owner**: (unassigned)
**Estimate**: 0.5 days
**GDD**: `design/gdd/player-controller.md` (In Revision — post-design-review round 2)
**ADR**: N/A — design review activity; no implementation code, no architectural pattern to govern
**Control Manifest Rules**: N/A — this story produces a GDD approval verdict, not implementation code

## Description

Run `/design-review design/gdd/player-controller.md` in a **fresh Claude Code session**. The GDD was authored and has completed two review rounds; round-2 blockers were addressed and it is currently `In Revision`. This story confirms all round-2 blockers are resolved and promotes Player Controller to Approved.

**Key constraint for review:** `technical-preferences.md` flags gamepad as a known-hard requirement — the reviewer must confirm a concrete gamepad interaction model is specified, not deferred.

## Acceptance Criteria

- [ ] Round-2 revision blockers confirmed resolved in GDD text (all 8 sections substantive, no "TBD")
- [ ] `/design-review` verdict is APPROVED (no BLOCKING findings)
- [ ] Gamepad interaction model is concrete and implementable — not "to be determined"
- [ ] `fayde_iframe_duration` value specified and consistent with Prana Data AC-PD-44b (`0.5s`)
- [ ] Footstep audio ownership resolved (Player Controller calls `AudioSystem.play_event()` directly OR emits a signal — one or the other, documented)
- [ ] `systems-index.md` Player Controller status confirmed as `Approved`, doc link present
- [ ] Session committed to git with `docs:` prefix

## Instructions

1. Open a **fresh** Claude Code session
2. Run: `/design-review design/gdd/player-controller.md`
3. Address any BLOCKING findings before marking DONE
4. Commit the result

## Out of Scope

- Authoring the GDD from scratch (already completed in a prior session)
- Implementing any Player Controller code (belongs to a future implementation epic)
- Writing new ADRs based on review findings (separate story if required)
- Modifying the GDD after an APPROVED verdict

## QA Test Cases

> **Design sprint:** Verification is the `/design-review` verdict.
> Implementation tests will be authored when Player Controller is implemented.

Verification checklist (from `production/qa/qa-plan-sprint-1-2026-05-26.md`):

- [ ] All 8 GDD sections present and substantive (no "TBD" in required fields)
- [ ] Gamepad movement model is concrete and implementable — not "to be determined"
- [ ] `fayde_iframe_duration` value matches or is consistent with Prana Data's `0.5s` reference
- [ ] Footstep audio ownership decision documented in Dependencies section
- [ ] AC format: at least one movement formula test in the Acceptance Criteria section
- [ ] `/design-review` APPROVED

## Test Evidence

> Fill in after completing:

- **Verdict**: ___
- **Session date**: ___
- **Commit SHA**: ___

## Dependencies

- Game State & Scene Flow GDD: `design/gdd/game-state-scene-flow.md` (Approved)
- Resolves: Audio System Open Question 3 (footstep audio ownership)
- Must precede: S1-04 (Prana Grid), S1-05 (Combination Resolution)

## Cross-System Notes

- `fayde_iframe_duration` value used in Prana Data AC-PD-44b — if the value changes from 0.5s, notify qa-lead to update Prana Data test specs
- Footstep audio: if Player Controller calls `AudioSystem.play_event("sfx_fayde_footstep")` directly, footstep sounds must be registered in `AudioEventRegistry` with `priority = LOW` and a dedicated non-pooled player is strongly recommended (per Audio System Open Question 3 note — 2–3 events/sec at normal movement speed creates pool pressure)
