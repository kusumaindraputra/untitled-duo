## WhimsyDetail — one small, animated, non-gameplay detail per room (ADR-0038).
##
## Art bible Principle 3 ("Whimsy lives in the details"): every room has one thing
## with no gameplay function that rewards a player who pauses to look. Drawn with
## integer rects in the floor's prop palette, so it stays crisp pixel art. It owns
## no collision and never takes input. With reduce motion on it holds a still pose.
class_name WhimsyDetail
extends Node2D

## Which detail this is (RoomLook.Whimsy).
var kind: int = RoomLook.Whimsy.MOSS_BREATH
## Palette: outline, body, light, glow.
var dark: Color = Color("#231E1A")
var mid: Color = Color("#5C5040")
var light: Color = Color("#7E6E58")
var glow: Color = Color("#8E7358")

var _t: float = 0.0
## Phase offset so two rooms with the same detail do not animate in lockstep.
var _phase: float = 0.0


## Sets up the detail from [param look]. [param phase] offsets its animation clock.
func setup(whimsy: int, look: RoomLook, phase: float = 0.0) -> void:
	kind = whimsy
	dark = look.prop_dark
	mid = look.prop_mid
	light = look.prop_light
	glow = look.prop_glow
	_phase = phase
	name = "Whimsy_%s" % str(RoomLook.Whimsy.keys()[kind]).to_pascal_case()


func _process(delta: float) -> void:
	if GameSettings.motion_reduced():
		return
	_t += delta
	queue_redraw()


## Animation clock in seconds (phase-shifted).
func clock() -> float:
	return _t + _phase


func _draw() -> void:
	var t: float = clock()
	match kind:
		RoomLook.Whimsy.MOSS_BREATH: _draw_moss(t)
		RoomLook.Whimsy.SCRAP_CRITTER: _draw_critter(t)
		RoomLook.Whimsy.KETTLE_SPROUT: _draw_kettle(t)
		RoomLook.Whimsy.STEAM_VENT: _draw_vent(t)
		RoomLook.Whimsy.LAMP_MOTH: _draw_lamp(t)
		RoomLook.Whimsy.CRYSTAL_CHIME: _draw_chime(t)
		RoomLook.Whimsy.SPORE_PUFF: _draw_spores(t)


func _px(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(roundf(x), roundf(y), roundf(w), roundf(h)), c)


func _faded(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * clampf(a, 0.0, 1.0))


## Moss mound that slowly breathes, with two glowing specks.
func _draw_moss(t: float) -> void:
	var breath: int = int(floor((sin(t * 1.6) + 1.0) * 1.5))  # 0–3 px
	_px(-8, -3 - breath, 16, 3 + breath, dark)
	_px(-7, -2 - breath, 14, 2 + breath, mid)
	_px(-5, -3 - breath, 6, 1, light)
	_px(-3, -4 - breath, 1, 1, glow)
	_px(4, -3 - breath, 1, 1, glow)


## A tin beetle peeking out from behind a tiny junk pile, blinking, then hiding.
func _draw_critter(t: float) -> void:
	var c: float = fmod(t, 7.0)
	var rise: float = 0.0
	if c > 3.5 and c < 4.0:
		rise = (c - 3.5) / 0.5
	elif c >= 4.0 and c < 6.3:
		rise = 1.0
	elif c >= 6.3 and c < 6.6:
		rise = 1.0 - (c - 6.3) / 0.3
	var look_x: float = -1.0 if fmod(c, 1.4) < 0.7 else 1.0
	var y: float = -3.0 - rise * 5.0
	if rise > 0.0:
		_px(-4, y - 1, 8, 5, dark)
		_px(-3, y, 6, 3, mid)
		_px(-2, y, 3, 1, light)
		_px(-4, y - 3, 1, 2, dark)  # antennae
		_px(3, y - 3, 1, 2, dark)
		if not (c > 5.0 and c < 5.15):  # blink
			_px(look_x * 2.0, y + 1, 1, 1, glow)
	# The pile it hides behind, drawn last so it stays in front.
	_px(-7, -4, 14, 4, dark)
	_px(-6, -3, 12, 3, mid)
	_px(-5, -4, 3, 1, light)
	_px(2, -5, 4, 1, light)


