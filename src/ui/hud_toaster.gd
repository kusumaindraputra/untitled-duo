## HudToaster — short corner toasts for things gained mid-run (ADR-0046).
##
## A sigil taken, a memory fragment found or bonus Cipher Shards each push one small
## card into the bottom-left corner, above the run timer when it shows. Cards stack upwards, stay for hold_sec, then fade;
## beyond max_visible they wait in a queue, so a burst never covers the room.
##
## Pausable on purpose: while the sigil offer, a memory card or the pause menu holds
## the tree, toasts neither age nor appear, so none expires unseen behind a modal.
## Ages advance in _process (ADR-0004 float accumulators) and alpha_at / offset_at are
## pure, so tests step the toaster with tick() instead of waiting.
##
## Size follows GameSettings HUD scale and card opacity through refresh_hud_prefs(),
## which the Settings panel calls on the "hud_prefs" group.
class_name HudToaster
extends Control

const TUNING: HudToastTuning = preload("res://assets/data/hud_toast_tuning.tres")
## Group the Settings panel calls refresh_hud_prefs() on.
const HUD_PREFS_GROUP: StringName = &"hud_prefs"

## Queued toasts not shown yet: {"text": String, "color": Color}.
var _queue: Array[Dictionary] = []
## Shown toasts, oldest first: {"card": PanelContainer, "age": float}.
var _live: Array[Dictionary] = []
var _hud_scale: float = 1.0
## Returns px to keep clear above the bottom edge (the run timer). Unset = none.
var bottom_inset: Callable = Callable()
var _card_alpha: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group(HUD_PREFS_GROUP)
	refresh_hud_prefs()


func _process(delta: float) -> void:
	tick(delta)


## Queues a toast with [param text], its edge and text tinted [param color].
func push(text: String, color: Color = UIPalette.ACCENT) -> void:
	if text.is_empty():
		return
	_queue.append({"text": text, "color": color})
	while _queue.size() > maxi(TUNING.max_queued, 1):
		_queue.pop_front()
	_show_queued()


## Advances every toast by [param delta] seconds, frees finished ones and shows
## queued ones in their place. Test seam; _process calls it every frame.
func tick(delta: float) -> void:
	var life: float = lifetime()
	for i: int in range(_live.size() - 1, -1, -1):
		var t: Dictionary = _live[i]
		t["age"] = float(t["age"]) + delta
		if float(t["age"]) >= life:
			(t["card"] as Node).free()
			_live.remove_at(i)
	_show_queued()
	_layout()


## Re-reads HUD scale and card opacity from GameSettings and restyles live toasts.
func refresh_hud_prefs() -> void:
	_hud_scale = GameSettings.hud_scale()
	_card_alpha = GameSettings.hud_card_alpha()
	for t: Dictionary in _live:
		_style_card(t["card"] as PanelContainer, t.get("color", UIPalette.ACCENT) as Color)
	_layout()


## Toasts on screen now.
func visible_count() -> int:
	return _live.size()


## Toasts waiting for a free slot.
func queued_count() -> int:
	return _queue.size()


## Text of the toasts on screen, oldest first (test / QA hook).
func visible_texts() -> Array[String]:
	var out: Array[String] = []
	for t: Dictionary in _live:
		out.append(str(t["text"]))
	return out


## Seconds a toast lives from slide-in to the end of its fade.
static func lifetime() -> float:
	return TUNING.in_sec + TUNING.hold_sec + TUNING.out_sec


## Pure: opacity of a toast [param age] seconds old.
static func alpha_at(age: float, in_sec: float, hold_sec: float, out_sec: float) -> float:
	if age < 0.0:
		return 0.0
	if age < in_sec:
		return age / maxf(in_sec, 0.001)
	var fade_start: float = in_sec + hold_sec
	if age < fade_start:
		return 1.0
	return clampf(1.0 - (age - fade_start) / maxf(out_sec, 0.001), 0.0, 1.0)


## Pure: horizontal slide offset in px of a toast [param age] seconds old. Starts
## [param slide_px] to the left and eases in; zero once in or with reduced motion.
static func offset_at(age: float, in_sec: float, slide_px: float, reduced: bool) -> float:
	if reduced or in_sec <= 0.0 or age >= in_sec:
		return 0.0
	var t: float = clampf(age / in_sec, 0.0, 1.0)
	return -slide_px * (1.0 - t) * (1.0 - t)


func _show_queued() -> void:
	while not _queue.is_empty() and _live.size() < maxi(TUNING.max_visible, 1):
		var q: Dictionary = _queue.pop_front()
		var card := _make_card(str(q["text"]), q["color"] as Color)
		_live.append({"card": card, "age": 0.0, "text": q["text"], "color": q["color"]})


func _make_card(text: String, color: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", TUNING.font_size)
	label.add_theme_color_override(&"font_color", UIPalette.TEXT)
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override(&"outline_size", 3)
	card.add_child(label)
	_style_card(card, color)
	card.modulate.a = 0.0
	add_child(card)
	return card


## Card background at the player's HUD card opacity, with a left edge in [param color].
func _style_card(card: PanelContainer, color: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UIPalette.CARD_SOLID, UIPalette.CARD_SOLID.a * _card_alpha)
	box.border_color = color
	box.border_width_left = 3
	box.set_corner_radius_all(4)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	card.add_theme_stylebox_override(&"panel", box)


## Stacks live toasts upward from the bottom-left corner, newest at the bottom.
func _layout() -> void:
	var view: Vector2 = get_viewport_rect().size if is_inside_tree() else Vector2(1152, 648)
	var y: float = view.y - TUNING.margin
	if bottom_inset.is_valid():
		y -= float(bottom_inset.call())
	var reduced: bool = GameSettings.motion_reduced()
	for i: int in range(_live.size() - 1, -1, -1):
		var t: Dictionary = _live[i]
		var card := t["card"] as PanelContainer
		var age: float = float(t["age"])
		card.scale = Vector2(_hud_scale, _hud_scale)
		card.size = card.get_combined_minimum_size()
		var h: float = card.size.y * _hud_scale
		y -= h
		card.position = Vector2(TUNING.margin + offset_at(age, TUNING.in_sec, TUNING.slide_px, reduced), y)
		# Reduce motion: the card appears at once instead of sliding and fading in.
		var in_sec: float = 0.0 if reduced else TUNING.in_sec
		card.modulate.a = alpha_at(age, in_sec, TUNING.hold_sec + TUNING.in_sec - in_sec, TUNING.out_sec)
		y -= TUNING.gap
