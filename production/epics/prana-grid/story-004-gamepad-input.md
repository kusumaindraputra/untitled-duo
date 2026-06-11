# Story 004: PranaGrid Gamepad Input (ADR-0013 HIGH Risk Path)

> **Epic**: Prana Grid
> **Status**: Ready
> **Layer**: Core
> **Type**: UI
> **Estimate**: 2.5 days (ADR-0013 HIGH risk — independent validation required from mouse path)
> **Sprint ID**: S4-07
> **Manifest Version**: 2026-06-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/prana-grid.md`
**Requirements**: `TR-PG-001` (gamepad path specifically)
- TR-PG-001: Dual-input support — gamepad d-pad cursor (secondary path); `_selected_slot_index: int` + `_gamepad_cursor: Control` overlay; no hover-only interactions; `grab_focus()` NEVER called from gamepad code path

**ADR Governing Implementation**: ADR-0013: PranaGrid Dual-Input Focus Model
**ADR Decision Summary**: Gamepad path uses `_selected_slot_index: int` (PranaGrid state var) + a `_gamepad_cursor: Control` overlay child node repositioned on index change. `grab_focus()` is NEVER called from gamepad code. D-pad navigation wraps as a 3×3 torus. Input mode detected via `_input()` event type — not polled in `_process()`.

**Engine**: Godot 4.6 | **Risk**: HIGH — post-LLM-cutoff; dual-focus system changed in Godot 4.6; ADR-0013 prototype PASSED WITH CONCERN on 2026-06-05
**Engine Notes**:
- `grab_focus()` in Godot 4.6 affects keyboard/gamepad focus ONLY — does not affect mouse hover
- `_gamepad_cursor` must have `mouse_filter = MOUSE_FILTER_IGNORE` — prevents overlay intercepting mouse events on slots below
- `_gamepad_cursor` anchors must all be `0.0` — non-zero anchors offset `global_position` assignments
- PranaGrid root: plain `Control` or `Panel` — Container subclass layout pass would override `_gamepad_cursor.global_position`
- Initialize `_gamepad_cursor` position in `_ready()` after `await get_tree().process_frame` to guarantee layout completion
- Three-path model (ADR-0013 Decision): mouse / gamepad d-pad / keyboard accessibility operate independently with no cross-interference

**Control Manifest Rules (Core layer)**:
- Required: `_selected_slot_index: int` + `_gamepad_cursor: Control` overlay for gamepad navigation (ADR-0013)
- Required: Input mode detection via `_input()` event type check — not polled in `_process()` (ADR-0013)
- Required: `_gamepad_cursor.mouse_filter = MOUSE_FILTER_IGNORE` (ADR-0013)
- Required: Gamepad d-pad navigation wraps as 3×3 torus (ADR-0013)
- Required: Initialize `_gamepad_cursor` position in `_ready()` after `await get_tree().process_frame` (ADR-0013)
- Forbidden: Never call `grab_focus()` in gamepad navigation code paths (ADR-0013)
- Forbidden: Never use engine focus state as source of truth for which slot gamepad selected (ADR-0013)
- Forbidden: Never poll `Input.is_action_pressed()` in `_process()` for input mode detection (ADR-0013)

---

## Acceptance Criteria

*From `design/gdd/prana-grid.md`, scoped to this story:*

- [ ] **AC-PG-09**: Full gamepad-only cycle completable with no mouse input — navigate all 9 slots, cycle through all 5 Prana types, place a token, clear a token, and confirm
- [ ] D-pad LEFT/RIGHT navigates columns; d-pad UP/DOWN navigates rows; wraps as 3×3 torus
- [ ] **AC-0013-05** — Wrap correctness: right from slot 2 (top-right) → slot 0 (top-left, same row); down from slot 2 → slot 5 (middle-right)
- [ ] `_gamepad_cursor` overlay visible when last input was joypad; hidden when last input was mouse or keyboard
- [ ] `_gamepad_cursor` repositions to selected slot on each d-pad press; renders above slot nodes with white/gold border highlight
- [ ] Type Cycle control cycles through all 5 Prana types (0–4); Type Indicator shows current type (color + icon)
- [ ] Place action: fills `_selected_slot_index` slot with the currently cycled Prana type
- [ ] Place on occupied slot: replaces the token (no crash, no duplicate)
- [ ] Clear action: clears the token at `_selected_slot_index` slot
- [ ] Gamepad Confirm: accepted when slot 4 is filled; rejected with error indicator when slot 4 is empty (same logic as mouse confirm — GDD Rules 5, 6)
- [ ] Switch from gamepad to mouse: `_gamepad_cursor` hides; mouse hover highlight appears on hover (AC-0013-01d)
- [ ] Switch from mouse to gamepad: `_gamepad_cursor` reappears at current `_selected_slot_index`; mouse hover state doesn't interfere

### ADR-0013 Gamepad Path Validation (manual gate — required before Done)
- [ ] **AC-0013-01a**: D-pad moves `_gamepad_cursor` overlay to the correct slot position
- [ ] **AC-0013-01c**: Tab key focus does NOT move the gamepad overlay
- [ ] **AC-0013-02**: Full gamepad-only cycle completable (AC-PG-09)
- [ ] **AC-0013-04**: `grep -n "grab_focus" src/ui/prana_grid.gd` returns zero matches in any gamepad handler
- [ ] **AC-0013-03**: `_gamepad_cursor.mouse_filter == MOUSE_FILTER_IGNORE` (verified programmatically or in editor)

---

## Implementation Notes

*Derived from ADR-0013 Decision section — gamepad path:*

**Cursor state variables** (declare alongside mouse-path state from Story 002):
```gdscript
var _selected_slot_index: int = 4      # Default: centre slot
var _cursor_visible: bool = false
@onready var _gamepad_cursor: Control = %GamepadCursor  # Overlay child
```

**Cursor setup in _ready() (after await process_frame):**
```gdscript
func _ready() -> void:
    # ... existing setup ...
    await get_tree().process_frame  # guarantee layout before first positioning
    _gamepad_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
    # Anchors must all be 0.0 — verify in editor, not set in code
    _move_cursor_to(_selected_slot_index)
    _gamepad_cursor.visible = false
