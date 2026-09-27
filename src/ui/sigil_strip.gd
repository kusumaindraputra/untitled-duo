## SigilStrip — a row of small chips under the CombatHUD left card showing the run's
## Cipher Core and every sigil taken so far (ADR-0045).
##
## Each chip carries a two-letter tag from the sigil's title ("Ember Wake" → "EW") and
## a stack count when the sigil was taken more than once. The Core chip comes first
## in its accent colour; behaviour sigils get the gold border their reward cards use
## (SigilConfig.behaviour_card_color). When a behaviour sigil fires
## (SigilEffects.effect_fired) its chip lights up for a moment, so the player sees
## which part of the build just did something.
##
## Chips wrap into rows of the given width. Sizes and the pulse length live in
## assets/data/hud_readout_tuning.tres. Tagging and wrapping are static for tests.
class_name SigilStrip
extends Control

## Emitted when the strip's height changes (a row was added or it was cleared).
signal layout_changed

const TUNING: HudReadoutTuning = preload("res://assets/data/hud_readout_tuning.tres")
const _SIGILS: SigilConfig = preload("res://assets/data/sigil_config.tres")

enum Kind { CORE, STAT, BEHAVIOUR }

const CHIP_BG := UIPalette.CARD_SOLID
const STAT_BORDER := UIPalette.BORDER
const PULSE_FILL := Color(1.0, 0.92, 0.7, 0.55)

var tuning: HudReadoutTuning = TUNING
## Row width the chips wrap to, in px.
var max_width: float = 208.0

## [{id, tag, color, kind, stacks}] in pick order, Core first.
var _chips: Array[Dictionary] = []
## id → seconds of pulse left.
var _pulse: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Two-letter tag for [param title]: initials of the first two words, or the first
## two letters of a one-word title. Upper case; "" for an empty title.
static func tag_for(title: String) -> String:
	var words: PackedStringArray = title.strip_edges().split(" ", false)
	if words.is_empty():
		return ""
	if words.size() == 1:
		return words[0].left(2).to_upper()
	return (words[0].left(1) + words[1].left(1)).to_upper()


## Number of rows [param count] chips need at [param width] px per row.
static func rows_for(count: int, width: float, chip: float, gap: float) -> int:
	if count <= 0:
		return 0
	var per_row: int = maxi(int(floor((width + gap) / (chip + gap))), 1)
	return ceili(float(count) / float(per_row))


## Height in px for the current chips (0 when empty).
func strip_height() -> float:
	var rows: int = rows_for(_chips.size(), max_width, tuning.strip_chip_size, tuning.strip_chip_gap)
	return 0.0 if rows == 0 else rows * tuning.strip_chip_size + (rows - 1) * tuning.strip_chip_gap


## Clears every chip (new run).
func reset() -> void:
	_chips.clear()
	_pulse.clear()
	_changed()


## Puts the run's Core first. Replaces an earlier Core chip.
func set_core(id: StringName, title: String, accent: Color) -> void:
	for i: int in _chips.size():
		if _chips[i]["kind"] == Kind.CORE:
			_chips.remove_at(i)
			break
	_chips.insert(0, {"id": id, "tag": tag_for(title), "color": accent, "kind": Kind.CORE, "stacks": 1})
	_changed()


## Adds [param id] or one more stack of it.
func add_sigil(id: StringName, title: String, behaviour: bool) -> void:
	for chip: Dictionary in _chips:
		if chip["id"] == id and chip["kind"] != Kind.CORE:
			chip["stacks"] = int(chip["stacks"]) + 1
			queue_redraw()
			return
	var color: Color = _SIGILS.behaviour_card_color if behaviour else STAT_BORDER
	_chips.append({"id": id, "tag": tag_for(title), "color": color,
		"kind": Kind.BEHAVIOUR if behaviour else Kind.STAT, "stacks": 1})
	_changed()


## Lights up the chip of [param id]. No-op for an id without a chip.
func pulse(id: StringName) -> void:
	if not has_chip(id):
		return
	_pulse[id] = tuning.strip_pulse_sec
	queue_redraw()


func has_chip(id: StringName) -> bool:
	for chip: Dictionary in _chips:
		if chip["id"] == id:
			return true
	return false


func chip_count() -> int:
	return _chips.size()


## Copy of the chip list (test hook).
func get_chips() -> Array[Dictionary]:
	return _chips.duplicate(true)


func is_pulsing(id: StringName) -> bool:
	return float(_pulse.get(id, 0.0)) > 0.0


## Advances pulses by [param delta] seconds (public so tests can step it).
func tick(delta: float) -> void:
	if _pulse.is_empty():
		return
	for id: Variant in _pulse.keys():
		var left: float = float(_pulse[id]) - delta
		if left <= 0.0:
			_pulse.erase(id)
		else:
			_pulse[id] = left
	queue_redraw()


func _process(delta: float) -> void:
	tick(delta)


func _changed() -> void:
	size = Vector2(max_width, strip_height())
	queue_redraw()
	layout_changed.emit()


func _draw() -> void:
	var chip: float = tuning.strip_chip_size
	var gap: float = tuning.strip_chip_gap
	var per_row: int = maxi(int(floor((max_width + gap) / (chip + gap))), 1)
	var font: Font = get_theme_default_font()
	var fs: int = int(chip * 0.46)
	var small: int = int(chip * 0.36)
	for i: int in _chips.size():
		var c: Dictionary = _chips[i]
		var pos := Vector2((i % per_row) * (chip + gap), (i / per_row) * (chip + gap))
		var r := Rect2(pos, Vector2(chip, chip))
		var accent: Color = c["color"]
		draw_rect(r, CHIP_BG)
		var left: float = float(_pulse.get(c["id"], 0.0))
		if left > 0.0:
			var a: float = clampf(left / maxf(tuning.strip_pulse_sec, 0.001), 0.0, 1.0)
			draw_rect(r, Color(PULSE_FILL, PULSE_FILL.a * a))
		var border_w: float = 2.0 if c["kind"] == Kind.CORE else 1.0
		draw_rect(r.grow(-border_w * 0.5), accent, false, border_w)
		if font == null:
			continue
		var tag: String = c["tag"]
		var text_color: Color = accent.lerp(UIPalette.TEXT, 0.35) if c["kind"] != Kind.STAT else UIPalette.TEXT
		draw_string(font, pos + Vector2(0.0, chip * 0.5 + fs * 0.35), tag,
			HORIZONTAL_ALIGNMENT_CENTER, chip, fs, text_color)
		var stacks: int = c["stacks"]
		if stacks > 1:
			draw_string(font, pos + Vector2(0.0, chip - 1.0), str(stacks),
				HORIZONTAL_ALIGNMENT_RIGHT, chip - 2.0, small, UIPalette.ACCENT)
