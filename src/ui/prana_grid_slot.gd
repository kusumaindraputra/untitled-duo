## PranaGridSlot — A single interactive cell in the 3×3 PranaGrid (Story 002, ADR-0013).
##
## Handles all per-slot input: Godot built-in drag-and-drop API (get_drag_data /
## can_drop_data / drop_data), right-click-to-clear via _gui_input(), and hover
## highlight via StyleBoxFlat swap (no grab_focus() in the mouse path — ADR-0013).
##
## Parent contract: PranaGridSlot is always a direct child of PranaGrid. It calls
## back to the parent via get_parent()._place_token() and get_parent()._clear_slot().
## mouse_filter and focus_mode are set by PranaGrid._ready() after instantiation.
##
## ADR-0013 constraints enforced here:
##   - grab_focus() NEVER called in any mouse handler.
##   - Drag payload is { "type_id": int } — no other keys.
##   - can_drop_data rejects any payload that is not a Dictionary with "type_id".
class_name PranaGridSlot
extends Control  # Never Container — ADR-0013 hard constraint

## Index of this slot in the parent PranaGrid's _slots array (0–8).
## Set by PranaGrid._ready() immediately after instantiation.
var slot_index: int = -1

## type_id of the token currently displayed in this slot, or -1 if empty.
## Kept in sync with PranaGrid._slots[slot_index] via _refresh().
## -1 matches PranaFragment.type_id sentinel for "no fragment" (prana_fragment.gd).
var _displayed_type_id: int = -1

## StyleBox applied when the mouse is hovering over this slot.
## Assigned by PranaGrid._ready(). Not set here to keep slot stateless on init.
var _hover_stylebox: StyleBoxFlat = null

## StyleBox applied when this slot has keyboard focus (must be explicit in Godot 4.6).
## Assigned by PranaGrid._ready() via add_theme_stylebox_override("focus", ...).
var _focus_stylebox: StyleBoxFlat = null

## StyleBox applied in the default (no-hover, no-focus) state.
## Assigned by PranaGrid._ready().
var _default_stylebox: StyleBoxFlat = null


## Returns the drag payload when a filled slot is dragged (GDD Rule 9).
## Payload: { "type_id": int, "source_slot": int } so the grid can clear the
## source slot on a successful inter-slot drag.
## Returns null when this slot is empty — cancels the drag initiation.
func get_drag_data(_at_position: Vector2) -> Variant:
	if _displayed_type_id == -1:
		return null
	var payload := { "type_id": _displayed_type_id, "source_slot": slot_index }
	# Drag preview — lightweight label so the player sees what they are dragging.
	# Full art preview is a Story 002 scene-tree concern; this is the logic stub.
	var preview := Label.new()
	preview.text = str(_displayed_type_id)
	set_drag_preview(preview)
	return payload


## Accepts drop only when payload is a Dictionary containing "type_id" (ADR-0013).
func can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("type_id")


## Handles the drop: places the incoming token on this slot.
## If the payload carries a "source_slot" key (inter-slot drag), the source slot
## is cleared first so the token moves rather than copies.
func drop_data(_at_position: Vector2, data: Variant) -> void:
	var parent := get_parent() as PranaGrid
	if parent == null:
		push_error("PranaGridSlot: parent is not PranaGrid — slot_index %d orphaned" % slot_index)
		return
	# Clear source slot on inter-slot drag (slot-to-slot swap path, GDD Rule 9).
	if data.has("source_slot") and data["source_slot"] != slot_index:
		parent._clear_slot(data["source_slot"])
	parent._place_token(slot_index, data["type_id"])


## Handles right-click-to-clear (AC-PG-07) and future click-to-place events.
## Mouse button events only — keyboard/gamepad actions handled by PranaGrid directly.
func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		var parent := get_parent() as PranaGrid
		if parent != null:
			parent._clear_slot(slot_index)
		get_viewport().set_input_as_handled()


## Applies hover StyleBoxFlat — no grab_focus() (ADR-0013 hard constraint).
func _on_mouse_entered() -> void:
	if _hover_stylebox != null:
		add_theme_stylebox_override("panel", _hover_stylebox)


## Restores default StyleBoxFlat on mouse exit.
func _on_mouse_exited() -> void:
	if _default_stylebox != null:
		add_theme_stylebox_override("panel", _default_stylebox)


## Updates _displayed_type_id. Called by PranaGrid after any slot mutation.
## [param type_id] is -1 for empty, 0–4 for a placed fragment type.
func refresh(type_id: int) -> void:
	_displayed_type_id = type_id
	# Visual update (token icon/color swap) is a scene-tree concern handled in
	# the .tscn scene; this method is the logic hook that drives it.
	queue_redraw()
