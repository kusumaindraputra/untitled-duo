## MenuBackdrop — the vault behind the main menu, with Ayden and Faith standing in it
## (beta plan U7, ADR-0058).
##
## Drawn in code: a dark gradient, the vault's receding arches in dim gold, a lit floor
## ellipse and slow Prana motes rising. The two brothers' idle frames stand side by side
## on the floor, Ayden on the left and Faith on the right like their hands on the grid,
## scaled with nearest filtering so the pixel art stays crisp. A thread of Prana runs
## between them in their two colours and a heart on it beats: the link the fight is
## built on. Motes and the heart hold still when [member animate] is false (reduced
## motion).
class_name MenuBackdrop
extends Control

## Both brothers share Fayde's rig: 4×3 frames of 20×32 (ADR-0034, ADR-0058); frame 0
## is the front idle.
const IDLE_FRAME := Rect2(0, 0, 20, 32)
const FIGURE_SCALE: float = 7.0
## Horizontal distance from the vault's centre to each brother's centre, in figure widths.
const FIGURE_SPREAD: float = 0.72
## Height of the link thread above the feet, as a fraction of the figure height (hands).
const LINK_HEIGHT: float = 0.34
## How far the thread sags at its middle, in px.
const LINK_SAG: float = 10.0
## Heart beats per second on the link (a resting heartbeat, slower than combat's).
const HEART_RATE: float = 0.8
const SKY_TOP := Color(0.03, 0.025, 0.05)
const SKY_BOTTOM := Color(0.09, 0.06, 0.1)
## Lantern-warm, not jewel gold (art bible §4.1 E7, ADR-0039).
const ARCH_COLOR := UIPalette.ACCENT
const FLOOR_GLOW := Color(1.0, 0.75, 0.35, 0.16)
const MOTE_COLORS: Array[Color] = [
	Color(1.0, 0.45, 0.2), Color(0.45, 0.45, 1.0), Color(1.0, 0.85, 0.3),
	Color(0.5, 0.9, 1.0), Color(0.45, 0.9, 0.5),
]
const MOTE_COUNT: int = 26
## Mote rise speed, px per second.
const MOTE_SPEED: float = 14.0
## Where the vault's centre sits, as a fraction of the backdrop size.
const FOCUS := Vector2(0.7, 0.6)

## When false, motes hold still (reduced motion).
var animate: bool = true

var _time: float = 0.0
## The brothers' sprites (glow under body), keyed by DuoSwap.Character.
var _figures: Dictionary[int, Array] = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for c: int in [DuoSwap.Character.AYDEN, DuoSwap.Character.FAITH]:
		var look: Dictionary = DuoLooks.for_character(c)
		var glow := _sprite(look["glow"])
		glow.modulate = Color(1, 1, 1, 0.6)
		add_child(glow)
		var body := _sprite(look["sheet"])
		add_child(body)
		_figures[c] = [glow, body]
	resized.connect(_place_figures)
	_place_figures()


func _process(delta: float) -> void:
	if animate:
		_time += delta
		queue_redraw()


## Mote [param i]'s position at time [param t] inside [param area]; wraps bottom to top.
static func mote_position(i: int, t: float, area: Vector2) -> Vector2:
	var seed_x: float = fposmod(float(i) * 0.618034, 1.0)
	var seed_y: float = fposmod(float(i) * 0.414214, 1.0)
	var y: float = fposmod(seed_y * area.y - t * MOTE_SPEED * (0.6 + seed_x * 0.8), area.y)
	var x: float = seed_x * area.x + sin(t * 0.5 + float(i)) * 6.0
	return Vector2(x, y)


## Where [param character]'s feet stand for a backdrop of [param area]: Ayden left of
## the vault's centre, Faith right of it. Static so tests can check the layout.
static func feet_position(character: int, area: Vector2) -> Vector2:
	var centre: Vector2 = area * FOCUS + Vector2(0, area.y * 0.18)
	var side: float = 1.0 if character == DuoSwap.Character.FAITH else -1.0
	return centre + Vector2(side * IDLE_FRAME.size.x * FIGURE_SCALE * FIGURE_SPREAD, 0.0)


## Heart pulse at time [param t]: 1 on each beat, easing back to 0 before the next.
static func heart_pulse(t: float) -> float:
	var phase: float = fposmod(t * HEART_RATE, 1.0)
	return pow(1.0 - phase, 3.0)


func _sprite(tex: Texture2D) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = IDLE_FRAME
	var r := TextureRect.new()
	r.texture = atlas
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.size = IDLE_FRAME.size * FIGURE_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _place_figures() -> void:
	for c: int in _figures:
		var feet: Vector2 = feet_position(c, size)
		for r: TextureRect in _figures[c]:
			r.position = feet - Vector2(r.size.x * 0.5, r.size.y)


