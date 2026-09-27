## TutorialRoomPanel — the lesson card of the guided first room (ADR-0055).
##
## Bottom centre, like the TutorialCoach toast it replaces on the first run, so it
## never covers the floor title (top) or the prep panel (right). Shows a counter, the
## lesson, a smaller detail line and the hold-to-skip prompt with a fill bar. Pure
## display: TutorialRoom decides what it says.
class_name TutorialRoomPanel
extends PanelContainer

## Card width in px before text scaling; lessons wrap inside it.
const WIDTH: float = 400.0

const _COLOR_HINT := Color(1.0, 0.92, 0.7)
const _COLOR_DONE := UIPalette.GOOD
const _COLOR_COUNT := Color(UIPalette.ACCENT, 0.8)

var _count_label: Label = null
var _hint_label: Label = null
var _detail_label: Label = null
var _skip_label: Label = null
var _skip_bar: ProgressBar = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_bottom = -28.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.08, 0.88)
	style.border_color = Color(UIPalette.ACCENT, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	add_theme_stylebox_override(&"panel", style)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 3)
	add_child(vbox)
	_count_label = _label(12, _COLOR_COUNT)
	vbox.add_child(_count_label)
	_hint_label = _label(18, _COLOR_HINT)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size.x = WIDTH
	vbox.add_child(_hint_label)
	_detail_label = _label(13, UIPalette.TEXT_DIM)
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.custom_minimum_size.x = WIDTH
	vbox.add_child(_detail_label)
	var skip_row := HBoxContainer.new()
	skip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	skip_row.add_theme_constant_override(&"separation", 8)
	vbox.add_child(skip_row)
	_skip_label = _label(11, UIPalette.TEXT_FAINT)
	skip_row.add_child(_skip_label)
	_skip_bar = ProgressBar.new()
	_skip_bar.show_percentage = false
	_skip_bar.custom_minimum_size = Vector2(48.0, 5.0)
	_skip_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_skip_bar.max_value = 1.0
	_skip_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(UIPalette.TEXT_FAINT, 0.3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UIPalette.ACCENT
	_skip_bar.add_theme_stylebox_override(&"background", bg)
	_skip_bar.add_theme_stylebox_override(&"fill", fill)
	skip_row.add_child(_skip_bar)
	visible = false


## Shows a lesson: [param heading] counter, [param hint] line, [param detail] line and
## the [param skip] prompt.
func show_step(heading: String, hint: String, detail: String, skip: String) -> void:
	if _hint_label == null:
		return
	visible = true
	_count_label.text = heading
	_hint_label.text = hint
	_hint_label.add_theme_color_override(&"font_color", _COLOR_HINT)
	_detail_label.text = detail
	_detail_label.visible = detail != ""
	_skip_label.text = skip
	_skip_label.get_parent().visible = true
	UIFeel.fade_in(self)


## Marks the lesson on screen as done (check mark, green).
func tick() -> void:
	if _hint_label == null:
		return
	_hint_label.text = "✔  " + _hint_label.text
	_hint_label.add_theme_color_override(&"font_color", _COLOR_DONE)


## Fills the skip bar to [param ratio] (0..1).
func set_skip_progress(ratio: float) -> void:
	if _skip_bar != null:
		_skip_bar.value = clampf(ratio, 0.0, 1.0)


## Shows [param text] as the final line for [param hold_sec], then fades and frees.
func show_done(text: String, hold_sec: float) -> void:
	if _hint_label == null or not is_inside_tree():
		queue_free()
		return
	visible = true
	_count_label.text = ""
	_hint_label.text = text
	_hint_label.add_theme_color_override(&"font_color", _COLOR_DONE)
	_detail_label.visible = false
	_skip_label.get_parent().visible = false
	var tw: Tween = create_tween()
	tw.tween_interval(hold_sec)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)


## Closes at once (skip).
func close() -> void:
	queue_free()


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
