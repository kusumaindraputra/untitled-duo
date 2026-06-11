# Story 001: PranaGrid Phase Gating (ARRANGEMENT / LOCKED / HIDDEN)

> **Epic**: Prana Grid
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 0.75 days
> **Sprint ID**: S4-03
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-11

## Context

**GDD**: `design/gdd/prana-grid.md`
**Requirements**: `TR-PG-003`, `TR-PG-005`
- TR-PG-003: Phase-gate states (ARRANGEMENT/LOCKED/HIDDEN) driven by GSM signals: preparation_started, grid_locked, grid_hidden
- TR-PG-005: PROCESS_MODE_PAUSABLE — grid preserves state (ARRANGEMENT or LOCKED) during pause; no state change on game_paused

**ADR Governing Implementation**: ADR-0013: PranaGrid Dual-Input Focus Model (primary) + ADR-0003: Signal-Driven Architecture (secondary)
**ADR Decision Summary**: PranaGrid uses a three-path input model with `_selected_slot_index` + `_gamepad_cursor` overlay for gamepad; it connects to GSM signals in `_ready()` and disconnects in `_exit_tree()`. State machine is driven entirely by signal events — no polling.

**Engine**: Godot 4.6 | **Risk**: LOW (state machine + signals are stable APIs)
**Engine Notes**: `PROCESS_MODE_PAUSABLE` stops input processing when `get_tree().paused = true`. PranaGrid root must be a plain `Control` or `Panel` — never a `Container` subclass (per ADR-0013).

**Control Manifest Rules (Core layer)**:
- Required: Connect to signals in `_ready()`, disconnect scene nodes in `_exit_tree()` (ADR-0003)
- Required: All in-game timing uses float delta accumulators in `_process(delta)` (ADR-0004)
- Required: `PROCESS_MODE_PAUSABLE` for PranaGrid (ADR-0004)
- Forbidden: Never poll Autoload state in `_process()` to detect changes — subscribe to signals (ADR-0003)
- Forbidden: Never use string-based signal connections (ADR-0003)

---

## Acceptance Criteria

*From `design/gdd/prana-grid.md`, scoped to this story:*

- [ ] **AC-PG-01**: `preparation_started` → all 9 slots reset to empty (null) and grid enters ARRANGEMENT state; applies from any previous state (LOCKED, HIDDEN, or ARRANGEMENT)
- [ ] **AC-PG-02**: `grid_locked` → grid enters LOCKED state; all input (drag, place, clear, confirm) is disabled and produces no state change and no signal emission
- [ ] HIDDEN state entered on `grid_hidden` signal; ARRANGEMENT re-entered from HIDDEN on next `preparation_started`
- [ ] `grid_locked` received without prior `arrangement_confirmed` this phase → grid enters LOCKED with all-null committed_fragments; `push_error()` logged (sequencing bug guard — does not crash)
- [ ] In ARRANGEMENT state: the 9-element slots array exists and all elements are null on entry; slot index is computed by `slot_index = row × 3 + col` (Formula 1)
- [ ] Slot index invariants: index 4 = centre (row 1, col 1); inverse: `row = slot_index / 3` (integer division), `col = slot_index % 3`
- [ ] `process_mode = PROCESS_MODE_PAUSABLE` — grid state is preserved (unchanged) during pause; no state transition fires on game_paused/game_resumed

---

## Implementation Notes

*Derived from ADR-0013 + ADR-0003:*

**Node setup:**
```gdscript
class_name PranaGrid
extends Control  # Never Container — ADR-0013 hard requirement

const GRID_SIZE := 9
signal arrangement_confirmed

var _state: State = State.HIDDEN
var _slots: Array = []  # Array[PranaFragment or null], length 9
var _selected_slot_index: int = 4  # gamepad cursor — default centre
var _cursor_visible: bool = false

enum State { ARRANGEMENT, LOCKED, HIDDEN }
```

**Signal connections in `_ready()`:**
```gdscript
func _ready() -> void:
    process_mode = PROCESS_MODE_PAUSABLE
    _slots.resize(GRID_SIZE)
    _slots.fill(null)
    GameStateManager.preparation_started.connect(_on_preparation_started)
    GameStateManager.grid_locked.connect(_on_grid_locked)
    GameStateManager.grid_hidden.connect(_on_grid_hidden)

func _exit_tree() -> void:
    GameStateManager.preparation_started.disconnect(_on_preparation_started)
    GameStateManager.grid_locked.disconnect(_on_grid_locked)
    GameStateManager.grid_hidden.disconnect(_on_grid_hidden)
```

