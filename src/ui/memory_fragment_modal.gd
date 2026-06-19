## memory_fragment_modal.gd — Placeholder modal for the memory fragment trigger system.
##
## Shows an "Under Construction" panel when Fayde activates an AnchorObject.
## Dismissed by any key or mouse click. Replace body in LD-24+ with real narrative UI.
##
## Story: LD-23 — Memory Fragment Trigger System (placeholder)
## Design: design/anchor-objects.md
class_name MemoryFragmentModal
extends CanvasLayer

var _memory_id: StringName = &""


## Call before add_child() to set which memory was triggered.
func setup(memory_id: StringName) -> void:
	_memory_id = memory_id


func _ready() -> void:
	layer = 20
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		get_viewport().set_input_as_handled()
		queue_free()
	elif event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		queue_free()


# ── Private ───────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(340.0, 180.0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_top", 24)
	margin.add_theme_constant_override(&"margin_bottom", 24)
	margin.add_theme_constant_override(&"margin_left", 32)
	margin.add_theme_constant_override(&"margin_right", 32)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override(&"separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Memory Fragment"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var divider := HSeparator.new()
	vbox.add_child(divider)

	var under_construction := Label.new()
	under_construction.text = "[ Under Construction ]"
	under_construction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(under_construction)

	var id_label := Label.new()
	id_label.text = str(_memory_id)
	id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	id_label.modulate = Color(0.7, 0.7, 0.7, 1.0)
	vbox.add_child(id_label)

	var hint := Label.new()
	hint.text = "[ Press any key to continue ]"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(0.6, 0.6, 0.6, 1.0)
	vbox.add_child(hint)
