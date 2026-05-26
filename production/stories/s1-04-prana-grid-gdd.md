# Story S1-04: Design Prana Grid GDD

**Sprint**: 1
**Priority**: Must Have
**Status**: Blocked (on S1-03)
**Type**: Config/Data + UI + Logic
**Owner**: (unassigned)
**Estimate**: 3.0 days
**GDD**: `design/gdd/prana-grid.md` (to be created)

## Description

Author the Prana Grid GDD using `/design-system prana-grid`, paired with a ux-designer agent. The Prana Grid is the player's core interaction surface — a 3×3 drag-and-drop grid where Prana types are arranged before combat. This is the most design-intensive story this sprint (L effort).

**Known-hard requirement:** Gamepad Prana-selection UX must be specified concretely. Drag-and-drop is mouse-optimized; gamepad requires a different interaction model (d-pad/joystick slot navigation + confirm/cancel buttons). The GDD cannot be APPROVED without this.

**Pre-authoring check:** Verify Art Bible Section 5 (Prana-to-color mapping) is written before starting the session.

## Acceptance Criteria

- [ ] GDD file created at `design/gdd/prana-grid.md`
- [ ] All 8 required sections present
- [ ] Grid layout fully specified: 3×3 slot arrangement, slot dimensions, visual gap
- [ ] Drag-and-drop interaction defined for keyboard/mouse (primary)
- [ ] **Gamepad Prana-selection UX specified** — concrete and implementable; BLOCKING if absent or vague
- [ ] Prana Data integration: grid reads from `PranaCatalog.get_type()` by integer ID (no string comparisons)
- [ ] Center-slot communication defined: how does grid pass its state to Combination Resolution?
- [ ] Slot states defined: empty, filled (per type), highlighted (synergy glow), locked
- [ ] Colorblind mode: icon fallback display per art bible §4.5
- [ ] Dependencies: Prana Data (Approved), Game State & Scene Flow (Approved), Player Controller (S1-03)
- [ ] ACs include: all 5 types placeable in any slot; grid state readable by Combination Resolution; colorblind fallback renders
- [ ] `/design-review` returns APPROVED
- [ ] `systems-index.md` Prana Grid: status → Approved, doc link added

## QA Test Cases

> **Design sprint:** Verification is the `/design-review` verdict.
> Implementation tests will be authored when Prana Grid is implemented.

Verification checklist (from `production/qa/qa-plan-sprint-1-2026-05-26.md`):

- [ ] Art bible Section 5 confirmed written before session begins
- [ ] Gamepad UX is concrete (d-pad/joystick navigation + confirm/cancel) — not deferred
- [ ] Center-slot communication contract defined (what data shape is sent to Combination Resolution?)
- [ ] All 5 Prana types can be placed in any of the 9 slots — no hardcoded type restrictions
- [ ] Colorblind mode: 8×8 px icon renders per art bible §4.5
- [ ] At least one gameplay formula in ACs (e.g., maximum types in grid = 5, minimum = 0)
- [ ] `/design-review` APPROVED

## Test Evidence

> Fill in after completing:

- **Verdict**: ___
- **Session date**: ___
- **Commit SHA**: ___

## Dependencies

- **Blocked by**: S1-03 (Player Controller GDD) — do not start until Player Controller is APPROVED
- Prana Data GDD: `design/gdd/prana-data.md` (Approved)
- Game State & Scene Flow GDD: `design/gdd/game-state-scene-flow.md` (Approved)
- Art Bible Section 5: `design/art/art-bible.md` — must be written before session

## Cross-System Notes

- The grid's center-slot communication contract is load-bearing for S1-05 (Combination Resolution) — define it clearly here
- Colorblind icon requirement comes from art bible §4.5 — verify that section is written
- Drag-and-drop at resolution: Prana Grid does NOT instantiate AudioStreamPlayer nodes — all audio via `AudioSystem.play_event()`
