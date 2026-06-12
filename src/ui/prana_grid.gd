## PranaGrid — 9-slot Prana arrangement grid for the Preparation Phase (GDD prana-grid.md).
##
## Owns the 9-slot arrangement array, grid phase state (ARRANGEMENT / LOCKED / HIDDEN),
## and the [signal arrangement_confirmed] payload passed to CombinationResolution on
## combat start. Implements a three-path input model (ADR-0013): mouse drag-and-drop
## (Story 002), gamepad d-pad cursor (Story 004), keyboard Tab accessibility (engine).
##
## All UI child nodes are created programmatically in _create_ui_nodes() — no .tscn
## children required (follows CombatHUD pattern). Tests instantiate via .new() and
## call handlers directly; _ready() is not called in headless unit tests.
##
## Lives as a child of PranaGridLayer (CanvasLayer layer 1) in main.tscn.
## State resets on each room load via [signal GameStateManager.preparation_started].
class_name PranaGrid
extends Control  # Never Container — ADR-0013 hard constraint

## Emitted when the player confirms a valid arrangement (slot 4 non-null).
## Consumed by GameStateManager to trigger PREPARATION → COMBAT transition.
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
var _error_label: Label = null

## Live PranaGridSlot nodes, indexed 0–8. Empty until _create_ui_nodes() runs.
## Guards in _place_token/_clear_slot check size before accessing.
var _slot_nodes: Array = []

## Confirm button reference. Null in headless tests — all callers guard with != null.
var _confirm_button: Button = null


func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	_slots.resize(GRID_SIZE)
	_slots.fill(null)
	_committed_fragments.resize(GRID_SIZE)
	add_to_group(&"prana_grid")
	GameStateManager.preparation_started.connect(_on_preparation_started)
	GameStateManager.grid_locked.connect(_on_grid_locked)
	GameStateManager.grid_hidden.connect(_on_grid_hidden)
	arrangement_confirmed.connect(GameStateManager._on_arrangement_confirmed)
	_create_ui_nodes()
	visible = false


func _exit_tree() -> void:
	if arrangement_confirmed.is_connected(GameStateManager._on_arrangement_confirmed):
		arrangement_confirmed.disconnect(GameStateManager._on_arrangement_confirmed)
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
			if _error_label != null:
				_error_label.visible = false


## Resets all slots to empty and enters ARRANGEMENT state.
## Called on every new wave start, from any prior state.
func _on_preparation_started(_wave_index: int = 0, _waves_remaining: int = 0) -> void:
	_slots.fill(null)
	_committed_fragments.fill(null)
	_state = State.ARRANGEMENT
	for i in _slot_nodes.size():
		(_slot_nodes[i] as PranaGridSlot).refresh(-1)
	_update_confirm_button()
	visible = true


## Transitions to LOCKED state and reduces grid opacity to 70% (AC-PG-12).
## Logs a sequencing error if no arrangement was confirmed this phase
## (committed_fragments all-null — GSM bug guard).
func _on_grid_locked() -> void:
	if _state == State.ARRANGEMENT and _slots[4] == null:
		push_error("PranaGrid: grid_locked received without arrangement_confirmed — committed_fragments all-null (Game State sequencing bug)")
	_state = State.LOCKED
	modulate.a = 0.7


## Transitions to HIDDEN state (between runs or during main menu).
## Restores full opacity so the grid is ready for the next preparation phase.
func _on_grid_hidden() -> void:
	_state = State.HIDDEN
	modulate.a = 1.0
	visible = false


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
func _place_token(idx: int, type_id: int) -> void:
	if _state != State.ARRANGEMENT:
		return
	_slots[idx] = type_id
	if idx < _slot_nodes.size():
		(_slot_nodes[idx] as PranaGridSlot).refresh(type_id)
	_update_confirm_button()


## Clears slot [param slot_index] during ARRANGEMENT state (AC-PG-07).
## Called by PranaGridSlot right-click handler. No-op outside ARRANGEMENT.
func _clear_slot(idx: int) -> void:
	if _state != State.ARRANGEMENT:
		return
	_slots[idx] = null
	if idx < _slot_nodes.size():
		(_slot_nodes[idx] as PranaGridSlot).refresh(-1)
	_update_confirm_button()


## Clears all 9 slots during ARRANGEMENT state (AC-PG-08).
## Called by the Clear All button. Confirm button returns to disabled state after this.
func clear_all() -> void:
	if _state != State.ARRANGEMENT:
		return
	_slots.fill(null)
	for i in _slot_nodes.size():
		(_slot_nodes[i] as PranaGridSlot).refresh(-1)
	_update_confirm_button()


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


# ── Private ───────────────────────────────────────────────────────────────────

## Builds all UI child nodes programmatically (follows CombatHUD pattern).
## Called once from _ready(). Headless unit tests use .new() and never call
## _ready(), so this method is never executed in the test harness.
func _create_ui_nodes() -> void:
	# Panel pinned to the right side of the viewport using absolute position+size
	# (same pattern as CombatHUD — anchors on CanvasLayer children are unreliable
	# until the layout pass runs, causing the panel to land off-screen).
	var vp_width := get_viewport_rect().size.x
	var panel := Panel.new()
	panel.position = Vector2(vp_width - 380.0, 20.0)
	panel.size = Vector2(360.0, 540.0)
	add_child(panel)

	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override(&"separation", 8)
	panel.add_child(layout)

	# Header
	var header := Label.new()
	header.text = "PREPARATION PHASE"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(header)

	var hint := Label.new()
	hint.text = "Drag tokens to slots  •  Right-click to clear  •  Slot 4 = centre (required)"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(hint)

	# 3×3 slot grid
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 4)
	grid.add_theme_constant_override(&"v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	layout.add_child(grid)

	for i in GRID_SIZE:
		var slot := PranaGridSlot.new()
		slot.slot_index = i
		slot.custom_minimum_size = Vector2(72.0, 72.0)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.focus_mode = Control.FOCUS_ALL
		grid.add_child(slot)
		_slot_nodes.append(slot)

	# Type selector
	var sel_label := Label.new()
	sel_label.text = "─── SELECT TYPE ───"
	sel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(sel_label)

	var selector := HBoxContainer.new()
	selector.add_theme_constant_override(&"separation", 4)
	selector.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	layout.add_child(selector)

	for type_id in 5:
		var token := PranaTypeToken.new()
		token.type_id = type_id
		selector.add_child(token)

	# Buttons row
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 8)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	layout.add_child(buttons)

	var clear_btn := Button.new()
	clear_btn.text = "Clear All"
	clear_btn.pressed.connect(clear_all)
	buttons.add_child(clear_btn)

	_confirm_button = Button.new()
	_confirm_button.text = "Confirm"
	_confirm_button.modulate.a = 0.4
	_confirm_button.disabled = true
	_confirm_button.pressed.connect(_on_confirm_pressed)
	buttons.add_child(_confirm_button)

	# Error label (hidden until slot 4 empty + confirm attempted)
	_error_label = Label.new()
	_error_label.text = "Place a fragment in the centre slot"
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.add_theme_color_override(&"font_color", Color("#FF3333"))
	_error_label.visible = false
	layout.add_child(_error_label)


## Syncs the Confirm button appearance and disabled state with slot 4's content.
## No-op when _confirm_button is null (headless test context).
func _update_confirm_button() -> void:
	if _confirm_button == null:
		return
	var valid: bool = _slots.size() > 4 and _slots[4] != null
	_confirm_button.disabled = not valid
	_confirm_button.modulate.a = 1.0 if valid else 0.4