**State transitions:**
```gdscript
func _on_preparation_started(_wave_index: int = 0, _waves_remaining: int = 0) -> void:
    _slots.fill(null)
    _state = State.ARRANGEMENT

func _on_grid_locked() -> void:
    if _state == State.ARRANGEMENT and _slots[4] == null:
        push_error("PranaGrid: grid_locked received without arrangement_confirmed — committed_fragments all-null (Game State sequencing bug)")
    _state = State.LOCKED

func _on_grid_hidden() -> void:
    _state = State.HIDDEN
```

**Slot index formula (Formula 1):**
```gdscript
static func slot_index(row: int, col: int) -> int:
    return row * 3 + col

static func slot_row(index: int) -> int:
    return index / 3

static func slot_col(index: int) -> int:
    return index % 3
```

**This story stops here.** Drag-and-drop input, confirmation logic, and visual rendering are Story 002. CR/SCE wiring is Story 003. Gamepad input is Story 004.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: Mouse drag-and-drop input, confirmation rule, committed_fragments array, is_loadout_valid, arrangement_confirmed signal, visual slot rendering
- **Story 003**: committed_fragments getter wired to CombinationResolution and SpellCastingEffects
- **Story 004**: Gamepad d-pad navigation, `_selected_slot_index` updates, `_gamepad_cursor` overlay

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-4-2026-06-11.md` — Automated Tests Required § S4-03.*

**Test file**: `tests/unit/prana-grid/prana_grid_phase_gating_test.gd`

- **AC-PG-01a** — preparation_started from ARRANGEMENT resets all slots
  - Given: Grid in ARRANGEMENT state with 3 slots filled
  - When: `_on_preparation_started()` called
  - Then: All 9 `_slots` elements are null; `_state == State.ARRANGEMENT`
  - Edge cases: Slots with same type in all 9 positions → all become null

- **AC-PG-01b** — preparation_started from LOCKED resets all slots
  - Given: Grid in LOCKED state (arrangement was confirmed)
  - When: `_on_preparation_started()` called
  - Then: All 9 `_slots` elements are null; `_state == State.ARRANGEMENT`

- **AC-PG-01c** — preparation_started from HIDDEN resets all slots
  - Given: Grid in HIDDEN state
  - When: `_on_preparation_started()` called
  - Then: All 9 `_slots` elements are null; `_state == State.ARRANGEMENT`

- **AC-PG-02** — grid_locked disables state and sets LOCKED
  - Given: Grid in ARRANGEMENT state
  - When: `_on_grid_locked()` called
  - Then: `_state == State.LOCKED`
  - Edge cases: Second grid_locked call while already LOCKED → no crash, stays LOCKED

- **HIDDEN** — grid_hidden sets HIDDEN state
  - Given: Grid in any state
  - When: `_on_grid_hidden()` called
  - Then: `_state == State.HIDDEN`

- **SEQUENCING BUG** — grid_locked without prior arrangement_confirmed
  - Given: Grid in ARRANGEMENT; no confirm issued; `_slots[4] == null`
  - When: `_on_grid_locked()` called
  - Then: `push_error` was called; `_state == State.LOCKED`; no crash

- **FORMULA-1a** — slot_index formula correctness
  - Given: (row=0, col=0), (row=1, col=1), (row=2, col=2)
  - When: `PranaGrid.slot_index(row, col)` called
  - Then: Returns 0, 4, 8 respectively

- **FORMULA-1b** — slot_index inverse
  - Given: slot_index values 0, 4, 8
  - When: `slot_row(index)` and `slot_col(index)` called
  - Then: (0,0), (1,1), (2,2) respectively

- **PAUSABLE** — state preserved during pause
  - Given: Grid in ARRANGEMENT state with 2 slots filled; `get_tree().paused = true`
  - When: No signals fire (paused)
  - Then: State remains ARRANGEMENT; filled slots unchanged

**Node teardown**: Use `node.free()` (not `queue_free()`) for nodes never added to SceneTree — per `.claude/rules/test-standards.md`.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/prana-grid/prana_grid_phase_gating_test.gd` — must exist and pass headless

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None — this is the foundation story for the PranaGrid epic
- Unlocks: Story 002 (mouse input + confirm needs the phase gating state machine), Story 003 (integration needs LOCKED state), Story 004 (gamepad needs ARRANGEMENT state + slot index formula)
