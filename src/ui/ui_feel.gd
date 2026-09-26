## UIFeel — menu sounds, screen fades and typewriter timing (beta plan U9).
##
## Autoload. Every Button that enters the tree gets a confirm sound on press, focus
## moves play a soft tick, and ui_cancel plays a back sound. All three go through
## AudioSystem.play_event (UI bus), so the UI volume slider covers them. Focus changes
## in the first frames after new UI appears are silent, so opening a screen (which
## grabs focus) does not tick.
##
## [method fade_in] and [method typewriter_chars] are shared by the overlays; both
## respect the Reduce motion setting (GameSettings.motion_reduced()).
##
## Text size (ADR-0032): every Label, Button, LineEdit and RichTextLabel that enters the
## tree has its font sizes multiplied by GameSettings.text_scale() one frame later (so
## overrides set right after add_child count). The unscaled sizes are kept in meta, so
## [method apply_text_scale_tree] can rescale open screens when the setting changes.
##
## Fonts (ADR-0035): the theme's default font is the DotGothic16 pixel font. Labels
## that carry long prose set [code]theme_type_variation = UIFeel.BODY_TEXT[/code] to
## use the easier-to-read body font instead; RichTextLabel uses it by default.
extends Node

## Theme type variation for long prose labels (body font, see assets/ui/game_theme.tres).
const BODY_TEXT: StringName = &"BodyLabel"
## Audio events, registered in assets/data/audio_event_registry.tres.
const EVENT_FOCUS: StringName = &"ui_focus"
const EVENT_CONFIRM: StringName = &"ui_confirm"
const EVENT_BACK: StringName = &"ui_back"
## Frames after UI appears during which focus changes stay silent.
const SETTLE_FRAMES: int = 2
## Default fade-in length for overlays, seconds.
const FADE_TIME: float = 0.18
## Typewriter speed, characters per second.
const TYPE_CPS: float = 55.0
## Buttons with this meta set to true make no confirm sound (they play their own).
const SILENT_META: StringName = &"ui_silent"
const _WIRED_META: StringName = &"_ui_feel_wired"
## Meta holding a Control's unscaled font sizes and the scale last applied.
const BASE_SIZES_META: StringName = &"_text_base_sizes"
const APPLIED_SCALE_META: StringName = &"_text_applied_scale"
const _RICH_FONT_SIZES: Array[StringName] = [
	&"normal_font_size", &"bold_font_size", &"italics_font_size", &"bold_italics_font_size", &"mono_font_size",
]
const _PLAIN_FONT_SIZES: Array[StringName] = [&"font_size"]

var _last_ui_frame: int = -100


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		_play(EVENT_BACK)


## True when a focus change at [param frame] should tick: UI that appeared at
## [param last_ui_frame] has had [constant SETTLE_FRAMES] frames to settle.
static func should_play_focus(frame: int, last_ui_frame: int) -> bool:
	return frame - last_ui_frame > SETTLE_FRAMES


## Characters to show [param elapsed] seconds into typing [param total] characters.
## Returns [param total] once done, or at once when motion is reduced.
static func typewriter_chars(elapsed: float, total: int, reduced: bool = false) -> int:
	if reduced:
		return total
	return clampi(int(elapsed * TYPE_CPS), 0, total)


## Fades [param item] in from transparent over [param duration] seconds, also while
## the tree is paused. With Reduce motion on it is shown at once and null is returned.
static func fade_in(item: CanvasItem, duration: float = FADE_TIME) -> Tween:
	if GameSettings.motion_reduced() or duration <= 0.0 or not item.is_inside_tree():
		item.modulate.a = 1.0
		return null
	item.modulate.a = 0.0
	var tw: Tween = item.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(item, "modulate:a", 1.0, duration)
	return tw


## Theme font-size names that carry [param c]'s text ([] for controls without text).
static func font_size_names(c: Control) -> Array[StringName]:
	if c is RichTextLabel:
		return _RICH_FONT_SIZES
	if c is Label or c is Button or c is LineEdit:
		return _PLAIN_FONT_SIZES
	return []