```

**Input mode detection (event-driven — never polled):**
```gdscript
func _input(event: InputEvent) -> void:
    if event is InputEventJoypadButton or event is InputEventJoypadMotion:
        _cursor_visible = true
        _gamepad_cursor.visible = true
    elif event is InputEventMouseButton or event is InputEventMouseMotion:
        _cursor_visible = false
        _gamepad_cursor.visible = false
```

**Gamepad cursor navigation (3×3 torus wrap — from ADR-0013):**
```gdscript
func _navigate_gamepad(direction: Vector2i) -> void:
    var row: int = _selected_slot_index / 3
    var col: int = _selected_slot_index % 3
    row = (row + direction.y + 3) % 3
    col = (col + direction.x + 3) % 3
    _selected_slot_index = row * 3 + col
    _move_cursor_to(_selected_slot_index)

func _move_cursor_to(index: int) -> void:
    var slot_node: Control = _slot_nodes[index]
    _gamepad_cursor.global_position = slot_node.global_position
    _gamepad_cursor.size = slot_node.size
```

**D-pad input in `_input()` (separate from mode detection):**
```gdscript
# Append to existing _input() handler:
if _cursor_visible and _state == State.ARRANGEMENT:
    if event.is_action_pressed(&"ui_left"):   _navigate_gamepad(Vector2i(-1, 0))
    if event.is_action_pressed(&"ui_right"):  _navigate_gamepad(Vector2i(1, 0))
    if event.is_action_pressed(&"ui_up"):     _navigate_gamepad(Vector2i(0, -1))
    if event.is_action_pressed(&"ui_down"):   _navigate_gamepad(Vector2i(0, 1))
    if event.is_action_pressed(&"prana_place"):  _gamepad_place()
    if event.is_action_pressed(&"prana_clear"):  _gamepad_clear()
    if event.is_action_pressed(&"prana_confirm"): _on_confirm_pressed()  # shared with mouse
