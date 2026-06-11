# QA Evidence: PranaGrid — Mouse Input & Confirm (Story 002)

**Date**: [fill in when verified]
**Story**: production/epics/prana-grid/story-002-mouse-input-confirm.md
**Sprint**: S4-04
**Tester**: Kusuma Putra
**Sign-off gate**: ADVISORY — does not block automated CI, but required before Story 002 can be marked fully Done

---

## AC-0013-01b: Mouse hover does NOT change `_selected_slot_index`

- **Setup**: Open game in Preparation Phase; attach debugger or add `print(_selected_slot_index)` to `_input()`.
- **Verify**: Move mouse over all 9 slots (0–8). `_selected_slot_index` value does not change on any hover event.
- **Pass condition**: `_selected_slot_index` is unchanged throughout the full mouse hover sequence.
- **Result**: [ ] PASS / [ ] FAIL
- **Notes**: 

---

## AC-0013-03: `_gamepad_cursor.mouse_filter == MOUSE_FILTER_IGNORE`

- **Setup**: Open game; inspect GamepadCursor node in scene tree (or print `_gamepad_cursor.mouse_filter`).
- **Verify**: Value equals `MOUSE_FILTER_IGNORE` (2).
- **Pass condition**: GamepadCursor does not intercept any mouse hover events on slot nodes beneath it.
- **Result**: [ ] PASS / [ ] FAIL — *(Note: GamepadCursor node wired in Story 004; verify then)*
- **Notes**: 

---

## AC-PG-12: LOCKED grid visible at 70% opacity

- **Setup**: Confirm a valid arrangement (slot 4 non-null); let the game progress to Combat Phase (LOCKED state).
- **Verify**: Grid panel is visible; slot tokens show their type colors/icons; `modulate.a` reads 0.7.
- **Pass condition**: Committed arrangement is readable on screen during the active combat wave.
- **Result**: [ ] PASS / [ ] FAIL
- **Notes**: 

---

## Manual: Drag-and-Drop Path (GDD Rules 5, 9)

*These cannot be tested headlessly — requires live Godot scene tree with drag events.*

### AC-PG-06: Drag to empty slot
- Drag a Type Selector token onto an empty grid slot → slot fills with correct `type_id`.
- **Result**: [ ] PASS / [ ] FAIL

### AC-PG-06b: Drag to occupied slot (replace)
- Drag a token onto a slot that already has a token → slot updates to the new type.
- **Result**: [ ] PASS / [ ] FAIL

### Slot-to-slot swap
- Drag a token from one filled slot to another filled slot → both update correctly.
- **Result**: [ ] PASS / [ ] FAIL

### Drag off-grid
- Drag a token from a filled slot and release outside the grid → slot becomes empty (null).
- **Result**: [ ] PASS / [ ] FAIL

### AC-PG-07: Right-click clear
- Right-click a filled slot → slot clears to null.
- **Result**: [ ] PASS / [ ] FAIL

---

## Manual: Error Flash Indicator (AC-PG-05)

- Click Confirm with slot 4 empty → error label/border appears briefly (~0.4s) then hides.
- **Result**: [ ] PASS / [ ] FAIL
- **Notes**: 

---

## Manual: Confirm Button Disabled State (AC-PG-04)

- With slot 4 empty → Confirm button visually greyed out (40% opacity, non-interactive).
- **Result**: [ ] PASS / [ ] FAIL — *(Note: button styling wired in scene; verify with scene setup)*
- **Notes**: 

---

*Story 002 automated tests (prana_grid_confirm_logic_test.gd) cover the confirm logic, state guards,*
*and committed_fragments array. This file covers the visual/drag-and-drop criteria that require a live scene.*
