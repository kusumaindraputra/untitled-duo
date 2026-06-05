# ADR-0013: PranaGrid Dual-Input Focus Model (Godot 4.6)

## Status
Accepted

## Date
2026-05-30

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Input / UI |
| **Knowledge Risk** | HIGH — Dual-focus system changed in Godot 4.6 (post-LLM-cutoff). `grab_focus()` now affects keyboard/gamepad focus ONLY; mouse hover focus is a separate system. This change is the primary motivation for this ADR. |
| **References Consulted** | `docs/engine-reference/godot/modules/input.md`, `docs/engine-reference/godot/modules/ui.md`, `docs/engine-reference/godot/breaking-changes.md` |
| **Post-Cutoff APIs Used** | Godot 4.6 dual-focus separation — confirmed in engine-reference docs. `Control.mouse_entered` / `mouse_exited` / `_gui_input()` — confirmed stable. `Control.focus_mode` — confirmed stable. `MOUSE_FILTER_IGNORE` / `MOUSE_FILTER_STOP` — confirmed stable. |
| **Verification Required** | **BLOCKING before PranaGrid sprint**: Create a minimal scene with a 3×3 grid of `Control` nodes + a single overlay child. Verify: (1) d-pad navigation updates `_selected_slot_index` and moves the overlay correctly; (2) mouse hover on a slot does not change `_selected_slot_index`; (3) `grab_focus()` on a slot (via Tab key) does not move the overlay; (4) switching from gamepad input to mouse input hides the overlay without affecting mouse hover state. All four must pass before authoring PranaGrid gameplay logic. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (Signal-Driven Architecture — PranaGrid emits signals, never polls state; this input model must not poll `Input.get_last_input_event_type()` on every frame) |
| **Enables** | PranaGrid implementation sprint — this is the blocking implementation pattern |
| **Blocks** | Epic: PranaGrid — no PranaGrid `.gd` file may be written before this ADR is Accepted and the Verification Required test is completed |
| **Ordering Note** | The throwaway verification scene must be built and confirmed before the main `prana_grid.gd` is authored. Authoring without verification risks rewriting the entire input layer if the pattern proves wrong in-engine. |

## Context

### Problem Statement

PranaGrid requires two simultaneous input models: mouse drag (primary) and gamepad d-pad cursor (secondary). Godot 4.6 separates focus into two independent systems: `grab_focus()` affects keyboard/gamepad focus only, while mouse hover is tracked separately. A naive implementation that uses `grab_focus()` for the gamepad cursor creates three problems: (1) the gamepad cursor and keyboard accessibility navigation share the same focus pool — pressing Tab and pressing d-pad both move "focus" on the same `Control` nodes, making independent visual styling impossible; (2) the mouse hover state and keyboard/gamepad focus state can both be active on different controls simultaneously, producing confusing double-highlight states; (3) the engine's focus theme styles (draw_stylebox for focused state) were not designed to serve as a gameplay cursor — they are accessibility indicators and should be treated as such.

### Constraints

- Godot 4.6: `grab_focus()` affects keyboard/gamepad focus only — does not affect mouse hover tracking
- `technical-preferences.md`: "All UI must be fully navigable via keyboard" — keyboard Tab/arrow accessibility is mandatory
- `technical-preferences.md`: "No hover-only interactions" — all gamepad actions must be completable without mouse
- PranaGrid GDD: gamepad cursor must render a "bright white/gold border highlight and slight scale-up (1.05×)" — distinct from the engine's default focus theme style
- PranaGrid GDD (Accessibility): "All grid slots must be reachable via keyboard navigation (Tab / arrow key traversal) in addition to mouse drag"
- ADR-0003: No polling in `_process()` — input mode detection must be event-driven

### Requirements