## A rusted kettle with a two-leaf sprout growing out of the spout, swaying.
func _draw_kettle(t: float) -> void:
	_px(-6, -8, 12, 8, dark)
	_px(-5, -7, 10, 6, mid)
	_px(-4, -7, 3, 5, light)
	_px(-2, -10, 4, 2, dark)  # lid
	_px(6, -7, 3, 2, dark)    # spout
	var sway: float = roundf(sin(t * 1.2) * 1.0)
	_px(8 + sway * 0.5, -11, 1, 4, mid)
	_px(6 + sway, -12, 2, 1, glow)
	_px(9 + sway, -13, 2, 1, glow)


## A pipe stub that exhales three puffs of steam every few seconds.
func _draw_vent(t: float) -> void:
	_px(-3, -8, 6, 8, dark)
	_px(-2, -8, 4, 8, mid)
	_px(-2, -8, 1, 8, light)
	_px(-4, -9, 8, 2, dark)
	var c: float = fmod(t, 3.6)
	for i: int in 3:
		var age: float = c - i * 0.25
		if age < 0.0 or age > 1.6:
			continue
		var y: float = -11.0 - age * 14.0
		var s: float = 2.0 + age * 2.0
		_px(-s * 0.5 + sin(age * 3.0 + i) * 2.0, y, s, s, _faded(light, 0.7 * (1.0 - age / 1.6)))


## A flickering bulb on a bent bracket with a moth circling it.
func _draw_lamp(t: float) -> void:
	_px(-1, -14, 2, 14, dark)
	_px(-1, -15, 6, 2, dark)
	var flick: float = 0.75 + 0.25 * sin(t * 9.0) * sin(t * 2.3)
	_px(1, -17, 7, 7, _faded(glow, 0.25 * flick))
	_px(3, -14, 3, 3, _faded(glow, flick))
	var a: float = t * 3.1
	var mx: float = 4.5 + cos(a) * 7.0
	var my: float = -13.0 + sin(a * 1.7) * 4.0
	_px(mx, my, 2, 1, light)
	_px(mx + (1.0 if sin(a * 12.0) > 0.0 else 0.0), my - 1.0, 1, 1, light)


## A small crystal whose glow swells, then lets a spark drift up.
func _draw_chime(t: float) -> void:
	var pulse: float = 0.5 + 0.5 * sin(t * 1.3)
	_px(-4, -3, 8, 3, dark)
	_px(-2, -11, 4, 9, dark)
	_px(-1, -12, 2, 1, dark)
	_px(-1, -10, 2, 8, mid)
	_px(-1, -10, 1, 7, light)
	_px(0, -8, 1, 4, _faded(glow, 0.5 + 0.5 * pulse))
	var c: float = fmod(t, 4.0)
	if c < 1.8:
		_px(sin(c * 4.0) * 2.0, -14.0 - c * 8.0, 1, 1, _faded(glow, 1.0 - c / 1.8))


## A little mushroom that puffs a spore cloud now and then.
func _draw_spores(t: float) -> void:
	_px(-1, -5, 2, 5, light)
	_px(-5, -8, 10, 3, dark)
	_px(-4, -8, 8, 2, mid)
	_px(-2, -8, 2, 1, glow)
	var c: float = fmod(t, 5.0)
	if c < 2.0:
		for i: int in 4:
			var ang: float = float(i) * 1.7
			var r: float = c * 5.0
			_px(cos(ang) * r, -10.0 - c * 6.0 + sin(ang) * r * 0.5, 1, 1, _faded(glow, 1.0 - c / 2.0))