```

**FORBIDDEN patterns** (from ADR-0013 — code review will check these):
```gdscript
# NEVER do this:
_slot_nodes[_selected_slot_index].grab_focus()  # FORBIDDEN
get_viewport().gui_get_focus_owner()             # FORBIDDEN for gamepad logic
if Input.is_action_pressed(&"ui_right"):         # FORBIDDEN — use _input() dispatch
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: Phase state machine (prerequisite — must be DONE)
- **Story 002**: Mouse drag-and-drop, confirmation logic, committed_fragments (prerequisite — must be DONE for _on_confirm_pressed to exist)
- **Story 003**: CR/SCE integration — independent from gamepad path

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-4-2026-06-11.md` — § S4-07.*

**No automated tests for this story** — gamepad input behaviour is physics/input-dependent and not testable headless. All verification is manual.

**Manual evidence file**: `production/qa/evidence/prana-grid-gamepad-adr0013.md`

Manual check: **AC-0013-05** — 3×3 torus wrap correctness
  - Setup: Launch game in Preparation Phase; gamepad connected; observe `_selected_slot_index` via print/debugger
  - Verify: (a) From slot 2, press d-pad RIGHT → `_selected_slot_index == 0`; (b) From slot 2, press d-pad DOWN → `_selected_slot_index == 5`
  - Pass condition: Both wraps correct; no out-of-bounds or stuck navigation

Manual check: **AC-PG-09** — full gamepad-only cycle
  - Setup: Start preparation phase; unplug or ignore mouse; use only gamepad
  - Verify: Navigate to slot 0, 4, 8 (corners + centre); cycle type to each of 5 types; Place in slot 4; Clear; Place again; press Confirm
  - Pass condition: `arrangement_confirmed` fires; no mouse input used at any point

Manual check: **cursor overlay independence**
  - Setup: Start with gamepad input; switch to mouse mid-arrangement (move mouse)
  - Verify: `_gamepad_cursor` hides on mouse movement; mouse hover highlight appears; `_selected_slot_index` preserved at last d-pad position; switch back to gamepad — cursor reappears at correct position
  - Pass condition: No crash; tokens not lost; both input modes work after switch

Manual check: **AC-0013-04** — no grab_focus in gamepad handlers
  - Setup: After implementation, run from terminal
  - Verify: `grep -n "grab_focus" src/ui/prana_grid.gd`
  - Pass condition: Zero matches in any joypad handler function

Manual check: **AC-0013-03** — mouse_filter on cursor overlay
  - Setup: Open prana_grid.gd or run a test that reads the property
  - Verify: `_gamepad_cursor.mouse_filter == Control.MOUSE_FILTER_IGNORE`
  - Pass condition: Property confirmed; clicking slots through the overlay works correctly

Manual check: **AC-0013-01c** — Tab key does not move gamepad overlay
  - Setup: Switch to gamepad input; cursor visible at slot 4; press Tab key
  - Verify: Engine keyboard focus moves to a different slot; `_gamepad_cursor` overlay stays at slot 4
  - Pass condition: Overlay does not move; gamepad cursor and keyboard focus are independent

---

## Test Evidence

**Story Type**: UI
**Required evidence**: `production/qa/evidence/prana-grid-gamepad-adr0013.md` — ADR-0013 gamepad path sign-off required

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (phase gating — ARRANGEMENT state + slot index formula), Story 002 (confirm logic — `_on_confirm_pressed()` shared with gamepad Confirm)
- Unlocks: None — this is the final PranaGrid implementation story (Should Have)