- Mouse and gamepad paths must be independently styled and non-interfering
- Keyboard Tab/arrow accessibility navigation must work alongside both mouse and gamepad
- d-pad input must navigate all 9 slots with wrapping (3×3 torus — right wraps to next row's left; no dead ends)
- The gamepad cursor overlay must be invisible when the player is using mouse and visible when using gamepad
- No system other than PranaGrid may own `_selected_slot_index` state
- `grab_focus()` must NEVER be called from the gamepad input code path

## Decision

PranaGrid implements a **three-path input model** where mouse, gamepad, and keyboard accessibility operate independently and without cross-interference.

### Three-Path Model Overview

```
Input Device       Tracking Mechanism          Visual Renderer              grab_focus()?
────────────────────────────────────────────────────────────────────────────────────────
Mouse              mouse_entered/exited on     Slot StyleBox hover          No — never
                   each slot Control           highlight (built-in theme)
                   _gui_input() for clicks
                   and drags

Gamepad (d-pad)    _selected_slot_index: int   _gamepad_cursor: Control     No — never
                   (PranaGrid state var)        overlay child node
                   Updated on joypad input      repositioned on index change

Keyboard (Tab)     Engine focus system          Slot Control focus theme     Yes — engine
                   (Tab/arrow traversal)        style (accessibility only)   handles this
                   _on_slot_focus_entered()
                   callback updates visual
```

### Gamepad Cursor

```gdscript
var _selected_slot_index: int = 4      # Default: centre slot
var _cursor_visible: bool = false       # Only true when last input was joypad
@onready var _gamepad_cursor: Control = %GamepadCursor   # Overlay child

func _input(event: InputEvent) -> void:
    if event is InputEventJoypadButton or event is InputEventJoypadMotion:
        _cursor_visible = true
        _gamepad_cursor.visible = true
    elif event is InputEventMouseButton or event is InputEventMouseMotion:
        _cursor_visible = false
        _gamepad_cursor.visible = false
```

`_gamepad_cursor` is a `Control` child of the grid root with:
- `mouse_filter = MOUSE_FILTER_IGNORE` — must not intercept mouse events meant for slot nodes
- `z_index` above slot nodes — renders on top of the slot content
- Styled to match the GDD visual spec: bright white/gold border, 1.05× scale via `custom_minimum_size` matched to slot size

On `_selected_slot_index` change, reposition `_gamepad_cursor` by reading the selected slot node's `global_position` and `size`:

```gdscript
func _move_cursor_to(index: int) -> void:
    var slot_node: Control = _slots[index]
    _gamepad_cursor.global_position = slot_node.global_position
    _gamepad_cursor.size = slot_node.size
```

### Gamepad D-Pad Navigation

Navigation wraps within the 3×3 grid using row/column arithmetic from PranaGrid GDD Formula 1 (`slot_index = row × 3 + col`):

```gdscript
func _navigate_gamepad(direction: Vector2i) -> void:
    var row: int = _selected_slot_index / 3
    var col: int = _selected_slot_index % 3
    row = (row + direction.y + 3) % 3
    col = (col + direction.x + 3) % 3
    _selected_slot_index = row * 3 + col
    _move_cursor_to(_selected_slot_index)
```

Wrapping is a 3×3 torus: right from column 2 wraps to column 0 of the same row; down from row 2 wraps to row 0 of the same column. This ensures every slot is reachable with no dead ends.

Place, Clear, and Confirm actions in gamepad mode operate on `_selected_slot_index` — they never use the engine focus state.

### Mouse Path

Each of the 9 slot nodes is a `Control` with:
- `mouse_filter = MOUSE_FILTER_STOP` — intercepts mouse events
- `focus_mode = FOCUS_ALL` — enables Tab/arrow keyboard accessibility
- `_gui_input(event)` handles `InputEventMouseButton` for click-to-place and right-click-to-clear
- `mouse_entered` / `mouse_exited` signals drive the hover highlight (built-in `StyleBoxFlat` swap via theme override — no `grab_focus()` call)

Drag-and-drop from the Type Selector panel uses Godot's built-in `Control.get_drag_data()` / `drop_data()` / `can_drop_data()` API on the slot nodes.

### Keyboard Accessibility Path

Slot `Control` nodes have `focus_mode = FOCUS_ALL`. Tab and arrow key navigation is handled entirely by Godot's built-in focus engine — no custom navigation code needed. `focus_entered` and `focus_exited` signals connect to a visual highlight handler that shows/hides a thin accessibility border (distinct from the gamepad overlay's gold border).

