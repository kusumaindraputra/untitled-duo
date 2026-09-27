## ClearBanner — the big "CLEAR" that punches in when a room is cleared (ADR-0041).
##
## Full-rect, click-through Control added to the HUD CanvasLayer. The word scales in
## from BigMomentTuning.clear_punch_scale with a rule underneath that grows out from
## the centre, holds, then fades and frees itself. Tweens ignore time_scale so it
## reads at full speed through the room clear slow-mo. With Reduce motion it only
## fades: no scale punch, the rule is drawn at full width.
class_name ClearBanner
extends Control

const TUNING: BigMomentTuning = preload("res://assets/data/big_moment_tuning.tres")
const _COPY: UICopy = preload("res://assets/data/ui_copy.tres")
## Font size of the word, before the UIFeel text scale.
const FONT_SIZE: int = 48
## Width of the rule under the word, px.
const RULE_WIDTH: float = 220.0
## Vertical anchor of the word (above the RANK banner at 0.28).
const ANCHOR_Y: float = 0.15

var _label: Label = null
var _rule: ColorRect = null


## Builds the banner with [param text] (defaults to UICopy.room_clear_banner).
## Call before adding it to the tree; [method play] starts it.
func setup(text: String = "") -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.name = "Word"
	_label.text = text if text != "" else _COPY.room_clear_banner
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	_label.add_theme_color_override(&"font_color", UIPalette.ACCENT)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 8)
	_label.anchor_left = 0.0
	_label.anchor_right = 1.0
	_label.anchor_top = ANCHOR_Y
	_label.anchor_bottom = ANCHOR_Y
	_label.offset_bottom = 64.0
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_rule = ColorRect.new()
	_rule.name = "Rule"
	_rule.color = UIPalette.ACCENT
	_rule.anchor_left = 0.5
	_rule.anchor_right = 0.5
	_rule.anchor_top = ANCHOR_Y
	_rule.anchor_bottom = ANCHOR_Y
	_rule.offset_top = 66.0
	_rule.offset_bottom = 69.0
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rule)
	modulate = Color(1, 1, 1, 0)


## The word shown (for tests).
func get_text() -> String:
	return _label.text if _label != null else ""


## Rule half-width at punch progress [param x] (0..1); full at once with reduced motion.
static func rule_half_width(x: float, reduce_motion: bool) -> float:
	if reduce_motion:
		return RULE_WIDTH * 0.5
	var c: float = clampf(x, 0.0, 1.0)
	return RULE_WIDTH * 0.5 * (1.0 - (1.0 - c) * (1.0 - c))


## Runs the punch-in, hold and fade, then frees the banner.
func play() -> void:
	var reduced: bool = GameSettings.motion_reduced()
	_label.pivot_offset = Vector2(_label.size.x * 0.5, 32.0)
	_set_rule(0.0, reduced)
	var tw: Tween = create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(self, "modulate:a", 1.0, TUNING.clear_in_sec)
	if not reduced:
		_label.scale = Vector2.ONE * TUNING.clear_punch_scale
		tw.parallel().tween_property(_label, "scale", Vector2.ONE, TUNING.clear_in_sec) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_method(_set_rule.bind(false), 0.0, 1.0, TUNING.clear_in_sec * 1.6)
	tw.tween_interval(TUNING.clear_hold_sec)
	tw.tween_property(self, "modulate:a", 0.0, TUNING.clear_out_sec)
	tw.tween_callback(queue_free)


func _set_rule(x: float, reduced: bool) -> void:
	if _rule == null:
		return
	var half: float = rule_half_width(x, reduced)
	_rule.offset_left = -half
	_rule.offset_right = half
