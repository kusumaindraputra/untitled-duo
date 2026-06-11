# Story 002: Mouse Drag-and-Drop Input + Confirm Validation

> **Epic**: Prana Grid
> **Status**: Ready
> **Layer**: Core
> **Type**: UI (Logic secondary)
> **Estimate**: 2.5 days (×2.5 adjusted — UI story with HIGH engine risk per ADR-0013)
> **Sprint ID**: S4-04
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-11

## Context

**GDD**: `design/gdd/prana-grid.md`
**Requirements**: `TR-PG-001`, `TR-PG-002`, `TR-PG-004`, `TR-PG-006`
- TR-PG-001: Dual-input support: mouse drag (primary); `_selected_slot_index` + overlay for gamepad (secondary); no hover-only interactions
- TR-PG-002: `committed_fragments: Array[PranaFragment]` length 9 (null = empty slot) — sole public data interface for CR and SCE
- TR-PG-004: Confirmation requires slot 4 (centre) non-null; `arrangement_confirmed` signal emitted; `is_loadout_valid()` returns false if slot 4 empty
- TR-PG-006: `is_loadout_valid() -> bool` — queried by GameStateManager before PREPARATION → COMBAT transition

**ADR Governing Implementation**: ADR-0013: PranaGrid Dual-Input Focus Model (primary), ADR-0003: Signal-Driven Architecture (secondary)
**ADR Decision Summary**: Mouse path uses Godot's built-in drag-and-drop API (`get_drag_data()`, `can_drop_data()`, `drop_data()`) on slot `Control` nodes with `MOUSE_FILTER_STOP`. `grab_focus()` is NEVER called from the mouse code path. `arrangement_confirmed` is emitted as a signal on valid confirmation — no direct method calls.

**Engine**: Godot 4.6 | **Risk**: HIGH — drag-and-drop focus behaviour in Godot 4.6 is post-LLM-cutoff; ADR-0013 verification prototype PASSED WITH CONCERN on 2026-06-05
**Engine Notes**:
- Slot nodes: `mouse_filter = MOUSE_FILTER_STOP`, `focus_mode = FOCUS_ALL`
- `_gui_input(event)` handles `InputEventMouseButton` for click-to-place and right-click-to-clear
- `mouse_entered` / `mouse_exited` drive hover highlight via `StyleBoxFlat` swap — no `grab_focus()` call
- Drag-and-drop uses `Control.get_drag_data()` / `drop_data()` / `can_drop_data()` built-in API
- PranaGrid root must be plain `Control` or `Panel` — never `Container` (ADR-0013)
- **Keyboard focus ring**: Slot `Panel`/`Control` nodes will NOT show a focus ring automatically. Must call `add_theme_stylebox_override("focus", ...)` explicitly at slot node setup.

**Control Manifest Rules (Core layer)**:
- Required: `_gui_input()` for slot click-to-place; `mouse_filter = MOUSE_FILTER_STOP` on slots (ADR-0013)
- Required: Input mode detection via `_input()` event type check — not polled in `_process()` (ADR-0013)
- Required: `_gamepad_cursor.mouse_filter = MOUSE_FILTER_IGNORE` (ADR-0013)
- Forbidden: Never call `grab_focus()` in mouse navigation code path (ADR-0013)
- Forbidden: Never use engine focus state as source of truth for mouse selection (ADR-0013)

---

## Acceptance Criteria

*From `design/gdd/prana-grid.md`, scoped to this story:*

### Drag-and-Drop Input (GDD Rules 5, 9)
- [ ] **AC-PG-06**: Drag token from Type Selector to empty slot → slot fills with correct `type_id`
- [ ] **AC-PG-06b**: Drag token to occupied slot → slot replaces the existing token; `committed_fragments[N].type_id` equals the new type after confirm
- [ ] Drag slot-to-slot swap: filled slot dragged to another filled slot → both slots update correctly
- [ ] Drag off-grid: filled slot token dragged off grid → slot becomes empty (null)
- [ ] **AC-PG-07**: Right-click filled slot → slot cleared to null

### Confirmation Rule (GDD Rules 6, 7; Formula 2)
- [ ] **AC-PG-03**: With slot 4 (centre) filled, Confirm triggered → `arrangement_confirmed` emitted exactly once; `committed_fragments` is Array[PranaFragment] of length 9; non-null elements have correct `type_id` (0–4) and `level = 1`; `committed_fragments[4]` is non-null
- [ ] **AC-PG-04**: Slot 4 empty (any other slots may be filled) → Confirm button is visually greyed out (40% opacity, non-interactive); clicking produces no signal, no state change
- [ ] **AC-PG-05**: Slot 4 empty + confirm key pressed → error indicator fires (grid border flash, "place a fragment in the centre slot" label); no `arrangement_confirmed` emitted; ARRANGEMENT state unchanged
- [ ] **AC-PG-08**: Clear All → all 9 slots null; Confirm button returns to disabled state
- [ ] `is_loadout_valid() -> bool` returns false when slot 4 is null; true when slot 4 is non-null