`grab_focus()` is called by the engine on Tab/arrow key presses — this is acceptable and expected for accessibility. It is NOT called by any gamepad or mouse code path.

### Forbidden Patterns

```gdscript
# FORBIDDEN: grab_focus() in the gamepad navigation code path
func _on_dpad_right() -> void:
    _slots[_selected_slot_index + 1].grab_focus()  # FORBIDDEN

# FORBIDDEN: Using the engine focus state as the source of truth for which
# slot is "selected" by the gamepad
var selected_slot = get_viewport().gui_get_focus_owner()  # FORBIDDEN for gamepad logic

# FORBIDDEN: Polling last input event type every frame
func _process(delta: float) -> void:
    if Input.is_action_pressed(&"ui_right"):   # FORBIDDEN — use _input() event dispatch
        _navigate_gamepad(Vector2i(1, 0))
```

### Architecture Summary

```
PranaGrid (Control)
├── SlotNode[0..8] (Control × 9)
│     focus_mode = FOCUS_ALL
│     mouse_filter = MOUSE_FILTER_STOP
│     Signals: mouse_entered, mouse_exited, focus_entered, focus_exited
│     Method: _gui_input(), get_drag_data(), can_drop_data(), drop_data()
│
└── GamepadCursor (Control × 1)
      mouse_filter = MOUSE_FILTER_IGNORE
      z_index = above slots
      visible = _cursor_visible
      Repositioned on each _selected_slot_index change
```

State owned by PranaGrid:
- `_selected_slot_index: int` — gamepad cursor position (0–8)
- `_cursor_visible: bool` — gamepad overlay visibility (event-driven, not polled)

## Alternatives Considered

### Alternative B: `grab_focus()` for Gamepad Cursor

- **Description**: Map `_selected_slot_index` changes directly to `slot_nodes[index].grab_focus()`. The engine's focus theme provides the cursor highlight. d-pad input calls `grab_focus()` on the target slot.
- **Pros**: Less custom code — reuses the engine's existing focus traversal and styling
- **Cons**: In Godot 4.6, keyboard/gamepad focus and mouse hover are independent systems but share the same `FOCUS_ALL` focus pool. A Tab keypress and a d-pad press would both call `grab_focus()` on slots — they're indistinguishable at the engine level. This makes it impossible to show "accessibility focus" (thin border) and "gamepad cursor" (gold border + scale) as distinct visual states simultaneously. Also: the engine's default focus theme style (`StyleBoxFlat` with theme focus state) is designed for accessibility, not a gameplay cursor — making it look "right" for gameplay purposes requires theming every slot's focus state, which fights the engine's accessibility intent.
- **Rejection Reason**: Architecture review engine specialist confirmed HIGH RISK in Godot 4.6. Cannot independently style gamepad cursor vs. keyboard accessibility focus using a shared `grab_focus()` approach. Produces ambiguous visual states when the user switches between keyboard Tab and d-pad navigation.

### Alternative C: Shared `_selected_slot_index` Cursor for Both Gamepad and Keyboard

- **Description**: Extend the `_selected_slot_index` + overlay approach to also handle keyboard arrow key navigation, bypassing the engine's Tab focus system entirely. No `grab_focus()` anywhere. Keyboard arrow keys update `_selected_slot_index` directly; Tab key cycles through slots via the same index variable.
- **Pros**: One unified cursor for both gamepad and keyboard; no split between engine focus and custom state; simpler rendering (one overlay handles both)
- **Cons**: Breaks engine-native Tab key accessibility — Godot's accessibility tooling (screen readers via AccessKit, introduced in 4.5) relies on the engine's focus system. Bypassing `grab_focus()` entirely for keyboard input means the grid is invisible to assistive technology. `technical-preferences.md` requires all UI to be navigable via keyboard; accessibility compliance means using the engine's focus system for keyboard navigation.
- **Rejection Reason**: Non-compliant with accessibility requirements. Loses screen reader support (AccessKit, Godot 4.5+). Rejected in favour of the three-path model which keeps the engine's focus system for keyboard accessibility while using the custom overlay for gamepad.

