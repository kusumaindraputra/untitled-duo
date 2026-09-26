## MemoriesPanel — archive of recovered memory fragments and seen endings (ADR-0027).
##
## Opened from the main menu. The left column lists every fragment in story order
## (locked ones as "? ? ?") plus any ending already seen; focusing or pressing an
## entry shows its text on the right. Keyboard / gamepad navigable, Esc or Back
## closes it, and it works while the tree is paused (PROCESS_MODE_ALWAYS).
##
## Design: design/gdd/memory-fragments.md
class_name MemoriesPanel
extends CanvasLayer

## The panel was closed.
signal closed

const _COPY: UICopy = preload("res://assets/data/ui_copy.tres")

## Progress to read. Tests inject their own; the menu passes its loaded copy.
var progress: MetaProgress = null
## Story to list. Defaults to the shipped story.
var story: StoryConfig = StoryRules.CONFIG

var _entries: Array[Button] = []
var _detail_title: Label = null
var _detail_voice: Label = null
var _detail_body: Label = null
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
	if not _entries.is_empty():
		_entries[0].grab_focus()
		_show_entry(0)
	else:
		_back.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Closes the panel and emits [signal closed].
func close() -> void:
	closed.emit()
	queue_free()


## Number of list entries (fragments plus seen endings). Test seam.
func entry_count() -> int:
	return _entries.size()


## Text of list entry [param i]. Test seam.
func entry_text(i: int) -> String:
	return _entries[i].text if i >= 0 and i < _entries.size() else ""


## Title currently shown in the detail pane. Test seam.
func detail_title() -> String:
	return _detail_title.text if _detail_title != null else ""


## Shows entry [param i] in the detail pane.
func select_entry(i: int) -> void:
	_show_entry(i)


# ── Private ───────────────────────────────────────────────────────────────────

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.06, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 48)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override(&"separation", 16)
	margin.add_child(root)

	var found: int = mini(progress.fragments_found, story.fragments.size())
	var heading := Label.new()
	heading.text = "%s    %d / %d" % [_COPY.memories_title, found, story.fragments.size()]
	heading.add_theme_font_size_override(&"font_size", 36)
	heading.add_theme_color_override(&"font_color", Color(0.55, 0.85, 1.0))
	root.add_child(heading)

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"separation", 32)
	root.add_child(row)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(320.0, 0.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override(&"separation", 6)
	scroll.add_child(list)

	for i: int in story.fragments.size():
		var unlocked: bool = i < found
		var frag: MemoryFragment = story.fragments[i]
		var label: String = frag.title if unlocked and frag != null else _COPY.memories_locked
		_add_entry(list, "%d.  %s" % [i + 1, label])
	if progress.ending_seen:
		_add_entry(list, _COPY.memories_ending_label)
	if progress.true_ending_seen:
		_add_entry(list, _COPY.memories_true_ending_label)

	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override(&"separation", 12)
	row.add_child(detail)

	_detail_voice = _make_label(15, Color(0.6, 0.62, 0.7))
	detail.add_child(_detail_voice)
	_detail_title = _make_label(32, Color(0.55, 0.85, 1.0))
	detail.add_child(_detail_title)
	_detail_body = _make_label(20, Color(0.88, 0.88, 0.92))
	_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_body.theme_type_variation = UIFeel.BODY_TEXT
	_detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(_detail_body)

	_back = Button.new()
	_back.text = _COPY.memories_back
	_back.custom_minimum_size = Vector2(200.0, 44.0)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_back.add_theme_font_size_override(&"font_size", 20)
	_back.pressed.connect(close)
	root.add_child(_back)


func _add_entry(list: VBoxContainer, text: String) -> void:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(300.0, 40.0)
	b.add_theme_font_size_override(&"font_size", 18)
	var idx: int = _entries.size()
	b.focus_entered.connect(_show_entry.bind(idx))
	b.pressed.connect(_show_entry.bind(idx))
	list.add_child(b)
	_entries.append(b)


## Resolves list position [param i] to a fragment, an ending or a locked slot.
func _show_entry(i: int) -> void:
	var count: int = story.fragments.size()
	var found: int = mini(progress.fragments_found, count)
	var frag: MemoryFragment = null
	if i < count:
		if i < found:
			frag = story.fragments[i]
	else:
		var endings: Array[MemoryFragment] = []
		if progress.ending_seen:
			endings.append(story.ending_partial)
		if progress.true_ending_seen:
			endings.append(story.ending_true)
		if i - count < endings.size():
			frag = endings[i - count]
	if frag == null:
		_detail_voice.text = ""
		_detail_title.text = _COPY.memories_locked
		_detail_body.text = _COPY.memories_locked_body
		return
	_detail_voice.text = frag.voice.to_upper()
	_detail_title.text = frag.title
	_detail_body.text = frag.body


func _make_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	return l
