## memory_fragment_modal.gd — Full-screen card that shows a recovered memory or an ending.
##
## Pauses the tree while open and restores the previous pause state when it closes
## (or is freed). Input is ignored for a short grace period so a cast or dash held
## at the moment a boss dies does not skip the text. Then any key, click or gamepad
## button closes it and emits [signal closed]. The body types out (U9); a press while it
## is typing shows it all instead of closing. Reduce motion shows it at once.
##
## Three ways to fill it (call one before add_child()):
## [method setup_fragment] for a story fragment, [method setup_ending] for an ending,
## and [method setup] for an anchor object's memory id (LD-23).
##
## Design: design/gdd/memory-fragments.md · ADR-0027
class_name MemoryFragmentModal
extends CanvasLayer

## The player dismissed the card.
signal closed

const _COPY: UICopy = preload("res://assets/data/ui_copy.tres")

## Seconds before input can dismiss the card.
const INPUT_GRACE_SEC: float = 0.6

var _memory_id: StringName = &""
var _header: String = ""
var _voice: String = ""
var _title: String = ""
var _body: String = ""
var _footnote: String = ""
var _accent: Color = Color(0.55, 0.85, 1.0)

## Body text, typed out a character at a time (U9); a press finishes it at once.
var _body_label: Label = null
var _type_time: float = 0.0
var _typing: bool = false

var _was_paused: bool = false
var _age: float = 0.0
var _closed: bool = false


## Anchor-object path: shows the story fragment with [param memory_id] if there is
## one, otherwise a short "a memory stirs" card.
func setup(memory_id: StringName) -> void:
	_memory_id = memory_id
	var idx: int = StoryRules.index_of(memory_id)
	if idx >= 0:
		setup_fragment(StoryRules.fragment_at(idx), idx, StoryRules.total())
		return
	_header = _COPY.memory_header
	_title = _COPY.memory_unknown_title
	_body = _COPY.memory_unknown_body


## Shows [param fragment], which sits at 0-based [param index] of a
## [param total]-fragment story.
func setup_fragment(fragment: MemoryFragment, index: int, total: int) -> void:
	if fragment == null:
		setup(&"")
		return
	_memory_id = fragment.id
	_header = _COPY.memory_header
	_voice = fragment.voice
	_title = fragment.title
	_body = fragment.body
	_footnote = _COPY.memory_count_format % [index + 1, total]


## Shows an ending. [param found] of [param total] fragments are recovered; the
## partial ending adds a line saying how many are still missing.
func setup_ending(ending: MemoryFragment, is_true: bool, found: int, total: int) -> void:
	_header = _COPY.ending_true_header if is_true else _COPY.ending_header
	_accent = UIPalette.ACCENT
	if ending != null:
		_memory_id = ending.id
		_voice = ending.voice
		_title = ending.title
		_body = ending.body
	if not is_true:
		_footnote = _COPY.ending_partial_hint_format % [found, total]


## Memory id this card shows (&"" when it has none).
func get_memory_id() -> StringName:
	return _memory_id


## Title shown on the card (test seam).
func get_title() -> String:
	return _title


## Footnote under the text (test seam).
func get_footnote() -> String:
	return _footnote


## True while the body text is still being typed out (test seam).
func is_typing() -> bool:
	return _typing


## Shows the whole body at once. Called on the first press while typing.
func finish_typing() -> void:
	_typing = false
	if _body_label != null:
		_body_label.visible_characters = -1


## True once the input grace period has passed.
func can_dismiss() -> bool:
	return _age >= INPUT_GRACE_SEC


## Closes the card, restores the pause state and emits [signal closed]. Idempotent.
func close() -> void:
	if _closed:
		return
	_closed = true
	if is_inside_tree():
		get_tree().paused = _was_paused
	closed.emit()
	queue_free()


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	get_tree().paused = true
	_build_ui()


func _exit_tree() -> void:
	# Freed without close() (scene change, test teardown): never leave the tree paused.
	if not _closed:
		_closed = true
		get_tree().paused = _was_paused


func _process(delta: float) -> void:
	_age += delta
	if _typing:
		_type_time += delta
		var total: int = _body_label.get_total_character_count()
		var shown: int = UIFeel.typewriter_chars(_type_time, total)
		_body_label.visible_characters = shown
		if shown >= total:
			finish_typing()


func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventKey and event.pressed and not event.is_echo()) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if _typing:
		finish_typing()
	elif can_dismiss():
		close()


# ── Private ───────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(760.0, 0.0)
	vbox.add_theme_constant_override(&"separation", 14)
	center.add_child(vbox)

	vbox.add_child(_make_label(_header, 16, _accent.darkened(0.15)))
	if not _voice.is_empty():
		vbox.add_child(_make_label(_voice.to_upper(), 15, UIPalette.TEXT_DIM))

	var title := _make_label(_title, 40, _accent)
	vbox.add_child(title)

	var line := ColorRect.new()
	line.color = Color(_accent, 0.5)
	line.custom_minimum_size = Vector2(240.0, 2.0)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(line)

	var body := _make_label(_body, 21, Color(0.9, 0.9, 0.93))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.theme_type_variation = UIFeel.BODY_TEXT
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body.custom_minimum_size = Vector2(760.0, 0.0)
	vbox.add_child(body)
	_body_label = body
	_typing = not GameSettings.motion_reduced() and not _body.is_empty()
	if _typing:
		# Lay out the full text first so the card does not grow line by line.
		body.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
		body.visible_characters = 0

	if not _footnote.is_empty():
		var foot := _make_label(_footnote, 16, UIPalette.ACCENT_DIM)
		foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		foot.theme_type_variation = UIFeel.BODY_TEXT
		vbox.add_child(foot)

	vbox.add_child(_make_label(_COPY.memory_continue_hint, 15, UIPalette.TEXT_FAINT))

	# Fade in so the card reads as a memory surfacing, not a menu popping.
	# Reduce motion shows it at once (UIFeel.fade_in).
	for child: Node in [dim, center]:
		UIFeel.fade_in(child as CanvasItem, 0.5)


func _make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	return l
