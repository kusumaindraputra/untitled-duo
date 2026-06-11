## PranaGrid — 9-slot Prana arrangement grid for the Preparation Phase (GDD prana-grid.md).
##
## Owns the 9-slot arrangement array, grid phase state (ARRANGEMENT / LOCKED / HIDDEN),
## and the [signal arrangement_confirmed] payload passed to CombinationResolution on
## combat start. Implements a three-path input model (ADR-0013): mouse drag-and-drop
## (Story 002), gamepad d-pad cursor (Story 004), keyboard Tab accessibility (engine).
##
## Lives inside IsometricRoom.tscn as a CanvasLayer child (layer 1, ADR-0005).
## State resets on each room load via [signal GameStateManager.preparation_started].
class_name PranaGrid
extends Control  # Never Container — ADR-0013 hard constraint

## Emitted when the player confirms a valid arrangement (slot 4 non-null).
## Consumed by GameStateManager to trigger PREPARATION → COMBAT transition.
## Emitted in Story 002. Declared here so dependent systems can connect early.
signal arrangement_confirmed

## Number of slots in the grid (3×3).
const GRID_SIZE := 9

## Grid phase states driven by GameStateManager signals (TR-PG-003).
enum State {
	ARRANGEMENT,  ## Player may place, move, and clear tokens.
	LOCKED,       ## Display-only; committed arrangement is frozen.
	HIDDEN,       ## Grid not visible; initial state before first wave.
}

## Current phase state. Never read this from outside — subscribe to signals.
var _state: State = State.HIDDEN

## Slot contents. Length always GRID_SIZE. null = empty. PranaFragment = filled.
## Written in Story 002 (placement/clear). Read by Story 003 (CR integration).
var _slots: Array = []

## Gamepad cursor index. Default: slot 4 (centre). Updated in Story 004.
var _selected_slot_index: int = 4

## True when last input event was from a joypad. Updated in Story 004.
var _cursor_visible: bool = false


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


## Resets all slots to empty and enters ARRANGEMENT state.
## Called on every new wave start, from any prior state.
func _on_preparation_started(_wave_index: int = 0, _waves_remaining: int = 0) -> void:
	_slots.fill(null)
	_state = State.ARRANGEMENT


## Transitions to LOCKED state. Logs a sequencing error if no arrangement was
## confirmed this phase (committed_fragments will be all-null — GSM bug guard).
func _on_grid_locked() -> void:
	if _state == State.ARRANGEMENT and _slots[4] == null:
		push_error("PranaGrid: grid_locked received without arrangement_confirmed — committed_fragments all-null (Game State sequencing bug)")
	_state = State.LOCKED


## Transitions to HIDDEN state (between runs or during main menu).
func _on_grid_hidden() -> void:
	_state = State.HIDDEN


## Returns the flat slot index for a given [param row] and [param col] (GDD Formula 1).
## Index 4 is always the centre slot (row 1, col 1).
static func slot_index(row: int, col: int) -> int:
	return row * 3 + col


## Returns the row for a given flat [param index] (inverse of Formula 1).
static func slot_row(index: int) -> int:
	return index / 3


## Returns the column for a given flat [param index] (inverse of Formula 1).
static func slot_col(index: int) -> int:
	return index % 3
