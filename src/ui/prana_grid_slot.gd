## PranaGridSlot — A single interactive cell in the 3×3 PranaGrid (Story 002, ADR-0013).
##
## Handles all per-slot input: Godot built-in drag-and-drop API (get_drag_data /
## can_drop_data / drop_data), right-click-to-clear via _gui_input(), and hover
## highlight via StyleBoxFlat swap (no grab_focus() in the mouse path — ADR-0013).
##
## Parent contract: PranaGridSlot calls back to PranaGrid via the _prana_grid
## reference set by PranaGrid._create_ui_nodes() after instantiation. Do NOT use
## get_parent() — slots live inside a GridContainer, not directly under PranaGrid.
## mouse_filter and focus_mode are set by PranaGrid._create_ui_nodes() after instantiation.
##
## ADR-0013 constraints enforced here:
##   - grab_focus() NEVER called in any mouse handler.
##   - Drag payload is { "type_id": int } — no other keys.
##   - _can_drop_data rejects any payload that is not a Dictionary with "type_id".
class_name PranaGridSlot
extends Panel  # Panel so add_theme_stylebox_override("panel", ...) renders correctly

## Background color for an empty slot.
const EMPTY_COLOR := Color(0.13, 0.13, 0.13, 0.92)

## Index of this slot in the parent PranaGrid's _slots array (0–8).
## Set by PranaGrid._create_ui_nodes() immediately after instantiation.
var slot_index: int = -1

## Direct reference to the owning PranaGrid. Set by PranaGrid._create_ui_nodes().
## Required because slots live inside a GridContainer (not a direct PranaGrid child).
var _prana_grid: PranaGrid = null

## type_id of the token currently displayed in this slot, or -1 if empty.
## Kept in sync with PranaGrid._slots[slot_index] via refresh().
var _displayed_type_id: int = -1

## StyleBox applied when the mouse is hovering over this slot.
## Assigned by PranaGrid._ready(). Not set here to keep slot stateless on init.
var _hover_stylebox: StyleBoxFlat = null

## StyleBox applied in the default (no-hover, no-focus) state.
## Assigned by PranaGrid._ready().
var _default_stylebox: StyleBoxFlat = null

## ColorRect child that shows the Prana type color (or empty state).
## Created in _ready(); null until the node enters the scene tree.
var _color_rect: ColorRect = null


func _ready() -> void:
	_color_rect = ColorRect.new()
	_color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_color_rect.color = EMPTY_COLOR
	add_child(_color_rect)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


## Returns the drag payload when a filled slot is dragged (GDD Rule 9).
## Payload: { "type_id": int, "source_slot": int } so the grid can clear the
## source slot on a successful inter-slot drag.
## Returns null when this slot is empty — cancels the drag initiation.
func _get_drag_data(_at_position: Vector2) -> Variant:
	if _displayed_type_id == -1:
		return null
	var payload := { "type_id": _displayed_type_id, "source_slot": slot_index }
	var preview := Label.new()
	preview.text = str(_displayed_type_id)
	set_drag_preview(preview)
	return payload


## Accepts drop only when payload is a Dictionary containing "type_id" (ADR-0013).
## Bag drops ("from_bag") are rejected on a filled slot — bag fragments may only land
## on an empty slot (grid-as-build: free a slot first by removing an existing fragment).
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.has("type_id")):
		return false
	if data.has("from_bag") and _displayed_type_id != -1:
		return false
	return true


## Handles the drop: places the incoming token on this slot.
## Bag drops ("from_bag") consume one bag fragment and only land on an empty slot.
## Inter-slot drags (payload carries "source_slot") clear the source so the token
## moves rather than copies.
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _prana_grid == null:
		push_error("PranaGridSlot: _prana_grid not set — slot_index %d orphaned" % slot_index)
		return
	if data.has("from_bag"):
		_prana_grid._place_from_bag(slot_index, data["type_id"])
		return
	# Clear source slot on inter-slot drag (slot-to-slot swap path, GDD Rule 9).
	if data.has("source_slot") and data["source_slot"] != slot_index:
		_prana_grid._clear_slot(data["source_slot"])
	_prana_grid._place_token(slot_index, data["type_id"])


## Handles right-click-to-clear (AC-PG-07) and left-click-to-place from the bag.
## Mouse button events only — keyboard/gamepad actions handled by PranaGrid directly.
func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		# Right-click discards the fragment in this slot, freeing it for a new placement.
		if _prana_grid != null:
			_prana_grid._clear_slot(slot_index)
		accept_event()
	elif mb.button_index == MOUSE_BUTTON_LEFT:
		# Left-click places the currently selected bag fragment into this empty slot.
		if _prana_grid != null:
			_prana_grid._place_selected_bag_into(slot_index)
		accept_event()


## Applies hover StyleBoxFlat — no grab_focus() (ADR-0013 hard constraint).
func _on_mouse_entered() -> void:
	if _hover_stylebox != null:
		add_theme_stylebox_override("panel", _hover_stylebox)


## Restores default StyleBoxFlat on mouse exit.
func _on_mouse_exited() -> void:
	if _default_stylebox != null:
		add_theme_stylebox_override("panel", _default_stylebox)


## Updates _displayed_type_id and the ColorRect background color.
## Called by PranaGrid after any slot mutation.
## [param type_id] is -1 for empty, 0–4 for a placed fragment type.
func refresh(type_id: int) -> void:
	_displayed_type_id = type_id
	if _color_rect != null:
		_color_rect.color = EMPTY_COLOR if type_id == -1 else PranaTypeToken.TYPE_COLORS[type_id]
