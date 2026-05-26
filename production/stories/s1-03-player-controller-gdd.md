# Story S1-03: Design Player Controller GDD

**Sprint**: 1
**Priority**: Must Have
**Status**: Ready
**Type**: Config/Data
**Owner**: (unassigned)
**Estimate**: 2.0 days
**GDD**: `design/gdd/player-controller.md` (to be created)

## Description

Author the Player Controller GDD using `/design-system player-controller`. This system owns Fayde's movement, dash mechanic, input handling, i-frame logic, and hitbox detection. It is a Core-layer system with no upstream game system dependencies (only Game State & Scene Flow, which is Approved).

**Key constraint:** `technical-preferences.md` flags gamepad as a known-hard requirement — the GDD must specify a concrete gamepad interaction model, not defer it.

## Acceptance Criteria

- [ ] GDD file created at `design/gdd/player-controller.md`
- [ ] All 8 required sections present: Overview, Player Fantasy, Detailed Rules, Formulas, Edge Cases, Dependencies, Tuning Knobs, Acceptance Criteria
- [ ] Movement speed formula defined with variables, ranges, and example calculation
- [ ] Dash mechanic specified: i-frame duration (`fayde_iframe_duration`), cooldown, distance, cancellability
- [ ] Input handling defined for keyboard/mouse AND gamepad (analog stick directional movement)
- [ ] Footstep audio ownership resolved (does Player Controller call `AudioSystem.play_event()` directly, or emit a signal?)
- [ ] `fayde_iframe_duration` value specified — must be consistent with Prana Data's Injury Bloom rule (AC-PD-44b uses `fayde_iframe_duration = 0.5s`)
- [ ] `DamageSource.CONTACT` vs `DamageSource.DIRECT` distinction addressed or cross-referenced to Health & Damage GDD
- [ ] Dependencies section lists Game State & Scene Flow (Approved) as upstream
- [ ] Acceptance criteria are in testable format (GIVEN/WHEN/THEN or equivalent)
- [ ] `/design-review` returns APPROVED
- [ ] `systems-index.md` Player Controller: status → Approved, doc link added

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
