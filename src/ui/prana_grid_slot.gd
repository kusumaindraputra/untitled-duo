## PranaGridSlot — A single interactive cell in the 3×3 PranaGrid (Story 002, ADR-0013).
##
## Handles all per-slot input: Godot built-in drag-and-drop API (get_drag_data /
## can_drop_data / drop_data), right-click-to-clear via _gui_input(), and hover
## highlight via StyleBoxFlat swap (no grab_focus() in the mouse path — ADR-0013).
##
## ADR-0042 (art bible §3.4): the slot draws itself as a circle — "empty slot =
## potential, filled slot = Prana type within arc slot". The hit area stays the full
## square cell, so drag-and-drop and clicks behave exactly as before.
##
## Parent contract: PranaGridSlot calls back to PranaGrid via the _prana_grid
## reference set by PranaGrid._create_ui_nodes() after instantiation. Do NOT use
## get_parent() — slots live inside a GridContainer, not directly under PranaGrid.
## mouse_filter and focus_mode are set by PranaGrid._create_ui_nodes() after instantiation.
##
## ADR-0013 constraints enforced here:
##   - grab_focus() NEVER called in any mouse handler.
##   - Drag payload always carries "type_id"; inter-slot drags add "source_slot" and
##     bag placements add "from_bag" (grid-as-build). _can_drop_data rejects any payload
##     that is not a Dictionary with "type_id".
class_name PranaGridSlot
extends Panel  # Panel so add_theme_stylebox_override("panel", ...) renders correctly

## Background color for an empty slot (E6 Atmosphere Haze, art bible §4.4).
const EMPTY_COLOR := Color(UIPalette.VOID, 0.92)
## Slot rim (E7) and its hover highlight.
const RIM_COLOR := UIPalette.BORDER
const RIM_HOVER_COLOR := UIPalette.ACCENT
## Rim width in px.
const RIM_WIDTH: float = 2.0

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

## Circle fill: the Prana type colour, or EMPTY_COLOR. Drawn in _draw().
var _fill_color: Color = EMPTY_COLOR
## True while the mouse is over the slot (brightens the rim).
var _hovered: bool = false

## Shape icon over the colour so the type reads without colour (ADR-0036).
## Created in _ready(); hidden while the slot is empty.
var _icon_rect: TextureRect = null

## Whole-number scale for the 12 px icon: 36 px inside the 54 px slot.
const ICON_SCALE: int = 3


func _ready() -> void:
	# The circle is drawn in _draw(); the square Panel box is kept only as a hit area.
	if _default_stylebox == null:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_icon_rect = PranaIcon.make_rect(0, ICON_SCALE)
	_icon_rect.visible = false
	add_child(_icon_rect)
	refresh(_displayed_type_id)
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
	set_drag_preview(PranaIcon.make_rect(_displayed_type_id, ICON_SCALE,
			PranaTypeToken.type_color(_displayed_type_id), false))
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
	_hovered = true
	queue_redraw()
	if _hover_stylebox != null:
		add_theme_stylebox_override("panel", _hover_stylebox)


## Restores default StyleBoxFlat on mouse exit.
func _on_mouse_exited() -> void:
	_hovered = false
	queue_redraw()
	if _default_stylebox != null:
		add_theme_stylebox_override("panel", _default_stylebox)


## Draws the circular slot: fill, then the E7 rim (brighter on hover).
func _draw() -> void:
	var r: float = circle_radius(size)
	if r <= 0.0:
		return
	var c: Vector2 = size * 0.5
	draw_circle(c, r, _fill_color, true, -1.0, true)
	draw_arc(c, r - RIM_WIDTH * 0.5, 0.0, TAU, 48, RIM_HOVER_COLOR if _hovered else RIM_COLOR,
		RIM_WIDTH, true)


## Pure: the slot circle's radius for a cell of [param cell_size] (inscribed, 1 px in).
static func circle_radius(cell_size: Vector2) -> float:
	return maxf(minf(cell_size.x, cell_size.y) * 0.5 - 1.0, 0.0)


## The colour the circle is filled with now (tests).
func get_fill_color() -> Color:
	return _fill_color


## Updates _displayed_type_id and the ColorRect background color.
## Called by PranaGrid after any slot mutation.
## [param type_id] is -1 for empty, 0–4 for a placed fragment type.
func refresh(type_id: int) -> void:
	_displayed_type_id = type_id
	_fill_color = EMPTY_COLOR if type_id == -1 else PranaTypeToken.type_color(type_id)
	queue_redraw()
	if _icon_rect != null:
		_icon_rect.visible = type_id != -1
		if type_id != -1:
			_icon_rect.texture = PranaIcon.texture(type_id, ICON_SCALE)
