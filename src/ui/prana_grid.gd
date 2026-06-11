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

## Duration in seconds for the centre-slot error flash indicator (AC-PG-05).
const ERROR_FLASH_DURATION := 0.4

## Grid phase states driven by GameStateManager signals (TR-PG-003).
enum State {
	ARRANGEMENT,  ## Player may place, move, and clear tokens.
	LOCKED,       ## Display-only; committed arrangement is frozen.
	HIDDEN,       ## Grid not visible; initial state before first wave.
}

## Current phase state. Never read this from outside — subscribe to signals.
var _state: State = State.HIDDEN

## Slot contents. Length always GRID_SIZE. null = empty. Integer type_id = filled.
## Written in Story 002 (placement/clear). Read by _on_confirm_pressed() to build
## _committed_fragments. PranaFragment objects live only in _committed_fragments.
var _slots: Array[Variant] = []

## Confirmed arrangement as PranaFragment objects. Length always GRID_SIZE.
## null entries indicate empty slots. Written only by _on_confirm_pressed().
## Read-only by convention — CombinationResolution and SCE access via getter (TR-PG-002).
var _committed_fragments: Array[PranaFragment] = []

## Countdown timer for the centre-slot error flash indicator (AC-PG-05).
## Counts down in _process(). Zero means no flash is active.
var _error_flash_timer: float = 0.0

## Error label shown when confirm is attempted with slot 4 empty (AC-PG-05).
## Null in headless tests (._ready() not called) and before the scene node is wired.
## Set by scene configuration or parent after instantiation.
var _error_label: Label = null

## Gamepad cursor index. Default: slot 4 (centre). Updated in Story 004.
var _selected_slot_index: int = 4

## True when last input event was from a joypad. Updated in Story 004.
var _cursor_visible: bool = false


func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	_slots.resize(GRID_SIZE)
	_slots.fill(null)
	_committed_fragments.resize(GRID_SIZE)
	GameStateManager.preparation_started.connect(_on_preparation_started)
	GameStateManager.grid_locked.connect(_on_grid_locked)
	GameStateManager.grid_hidden.connect(_on_grid_hidden)


func _exit_tree() -> void:
	GameStateManager.preparation_started.disconnect(_on_preparation_started)
	GameStateManager.grid_locked.disconnect(_on_grid_locked)
	GameStateManager.grid_hidden.disconnect(_on_grid_hidden)


## Ticks the error-flash timer and hides the error label when it expires (AC-PG-05).
## No-op when no flash is active.
func _process(delta: float) -> void:
	if _error_flash_timer > 0.0:
		_error_flash_timer -= delta
		if _error_flash_timer <= 0.0:
			_error_flash_timer = 0.0
			# _error_label node wired in scene tree (Story 002 scene setup).
			# Guard protects against headless-test instantiation with .new().
			if _error_label != null:
				_error_label.visible = false


## Resets all slots to empty and enters ARRANGEMENT state.
## Called on every new wave start, from any prior state.
func _on_preparation_started(_wave_index: int = 0, _waves_remaining: int = 0) -> void:
	_slots.fill(null)
	_committed_fragments.fill(null)
	_state = State.ARRANGEMENT


## Transitions to LOCKED state and reduces grid opacity to 70% (AC-PG-12).
## Logs a sequencing error if no arrangement was confirmed this phase
## (committed_fragments all-null — GSM bug guard).
func _on_grid_locked() -> void:
	# _slots[4] access is safe: initial state is HIDDEN, so this branch cannot
	# execute before _ready() initialises _slots to length GRID_SIZE.
	if _state == State.ARRANGEMENT and _slots[4] == null:
		push_error("PranaGrid: grid_locked received without arrangement_confirmed — committed_fragments all-null (Game State sequencing bug)")
	_state = State.LOCKED
	modulate.a = 0.7


## Transitions to HIDDEN state (between runs or during main menu).
## Restores full opacity so the grid is ready for the next preparation phase.
func _on_grid_hidden() -> void:
	_state = State.HIDDEN
	modulate.a = 1.0


## Called when the Confirm button is pressed (TR-PG-004).
##
## Guard: slot 4 (centre) must be non-null. If empty, fires the error flash
## indicator (AC-PG-05) and returns without emitting.
##
## On success: builds _committed_fragments (length GRID_SIZE, nulls for empty slots,
## PranaFragment for filled slots) and emits [signal arrangement_confirmed] (AC-PG-03).
func _on_confirm_pressed() -> void:
	if _slots[4] == null:
		_show_centre_error_indicator()
		return
	var fragments: Array[PranaFragment] = []
	fragments.resize(GRID_SIZE)
	for i in GRID_SIZE:
		if _slots[i] != null:
			var f := PranaFragment.new()
			f.type_id = _slots[i]
			f.level = 1
			f.stat_property = {}
			f.adjacency_effects = []
			fragments[i] = f
		else:
			fragments[i] = null
	_committed_fragments = fragments
	arrangement_confirmed.emit()


## Places [param type_id] into slot [param slot_index] during ARRANGEMENT state.
## Called by PranaGridSlot.drop_data() (drag-and-drop path) and by direct
## placement logic (click-to-place path). No-op outside ARRANGEMENT.
func _place_token(slot_index: int, type_id: int) -> void:
	if _state != State.ARRANGEMENT:
		return
	_slots[slot_index] = type_id


## Clears slot [param slot_index] during ARRANGEMENT state (AC-PG-07).
## Called by PranaGridSlot right-click handler. No-op outside ARRANGEMENT.
func _clear_slot(slot_index: int) -> void:
	if _state != State.ARRANGEMENT:
		return
	_slots[slot_index] = null


## Clears all 9 slots during ARRANGEMENT state (AC-PG-08).
## Called by the Clear All button in the scene tree. Confirm button returns to
## disabled state after this (handled in scene tree via is_loadout_valid()).
func clear_all() -> void:
	if _state != State.ARRANGEMENT:
		return
	_slots.fill(null)


## Returns true when slot 4 (centre) is non-null (TR-PG-006).
## Queried by GameStateManager before the PREPARATION → COMBAT transition.
func is_loadout_valid() -> bool:
	return _slots[4] != null


## Returns the confirmed arrangement as an [Array][PranaFragment] of length 9 (TR-PG-002).
## Empty slots are null. Read-only by convention — do not write to the returned array.
## Consumed by CombinationResolution and SpellCastingEffects after [signal arrangement_confirmed].
func get_committed_fragments() -> Array[PranaFragment]:
	return _committed_fragments


## Starts the centre-slot error flash indicator (AC-PG-05).
## Shows the error label for ERROR_FLASH_DURATION seconds; _process() hides it.
func _show_centre_error_indicator() -> void:
	_error_flash_timer = ERROR_FLASH_DURATION
	# _error_label node wired in scene tree (Story 002 scene setup).
	# Guard protects against headless-test instantiation with .new().
	if _error_label != null:
		_error_label.visible = true


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