func _draw() -> void:
	# Vertical gradient in bands (cheap, no shader).
	var bands: int = 24
	for b in bands:
		var t: float = float(b) / float(bands - 1)
		var y0: float = size.y * float(b) / float(bands)
		draw_rect(Rect2(0, y0, size.x, size.y / float(bands) + 1.0), SKY_TOP.lerp(SKY_BOTTOM, t))
	var centre: Vector2 = size * FOCUS
	# Receding arches: each one smaller and fainter toward the vault's back.
	for k in 6:
		var s: float = 1.0 - float(k) * 0.14
		var w: float = size.y * 0.62 * s
		var base_y: float = centre.y + size.y * 0.18 * s
		var col := ARCH_COLOR
		col.a = 0.2 - float(k) * 0.028
		# Ogival (pointed) arch, never round-topped (art bible §3.3): two arcs of
		# radius = span, each centred on the opposite springing point.
		var a: float = w * 0.5
		var spring_y: float = base_y - w * 0.75
		var apex := Vector2(centre.x, spring_y - a * sqrt(3.0))
		draw_line(Vector2(centre.x - a, base_y), Vector2(centre.x - a, spring_y), col, 2.0)
		draw_line(Vector2(centre.x + a, base_y), Vector2(centre.x + a, spring_y), col, 2.0)
		draw_arc(Vector2(centre.x + a, spring_y), 2.0 * a, PI, PI + PI / 3.0, 24, col, 2.0, false)
		draw_arc(Vector2(centre.x - a, spring_y), 2.0 * a, -PI / 3.0, 0.0, 24, col, 2.0, false)
		if k == 0:
			draw_line(apex, apex + Vector2(0, 6), col, 2.0)
	# Lit floor where the brothers stand, wide enough for both.
	var floor_c: Vector2 = centre + Vector2(0, size.y * 0.18)
	for r in 5:
		var rr: float = 230.0 - float(r) * 38.0
		var c := FLOOR_GLOW
		c.a = FLOOR_GLOW.a * (0.4 + float(r) * 0.15)
		draw_set_transform(floor_c, 0.0, Vector2(1.0, 0.28))
		draw_circle(Vector2.ZERO, rr, c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in MOTE_COUNT:
		var p: Vector2 = mote_position(i, _time, size)
		var c: Color = MOTE_COLORS[i % MOTE_COLORS.size()]
		c.a = 0.35 + 0.35 * fposmod(float(i) * 0.37, 1.0)
		draw_circle(p, 1.5 + fposmod(float(i) * 0.53, 1.0) * 1.5, c)
	_draw_link()


## The Prana thread between the brothers' hands, Ayden's ember fading into Faith's sky,
## with a heart at its middle that beats.
func _draw_link() -> void:
	var fig_h: float = IDLE_FRAME.size.y * FIGURE_SCALE
	var fig_half: float = IDLE_FRAME.size.x * FIGURE_SCALE * 0.5
	var a: Vector2 = feet_position(DuoSwap.Character.AYDEN, size) \
		+ Vector2(fig_half * 0.8, -fig_h * LINK_HEIGHT)
	var b: Vector2 = feet_position(DuoSwap.Character.FAITH, size) \
		+ Vector2(-fig_half * 0.8, -fig_h * LINK_HEIGHT)
	var pulse: float = heart_pulse(_time) if animate else 0.4
	var ayden: Color = DuoSwap.hud_color(DuoSwap.Character.AYDEN)
	var faith: Color = DuoSwap.hud_color(DuoSwap.Character.FAITH)
	var steps: int = 16
	var prev: Vector2 = a
	for i in range(1, steps + 1):
		var t: float = float(i) / float(steps)
		var p: Vector2 = a.lerp(b, t) + Vector2(0.0, sin(t * PI) * LINK_SAG)
		var col: Color = ayden.lerp(faith, t)
		col.a = 0.18 + 0.12 * pulse
		draw_line(prev, p, col, 6.0)
		col.a = 0.55 + 0.35 * pulse
		draw_line(prev, p, col, 2.0)
		prev = p
	var mid: Vector2 = a.lerp(b, 0.5) + Vector2(0.0, LINK_SAG)
	_draw_heart(mid, 7.0 + 2.0 * pulse, Color(1.0, 0.55, 0.6, 0.6 + 0.4 * pulse))


## A small pixel-style heart centred on [param at].
func _draw_heart(at: Vector2, r: float, col: Color) -> void:
	draw_circle(at + Vector2(-r * 0.5, -r * 0.3), r * 0.55, col)
	draw_circle(at + Vector2(r * 0.5, -r * 0.3), r * 0.55, col)
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-r * 1.02, -r * 0.1), at + Vector2(r * 1.02, -r * 0.1), at + Vector2(0.0, r * 0.95),
	]), col)
