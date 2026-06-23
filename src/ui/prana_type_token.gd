## prana_type_token.gd — Draggable Prana type token in the Type Selector panel.
##
## Displays a colored tile with the type abbreviation. Implements get_drag_data()
## so the player can drag it onto a PranaGridSlot (PranaGridSlot.can_drop_data
## accepts any Dictionary with "type_id").
##
## type_id must be set before add_child() is called — _ready() reads it to build
## the visual children.
class_name PranaTypeToken
extends Panel

## Centralized UI copy — supplies the short type abbreviations. Full names and
## colours come from PranaCatalog (the canonical Prana type data), so there is a
## single source of truth and nothing is duplicated here.
const _COPY: UICopy = preload("res://assets/data/ui_copy.tres")


## Number of Prana types, from PranaCatalog (single source of truth). Used for
## loop bounds and validity checks by token consumers.
static func type_count() -> int:
	return PranaCatalog.type_count()


## Canonical display [Color] for [param type_id], from PranaCatalog. Returns a
## neutral grey for an out-of-range id.
static func type_color(type_id: int) -> Color:
	return PranaCatalog.get_type_color(type_id)


## Short display abbreviation for [param type_id] (e.g. "ASH"), from UICopy.
## Returns "?" for an out-of-range id.
static func type_abbrev(type_id: int) -> String:
	if type_id < 0 or type_id >= _COPY.type_abbrevs.size():
		return "?"
	return _COPY.type_abbrevs[type_id]

## Prana type index (0–4). Set by PranaGrid._create_ui_nodes() before add_child().
var type_id: int = -1

## Grid reference wired by PranaGrid._create_ui_nodes(). Null in drag-only contexts.
var _prana_grid: PranaGrid = null

## When true, this token represents one fragment in the PranaBag (grid-as-build model):
## left-click selects it for click-to-place, and the drag payload is tagged "from_bag"
## so a drop consumes a bag fragment instead of free-filling. When false (legacy free-fill
## selector, now hidden), left-click fills all slots with this type.
var from_bag: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(56.0, 56.0)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.color = type_color(type_id)
	add_child(bg)

	var label := Label.new()
	label.text = type_abbrev(type_id)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


## Left-click behaviour depends on mode. Bag tokens (from_bag) select this type for
## click-to-place into an empty grid slot; legacy selector tokens fill all 9 slots.
## Drag still works for individual slot placement (see _get_drag_data).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if _prana_grid != null:
			if from_bag:
				_prana_grid._select_bag_type(type_id)
			else:
				_prana_grid.fill_all(type_id)
			accept_event()


## Returns the drag payload consumed by PranaGridSlot._drop_data().
## Bag tokens tag the payload "from_bag" so the drop consumes a bag fragment and only
## lands on an empty slot. Drag preview shows the type abbreviation label.
func _get_drag_data(_at_position: Vector2) -> Variant:
	if type_id < 0:
		return null
	var preview := Label.new()
	preview.text = type_abbrev(type_id)
	set_drag_preview(preview)
	var payload: Dictionary = { "type_id": type_id }
	if from_bag:
		payload["from_bag"] = true
	return payload