### committed_fragments Array (GDD Formula 2)
- [ ] `committed_fragments.size() == 9` always (length invariant)
- [ ] Empty slots are null — not -1, 0, or any sentinel other than null
- [ ] Fragment `level == 1` at First Playable scope; `stat_property == null`; `adjacency_effects == []`

### LOCKED visibility (GDD Rule 3, AC-PG-10, AC-PG-11, AC-PG-12)
- [ ] **AC-PG-10**: `committed_fragments` does not mutate during LOCKED state; subsequent reads return the confirmed arrangement unchanged
- [ ] **AC-PG-11**: Drag in progress when `grid_locked` fires → drag cancelled; no partial placement; committed array reflects pre-drag arrangement
- [ ] **AC-PG-12**: Grid display visible at 70% opacity during LOCKED state; committed tokens remain readable

### ADR-0013 Mouse Path Validation (manual gate — required before Done)
- [ ] **AC-0013-01b**: Mouse hover over a slot does NOT change `_selected_slot_index`
- [ ] **AC-0013-03**: `_gamepad_cursor.mouse_filter == MOUSE_FILTER_IGNORE`
- [ ] Mouse hover highlight uses `StyleBoxFlat` swap — no `grab_focus()` call in any mouse handler

---

## Implementation Notes

*Derived from ADR-0013 Implementation Guidelines + GDD Rules 5, 6, 9:*

**Slot node setup (per slot, in loop in `_ready()`):**
```gdscript
var slot := preload("res://src/ui/prana_grid_slot.tscn").instantiate()
slot.mouse_filter = Control.MOUSE_FILTER_STOP
slot.focus_mode = Control.FOCUS_ALL
# Keyboard focus ring — must be explicit in Godot 4.6 (will NOT appear automatically)
slot.add_theme_stylebox_override("focus", _focus_stylebox)
slot.mouse_entered.connect(_on_slot_hover_enter.bind(i))
slot.mouse_exited.connect(_on_slot_hover_exit.bind(i))
slot.focus_entered.connect(_on_slot_focus_entered.bind(i))
slot.focus_exited.connect(_on_slot_focus_exited.bind(i))
```

**Drag-and-drop API (slot Control nodes):**
```gdscript
# On Type Selector tokens:
func get_drag_data(_at_position: Vector2) -> Variant:
    return { "type_id": _type_id }  # payload

# On slot nodes:
func can_drop_data(_at_position: Vector2, data: Variant) -> bool:
    return typeof(data) == TYPE_DICTIONARY and data.has("type_id")

func drop_data(_at_position: Vector2, data: Variant) -> void:
    get_parent()._place_token(_slot_index, data["type_id"])
```

**Confirmation logic:**
```gdscript
func _on_confirm_pressed() -> void:
    if _slots[4] == null:
        _show_centre_error_indicator()
        return
    var fragments: Array[PranaFragment] = []
    fragments.resize(9)
    for i in 9:
        if _slots[i] != null:
            var f := PranaFragment.new()
            f.type_id = _slots[i]
            f.level = 1
            f.stat_property = null
            f.adjacency_effects = []
            fragments[i] = f
        else:
            fragments[i] = null
    _committed_fragments = fragments
    arrangement_confirmed.emit()

func is_loadout_valid() -> bool:
    return _slots[4] != null

var _committed_fragments: Array[PranaFragment] = []
func get committed_fragments() -> Array[PranaFragment]:
    return _committed_fragments  # read-only by convention — never write externally
```

**Error indicator (0.4s flash):**
```gdscript
var _error_flash_timer: float = 0.0
const ERROR_FLASH_DURATION := 0.4

func _show_centre_error_indicator() -> void:
    _error_flash_timer = ERROR_FLASH_DURATION
    _error_label.visible = true

func _process(delta: float) -> void:
    if _error_flash_timer > 0.0:
        _error_flash_timer -= delta
        if _error_flash_timer <= 0.0:
            _error_flash_timer = 0.0
            _error_label.visible = false
```

**LOCKED opacity:**
```gdscript
func _on_grid_locked() -> void:
    _state = State.LOCKED
    modulate.a = 0.7  # 70% opacity — committed arrangement remains readable
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: Phase state machine (ARRANGEMENT/LOCKED/HIDDEN transitions) — must be DONE before this story begins
- **Story 003**: Wiring `committed_fragments` getter to CombinationResolution/SpellCastingEffects
- **Story 004**: Gamepad d-pad navigation, `_selected_slot_index`, `_gamepad_cursor` overlay

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-4-2026-06-11.md` — § S4-04.*