## Consequences

### Positive

- Mouse and gamepad visual states can be independently styled (hover highlight ≠ gamepad cursor ≠ keyboard accessibility border)
- Keyboard Tab/arrow accessibility works via the engine's built-in focus system — compatible with screen readers (AccessKit, Godot 4.5+)
- `_selected_slot_index` is plain GDScript state — trivially testable without simulating focus events
- The gamepad overlay is a single repositioned `Control` node — no per-slot state; cheap to update
- Event-driven mode detection (`_cursor_visible` flip in `_input()`) avoids per-frame polling

### Negative

- Three distinct input paths mean three distinct code paths to test and maintain
- The `_input()` handler for mode detection fires on every input event — must be kept O(1) with no heavy processing
- `_move_cursor_to()` reads `global_position` on the slot node — requires the slot nodes to be laid out in the scene tree before the first d-pad event (safe in `_ready()` context, but must be deferred if called before first frame)

### Risks

- **Risk**: Developer adds a `grab_focus()` call in a d-pad handler ("just to make it look right"), re-introducing the dual-focus ambiguity.
  **Mitigation**: This ADR's Forbidden Patterns section is explicit. Code review checklist: grep for `grab_focus()` in `prana_grid.gd` on every PR; any call in a joypad handler is a blocking review finding.
- **Risk**: Verification Required step is skipped; the input model is authored without confirming the overlay approach works in a real Godot 4.6 project.
  **Mitigation**: Blocks column in ADR Dependencies is explicit. AC-0013-01 is a mandatory pre-sprint gate.
- **Risk**: `_move_cursor_to()` reads stale `global_position` if the grid layout hasn't been computed when the first d-pad event fires.
  **Mitigation**: Initialize `_gamepad_cursor` position in `_ready()` after `await get_tree().process_frame` to guarantee layout completion before first positioning.
- **Risk**: `PranaGrid` root node is a Container subclass (`GridContainer`, `VBoxContainer`, etc.) — the container's layout pass will override `_gamepad_cursor.global_position` on every layout reflow, silently undoing cursor repositioning.
  **Mitigation**: `PranaGrid` must be a plain `Control` or `Panel` — never a Container subclass. The slot nodes are positioned manually or via a non-container layout. Verified at scene creation.
- **Risk**: `GamepadCursor` overlay has non-zero anchors (e.g., accidentally set to `ANCHOR_CENTER` in the editor) — `global_position` assignments will be offset by the anchor calculation, producing incorrect cursor placement.
  **Mitigation**: `GamepadCursor` anchors must all be `0.0` (top-left anchor, default for a plain `Control`). Verified in AC-0013-01.
- **Risk**: Gamepad cursor overlay intercepts mouse hover events on the slot beneath it (if `mouse_filter` is not set correctly).
  **Mitigation**: `_gamepad_cursor.mouse_filter = MOUSE_FILTER_IGNORE` is a hard requirement. AC-0013-03 verifies this.

## GDD Requirements Addressed

| GDD System | TR ID | Requirement | How This ADR Addresses It |
|------------|-------|-------------|--------------------------|
| prana-grid.md | TR-PG-001 | Dual-input support: mouse drag (primary) + gamepad d-pad cursor (secondary); no hover-only interactions; Godot 4.6 dual-focus requires custom `_selected_slot_index` + overlay cursor, NOT `grab_focus()` | Decision: three-path model; `_selected_slot_index` + `_gamepad_cursor` overlay for gamepad; `mouse_entered`/`_gui_input()` for mouse; engine focus for keyboard accessibility |

## Performance Implications

- **CPU**: `_input()` handler — O(1) type check per event; negligible. `_move_cursor_to()` — two property reads + two property writes per d-pad press; negligible.
- **Memory**: One additional `Control` node (`_gamepad_cursor` overlay) — negligible.
- **Load Time**: None.
- **Rendering**: `_gamepad_cursor` reposition triggers one layout recalculation per d-pad press — acceptable for a UI element updated at human input frequency (~10 Hz at most).

## Validation Criteria

