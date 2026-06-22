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

## Art Bible palette — matches PranaGridSlot.TYPE_COLORS (QA plan S4-04 checklist).
## TODO(data-driven): demo debt — source colours/names from PranaCatalog (the canonical
## type data) instead of these hardcoded arrays so there is a single source of truth.
const TYPE_COLORS: Array[Color] = [
	Color("#F24C1D"),  # 0 Ashfire
	Color("#4A5EF5"),  # 1 Voidblue
	Color("#FFCC00"),  # 2 Stormgold
	Color("#3DD9F0"),  # 3 Deepfrost
	Color("#1AC953"),  # 4 Verdant
]

## Short display names shown on each token.
const TYPE_NAMES: Array[String] = ["ASH", "VOID", "STRM", "DEEP", "VERD"]

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
	bg.color = TYPE_COLORS[type_id] if type_id >= 0 and type_id < TYPE_COLORS.size() \
		else Color(0.3, 0.3, 0.3)
	add_child(bg)

	var label := Label.new()
	label.text = TYPE_NAMES[type_id] if type_id >= 0 and type_id < TYPE_NAMES.size() else "?"
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
	preview.text = TYPE_NAMES[type_id] if type_id < TYPE_NAMES.size() else str(type_id)
	set_drag_preview(preview)
	var payload: Dictionary = { "type_id": type_id }
	if from_bag:
		payload["from_bag"] = true
	return payload
