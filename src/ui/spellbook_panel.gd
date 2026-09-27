## SpellbookPanel — the codex of spells, reactions, sigils and enemies (beta plan F1).
##
## Opened from the main menu and the pause menu. A row of section tabs on top (Q / E
## or LB / RB switch sections), the section's entries on the left and the focused
## entry on the right. Locked entries show "? ? ?" and a hint on how to find them.
## Keyboard / gamepad navigable, Esc or Back closes it, works while paused.
class_name SpellbookPanel
extends CanvasLayer

## The panel was closed.
signal closed

const _COPY: UICopy = preload("res://assets/data/ui_copy.tres")
const TITLE_COLOR := Color(0.75, 0.6, 1.0)
const LOCKED_COLOR := UIPalette.TEXT_FAINT

## Progress to read. The menu / game loop passes its loaded copy; tests inject their own.
var progress: MetaProgress = null

var _section: Spellbook.Section = Spellbook.Section.SPELLS
var _entries: Array[Dictionary] = []
var _tabs: Array[Button] = []
var _list: VBoxContainer = null
var _detail_title: Label = null
var _detail_sub: Label = null
var _detail_body: Label = null
var _heading: Label = null
var _back: Button = null


func _ready() -> void:
	layer = 42
	process_mode = Node.PROCESS_MODE_ALWAYS
	if progress == null:
		progress = MetaProgress.new()
	_build()
	for child: Node in get_children():
		if child is CanvasItem:
			UIFeel.fade_in(child as CanvasItem)
	show_section(Spellbook.Section.SPELLS)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
		return
	var step: int = 0
	var joy := event as InputEventJoypadButton
	var key := event as InputEventKey
	if joy != null and joy.pressed:
		if joy.button_index == JOY_BUTTON_LEFT_SHOULDER:
			step = -1
		elif joy.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			step = 1
	elif key != null and key.pressed and not key.echo:
		if key.keycode == KEY_Q:
			step = -1
		elif key.keycode == KEY_E:
			step = 1
	if step != 0:
		get_viewport().set_input_as_handled()
		var n: int = Spellbook.Section.size()
		show_section(((int(_section) + step) % n + n) % n as Spellbook.Section)


## Closes the panel and emits [signal closed].
func close() -> void:
	closed.emit()
	queue_free()


## Shows [param section]'s entries and focuses the first one.
func show_section(section: Spellbook.Section) -> void:
	_section = section
	_entries = Spellbook.entries(section, progress)
	for i in _tabs.size():
		_tabs[i].modulate = Color.WHITE if i == int(section) else UIPalette.TEXT_DIM
	for c: Node in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	for i in _entries.size():
		var e: Dictionary = _entries[i]
		var b := Button.new()
		b.text = e["title"]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(280.0, 36.0)
		b.add_theme_font_size_override(&"font_size", 17)
		if not e["known"]:
			b.add_theme_color_override(&"font_color", LOCKED_COLOR)
		b.focus_entered.connect(select_entry.bind(i))
		b.pressed.connect(select_entry.bind(i))
		_list.add_child(b)
	var found: int = _entries.filter(func(x: Dictionary) -> bool: return x["known"]).size()
	_heading.text = "%s    %s  %d / %d" % [_COPY.spellbook_title,
		_COPY.spellbook_sections[int(section)], found, _entries.size()]
	if not _entries.is_empty():
		(_list.get_child(0) as Button).grab_focus()
		select_entry(0)


## Shows entry [param i] of the current section in the detail pane.
func select_entry(i: int) -> void:
	if i < 0 or i >= _entries.size():
		return
	var e: Dictionary = _entries[i]
	_detail_title.text = e["title"]
	_detail_title.add_theme_color_override(&"font_color", TITLE_COLOR if e["known"] else LOCKED_COLOR)
	_detail_sub.text = e["subtitle"]
	_detail_body.text = e["body"]


## Current section. Test seam.
func current_section() -> Spellbook.Section:
	return _section


## Detail title text. Test seam.
func detail_title() -> String:
	return _detail_title.text


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.06, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 40)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override(&"separation", 14)
	margin.add_child(root)

	_heading = _label(32, TITLE_COLOR)
	root.add_child(_heading)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(&"separation", 8)
	root.add_child(tabs)
	for i in _COPY.spellbook_sections.size():
		var t := Button.new()
		t.text = _COPY.spellbook_sections[i]
		t.custom_minimum_size = Vector2(140.0, 38.0)
		t.add_theme_font_size_override(&"font_size", 17)
		t.focus_mode = Control.FOCUS_NONE
		t.pressed.connect(func() -> void: show_section(i as Spellbook.Section))
		tabs.add_child(t)
		_tabs.append(t)
	var hint := _label(14, UIPalette.TEXT_FAINT)
	hint.text = InputPrompts.pick(_COPY.spellbook_tabs_hint, _COPY.spellbook_tabs_hint_pad)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tabs.add_child(hint)

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"separation", 32)
	root.add_child(row)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300.0, 0.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 4)
	scroll.add_child(_list)

	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override(&"separation", 10)
	row.add_child(detail)
	_detail_title = _label(30, TITLE_COLOR)
	detail.add_child(_detail_title)
	_detail_sub = _label(16, UIPalette.TEXT_DIM)
	detail.add_child(_detail_sub)
	_detail_body = _label(19, UIPalette.TEXT)
	_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_body.theme_type_variation = UIFeel.BODY_TEXT
	_detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(_detail_body)

	_back = Button.new()
	_back.text = InputPrompts.pick(_COPY.spellbook_back, _COPY.spellbook_back_pad)
	_back.custom_minimum_size = Vector2(200.0, 42.0)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_back.add_theme_font_size_override(&"font_size", 18)
	_back.pressed.connect(close)
	root.add_child(_back)


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	return l