1. **AC-0013-01** (BLOCKING pre-sprint gate): Throwaway verification scene confirms four behaviours: (a) d-pad navigation moves `_gamepad_cursor` overlay to the correct slot position; (b) mouse hover does NOT change `_selected_slot_index`; (c) Tab key focus does NOT move the overlay; (d) switching from gamepad to mouse input hides the overlay and does not affect mouse hover state. Also verify: `GamepadCursor` anchors are all `0.0` (inspect in Godot editor — any non-zero anchor value will produce incorrect cursor positioning despite correct `global_position` assignment).
2. **AC-0013-02**: AC-PG-09 (GDD) — gamepad full-cycle completable: navigate all 9 slots, cycle types, place, clear, confirm — no mouse required. Verified by functional test.
3. **AC-0013-03**: Gamepad cursor overlay (`_gamepad_cursor`) has `mouse_filter = MOUSE_FILTER_IGNORE`. Verified by reading the property in a unit test or scene inspection.
4. **AC-0013-04**: `grep -n "grab_focus" prana_grid.gd` returns zero matches in any gamepad input handler (`_on_dpad_*`, `_navigate_gamepad`, `_on_joypad_*`). Keyboard accessibility `focus_entered` / `focus_exited` handlers may exist but must not call `grab_focus()` themselves.
5. **AC-0013-05**: `_selected_slot_index` wraps correctly at boundaries: from slot 2 (top-right) → right → slot 0 (top-left); from slot 2 → down → slot 5 (middle-right). Unit test verifies both wrap cases.

## Verification Result

| Field | Value |
|-------|-------|
| **Date** | 2026-06-05 |
| **Verdict** | PASSED WITH CONCERN |
| **Prototype** | `prototypes/adr-0013-verification/DualInputVerify.tscn` |

### AC Results

| AC | Description | Result |
|----|-------------|--------|
| AC-0013-01a | d-pad navigation moves overlay to correct slot | PASS |
| AC-0013-01b | Mouse hover does NOT change `_selected_slot_index` | PASS |
| AC-0013-01c | Tab key focus does NOT move the overlay | PASS |
| AC-0013-01d | Gamepad→mouse switch hides overlay; mouse hover unaffected | PASS |

### Concern: Keyboard Focus Ring Not Visible (Production Styling Task)

The prototype's keyboard focus visual was text colour change only (cyan via `add_theme_color_override("font_color")`). No border ring appeared around the focused slot.

**Root cause**: `Panel` nodes in Godot 4.6's default theme do not render a focus ring. The engine's focus ring is rendered by the `focus` `StyleBox` theme property — `Panel` has no default `StyleBox` for that state; only `Button` and similar interactive nodes do.

**Production implication**: Slot `Control`/`Panel` nodes in `prana_grid.gd` must be given an explicit `StyleBox` for the `focus` theme state to produce the "thin accessibility border" required by the ADR. It will not appear automatically — must be configured explicitly via `add_theme_stylebox_override("focus", ...)` at node setup time or via a project theme.

**Verdict impact**: Does NOT block PranaGrid implementation. The three-path input model is confirmed correct in Godot 4.6. The concern is a production styling task only.

## Related Decisions

- [ADR-0002: Autoload Architecture](adr-0002-autoload-architecture.md) — PranaGrid is NOT an Autoload; it is a scene node instantiated within the Preparation Phase UI hierarchy
- [ADR-0003: Signal-Driven Architecture](adr-0003-signal-driven-architecture.md) — `_cursor_visible` must be driven by `_input()` events, not polled in `_process()`; PranaGrid emits `arrangement_confirmed` via signal, not direct call
- [design/gdd/prana-grid.md](../../design/gdd/prana-grid.md) — GDD Rules 9 (mouse model), 10 (gamepad model), Accessibility section, and Visual spec ("Cursor-selected (gamepad)" state); this ADR resolves QQ-02 from the architecture review
- [docs/architecture/architecture-review-2026-05-29.md](architecture-review-2026-05-29.md) — QQ-02 open question; engine specialist recommendation: `_selected_slot_index` + Sprite2D cursor, NOT `grab_focus()`
