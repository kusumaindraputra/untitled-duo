# ADR-0013 Gamepad Path — Manual Evidence
**Story**: S6-05 — PranaGrid Gamepad Input
**Tester**: [name]
**Date**: [date]
**Build**: [commit hash]

## ADR-0013 Mandatory Checks (all 6 required before Done)

- [ ] **AC-0013-01a** — D-pad press moves `_gamepad_cursor` to correct slot position
  - Result: 
- [ ] **AC-0013-01c** — Tab key does NOT move `_gamepad_cursor`
  - Result: 
- [ ] **AC-0013-02 / AC-PG-09** — Full gamepad-only cycle completable (all 9 slots, 5 types, Place + Clear + Confirm)
  - Result: 
- [ ] **AC-0013-04** — `grep -n "grab_focus" src/ui/prana_grid.gd` returns zero matches in gamepad handlers
  - Result: 
- [ ] **AC-0013-03** — `_gamepad_cursor.mouse_filter == Control.MOUSE_FILTER_IGNORE`
  - Result: 
- [ ] **AC-0013-05** — Wrap: slot 2 RIGHT → slot 0; slot 2 DOWN → slot 5
  - Result: 

## Full Interaction Flow Checks

- [ ] All 9 slots reachable; LEFT/RIGHT = columns; UP/DOWN = rows
- [ ] Type Cycle: 0→4→0 wraps; Type Indicator updates color + name each cycle
- [ ] Place: fills `_selected_slot_index` with current type; token visible
- [ ] Place on occupied slot: replaces cleanly — no crash, no duplicate
- [ ] Clear: removes token; slot returns to empty state
- [ ] Confirm with slot 4 empty: error indicator shown
- [ ] Confirm with slot 4 filled: `arrangement_confirmed` fires; transitions to LOCKED
- [ ] Switch gamepad → mouse (move mouse): `_gamepad_cursor` hides; mouse hover works
- [ ] Switch mouse → gamepad (d-pad): cursor reappears at `_selected_slot_index`; no interference

## Verdict

[ ] PASS — all ADR-0013 mandatory checks pass; all interaction flow checks pass
[ ] FAIL — one or more checks failed (describe below)

**Notes**:
