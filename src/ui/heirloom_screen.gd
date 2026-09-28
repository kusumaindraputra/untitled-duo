## HeirloomScreen — unlock and equip Heirlooms on their own screen (beta plan U7).
##
## Opened from the main menu's Heirlooms button. Lists every Heirloom with its state
## (locked with cost, unlocked, equipped), shows what the focused one does and what
## pressing it will do, and saves after each change. Keyboard / gamepad navigable, Esc
## or Back closes it, and it works while the tree is paused (PROCESS_MODE_ALWAYS).
##
## Design: ADR-0025 (meta progression).
class_name HeirloomScreen
extends CanvasLayer

## The screen was closed.
signal closed
## Progress changed and was saved (the menu refreshes its progress line).
signal progress_changed

const _COPY: UICopy = preload("res://assets/data/ui_copy.tres")
const _META: MetaTuning = preload("res://assets/data/meta_tuning.tres")
const TITLE_COLOR := UIPalette.ACCENT
const EQUIPPED_TINT := Color(1.0, 0.9, 0.5)
const POOR_TINT := UIPalette.TEXT_DIM

## Progress to read and write. The menu passes its loaded copy; tests inject their own.
var progress: MetaProgress = null
## Where progress is saved. Tests point this at a temp file.
var progress_path: String = MetaProgress.DEFAULT_PATH

var _buttons: Array[Button] = []
var _shards_label: Label = null
var _desc_label: Label = null
var _back: Button = null


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	if progress == null:
		progress = MetaProgress.new()
	_build()
	for child: Node in get_children():
		if child is CanvasItem:
			UIFeel.fade_in(child as CanvasItem)
	refresh()
	var first: int = maxi(_META.heirloom_ids.find(progress.equipped), 0)
	if not _buttons.is_empty():
		_buttons[first].grab_focus()
		_show_desc(_META.heirloom_ids[first])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Closes the screen and emits [signal closed].
func close() -> void:
	closed.emit()
	queue_free()


## Button text for Heirloom [param id] in its current state.
static func button_text(p: MetaProgress, id: StringName) -> String:
	var title: String = str(MetaProgress.heirloom_info(id).get("title", id))
	if p.equipped == id and p.is_unlocked(id):
		return _COPY.heirloom_equipped_format % title
	if p.is_unlocked(id):
		return _COPY.heirloom_unlocked_format % title
	if not p.is_revealed(_META, id):
		return _COPY.heirloom_memory_locked_format % [title, _META.memories_needed(id)]
	return _COPY.heirloom_locked_format % [title, _META.cost_of(id)]


## What [param id] does and what pressing it will do.
static func desc_text(p: MetaProgress, id: StringName) -> String:
	var hint: String = _COPY.heirloom_hint_buy
	if p.is_unlocked(id):
		hint = _COPY.heirloom_hint_unequip if p.equipped == id else _COPY.heirloom_hint_equip
	elif not p.is_revealed(_META, id):
		hint = _COPY.heirloom_hint_memories_format % _META.memories_needed(id)
	elif not p.can_unlock(_META, id):
		hint = _COPY.heirloom_hint_poor
	return _COPY.heirloom_desc_format % [str(MetaProgress.heirloom_info(id).get("desc", "")), hint]


## Re-reads [member progress] into the shard line and every button.
func refresh() -> void:
	_shards_label.text = _COPY.heirloom_shards_format % progress.shards
	for i: int in _buttons.size():
		var id: StringName = _META.heirloom_ids[i]
		var b: Button = _buttons[i]
		b.text = button_text(progress, id)
		if progress.equipped == id and progress.is_unlocked(id):
			b.modulate = EQUIPPED_TINT
		elif progress.is_unlocked(id) or progress.can_unlock(_META, id):
			b.modulate = Color.WHITE
		else:
			b.modulate = POOR_TINT


## Unlocks a locked Heirloom (if affordable) or toggles an unlocked one, then saves.
func press(id: StringName) -> void:
	var changed: bool = progress.unlock(_META, id) if not progress.is_unlocked(id) \
		else progress.toggle_equip(id)
	if changed:
		progress.save_to(progress_path)
		progress_changed.emit()
	refresh()
	_show_desc(id)


## Current description text. Test seam.
func description() -> String:
	return _desc_label.text


## The Heirloom buttons in catalog order. Test seam.
func buttons() -> Array[Button]:
	return _buttons


func _show_desc(id: StringName) -> void:
	_desc_label.text = desc_text(progress, id)


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.06, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override(&"separation", 16)
	add_child(root)

	root.add_child(_label(_COPY.heirloom_screen_title, 40, TITLE_COLOR))
	root.add_child(_label(_COPY.heirloom_header, 16, UIPalette.TEXT_DIM))
	_shards_label = _label("", 20, UIPalette.ACCENT)
	root.add_child(_shards_label)

	var grid := GridContainer.new()
	grid.columns = 4  # 12 Heirlooms: three even rows
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", 10)
	root.add_child(grid)
	for id: StringName in _META.heirloom_ids:
		var b := Button.new()
		b.name = "Heirloom_%s" % id
		b.custom_minimum_size = Vector2(190, 58)
		b.add_theme_font_size_override(&"font_size", 16)
		var captured: StringName = id
		b.pressed.connect(func() -> void: press(captured))
		b.focus_entered.connect(func() -> void: _show_desc(captured))
		b.mouse_entered.connect(func() -> void: _show_desc(captured))
		grid.add_child(b)
		_buttons.append(b)

	_desc_label = _label("", 17, UIPalette.TEXT)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.theme_type_variation = UIFeel.BODY_TEXT
	_desc_label.custom_minimum_size = Vector2(640, 48)
	_desc_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(_desc_label)

	_back = Button.new()
	_back.text = InputPrompts.pick(_COPY.heirloom_back, _COPY.heirloom_back_pad)
	_back.custom_minimum_size = Vector2(200, 44)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.add_theme_font_size_override(&"font_size", 18)
	_back.pressed.connect(close)
	root.add_child(_back)


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