**Automated test file**: `tests/unit/prana-grid/prana_grid_confirm_logic_test.gd`

- **committed_fragments length invariant**
  - Given: Any arrangement (all empty, partially filled, all filled)
  - When: Confirm triggered with slot 4 non-null
  - Then: `committed_fragments.size() == 9`; empty slots are `null` not -1

- **AC-PG-03** — arrangement_confirmed signal emitted exactly once
  - Given: slot 4 = Ashfire (type_id 0), other slots any state
  - When: Confirm triggered
  - Then: Signal spy receives exactly 1 emission; `committed_fragments[4].type_id == 0`; `committed_fragments[4].level == 1`

- **AC-PG-04/05** — centre-slot guard
  - Given: slot 4 is null; other slots may be filled (test both all-empty and ring-filled)
  - When: Confirm triggered (button click or Enter key)
  - Then: No `arrangement_confirmed` emitted; ARRANGEMENT state unchanged
  - Edge cases: All 9 slots filled except slot 4 → still rejected

- **AC-PG-06** — slot replace
  - Given: slot N contains Ashfire (type_id 0)
  - When: Voidblue (type_id 1) placed on slot N
  - Then: `_slots[N] == 1` (Voidblue); confirm → `committed_fragments[N].type_id == 1`

- **AC-PG-07** — slot clear
  - Given: slot N contains any token
  - When: Right-click (or clear action) on slot N
  - Then: `_slots[N] == null`; confirm → `committed_fragments[N] == null`

- **AC-PG-08** — Clear All
  - Given: Multiple slots filled
  - When: Clear All activated
  - Then: All 9 `_slots` are null; `is_loadout_valid() == false`

- **is_loadout_valid** — centre slot gate
  - Given: (a) slot 4 == null; (b) slot 4 == Deepfrost (type_id 3)
  - When: `is_loadout_valid()` called
  - Then: (a) false; (b) true

- **AC-PG-10** — committed_fragments immutability in LOCKED
  - Given: Grid confirmed and LOCKED; `_committed_fragments` captured
  - When: Multiple reads of `committed_fragments` during LOCKED state
  - Then: Each read returns same values; no element mutates

- **AC-PG-11** — drag cancelled on grid_locked
  - Given: Mouse drag in progress (token lifted from Type Selector)
  - When: `_on_grid_locked()` fires
  - Then: No partial placement; `_slots` reflect pre-drag state; `committed_fragments` unchanged

- **minimum valid arrangement** — centre only
  - Given: Only slot 4 filled (type_id = 2); slots 0–3, 5–8 all null
  - When: Confirm triggered
  - Then: `arrangement_confirmed` emits; `committed_fragments[4].type_id == 2`; `committed_fragments[0] == null` (and all non-centre slots)

- **First Playable fragment defaults**
  - Given: Any confirmed arrangement
  - When: `committed_fragments` inspected
  - Then: Each non-null element has `level == 1`, `stat_property == null`, `adjacency_effects == []`

**Manual verification file**: `production/qa/evidence/prana-grid-mouse-evidence.md`

Manual check: **AC-0013-01b** — mouse hover does not move gamepad cursor
  - Setup: Open game in Preparation Phase; observe `_selected_slot_index` via debugger/print
  - Verify: Move mouse over slots 0–8; `_selected_slot_index` value does not change
  - Pass condition: `_selected_slot_index` unchanged throughout mouse hover sequence

Manual check: **AC-PG-12** — LOCKED grid visible at 70% opacity
  - Setup: Confirm an arrangement; game enters Combat Phase (LOCKED state)
  - Verify: Grid panel visible; slot tokens show their type colors/icons; grid `modulate.a == 0.7`
  - Pass condition: Arrangement readable on screen during active combat wave

Manual check: **ADR-0013 mouse path validation** — see full checklist in `production/qa/qa-plan-sprint-4-2026-06-11.md`

---

## Test Evidence

**Story Type**: UI (Logic secondary)
**Required evidence**:
- Automated: `tests/unit/prana-grid/prana_grid_confirm_logic_test.gd` — must exist and pass
- Manual: `production/qa/evidence/prana-grid-mouse-evidence.md` — ADR-0013 mouse path sign-off required

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (phase gating state machine must be DONE — this story adds input to an existing ARRANGEMENT state)
- Unlocks: Story 003 (integration wires committed_fragments to CR/SCE — needs the getter from this story)