## Sets [param c]'s font sizes to its unscaled sizes × [param scale]. The first call
## records the unscaled sizes; a size changed by code since the last call becomes the
## new unscaled size. No-op at scale 1 on a control never scaled.
static func apply_text_scale(c: Control, scale: float) -> void:
	var names: Array[StringName] = font_size_names(c)
	if names.is_empty():
		return
	if not c.has_meta(BASE_SIZES_META) and is_equal_approx(scale, 1.0):
		return
	var base: Dictionary = c.get_meta(BASE_SIZES_META, {})
	var applied: float = float(c.get_meta(APPLIED_SCALE_META, 1.0))
	for n: StringName in names:
		var cur: int = c.get_theme_font_size(n)
		if not base.has(n) or cur != roundi(float(base[n]) * applied):
			base[n] = cur
		c.add_theme_font_size_override(n, maxi(1, roundi(float(base[n]) * scale)))
	c.set_meta(BASE_SIZES_META, base)
	c.set_meta(APPLIED_SCALE_META, scale)


## Applies [param scale] to [param root] and every Control below it.
static func apply_text_scale_tree(root: Node, scale: float) -> void:
	var c := root as Control
	if c != null:
		apply_text_scale(c, scale)
	for child: Node in root.get_children():
		apply_text_scale_tree(child, scale)


## Centres [param content] (a non-container child of a CanvasLayer or full-screen
## Control) at its minimum size, shrunk just enough to fit the viewport minus
## [param margin] on each side. Keeps large text sizes from pushing a screen past the
## window edge (ADR-0032). Returns the scale used.
## [param left] >= 0 pins its left edge there instead of centring it horizontally, and
## [param bottom_reserve] keeps that many px free at the bottom.
static func fit_to_viewport(content: Control, margin: float = 12.0, left: float = -1.0,
		bottom_reserve: float = 0.0) -> float:
	if not content.is_inside_tree():
		return 1.0
	var vp: Vector2 = content.get_viewport().get_visible_rect().size
	content.set_anchors_preset(Control.PRESET_TOP_LEFT)
	content.size = Vector2.ZERO
	var need: Vector2 = content.get_combined_minimum_size()
	var fit: float = fit_scale(need, vp, margin, left, bottom_reserve)
	content.size = need
	content.scale = Vector2(fit, fit)
	var shown: Vector2 = need * fit
	var bottom: float = vp.y - margin - bottom_reserve
	content.position = Vector2(
		left if left >= 0.0 else (vp.x - shown.x) * 0.5,
		maxf(margin, minf((vp.y - shown.y) * 0.5, bottom - shown.y)))
	return fit


## Scale (at most 1) that fits [param need] into [param vp] less the margins; see
## [method fit_to_viewport].
static func fit_scale(need: Vector2, vp: Vector2, margin: float, left: float = -1.0,
		bottom_reserve: float = 0.0) -> float:
	if need.x <= 0.0 or need.y <= 0.0:
		return 1.0
	var room_x: float = vp.x - margin - (left if left >= 0.0 else margin)
	var room_y: float = vp.y - margin * 2.0 - bottom_reserve
	return clampf(minf(room_x / need.x, room_y / need.y), 0.1, 1.0)


func _scale_text_later(c: Control) -> void:
	if is_instance_valid(c):
		apply_text_scale(c, GameSettings.text_scale())


func _on_node_added(node: Node) -> void:
	if node is Control:
		_last_ui_frame = Engine.get_process_frames()
		if not is_equal_approx(GameSettings.text_scale(), 1.0) \
				and not font_size_names(node as Control).is_empty():
			_scale_text_later.call_deferred(node)
	var b := node as BaseButton
	# Meta flag, not is_connected(): a re-parented button enters the tree again.
	if b != null and not b.has_meta(_WIRED_META):
		b.set_meta(_WIRED_META, true)
		b.pressed.connect(_on_button_pressed.bind(b))


func _on_button_pressed(b: BaseButton) -> void:
	if is_instance_valid(b) and not bool(b.get_meta(SILENT_META, false)):
		_play(EVENT_CONFIRM)


func _on_focus_changed(_control: Control) -> void:
	if should_play_focus(Engine.get_process_frames(), _last_ui_frame):
		_play(EVENT_FOCUS)


func _play(event_name: StringName) -> void:
	if AudioSystem.has_event(event_name):
		AudioSystem.play_event(event_name)
