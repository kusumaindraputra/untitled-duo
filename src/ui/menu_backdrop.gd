## MenuBackdrop — the vault behind the main menu, with Fayde standing in it (beta plan U7).
##
## Drawn in code: a dark gradient, the vault's receding arches in dim gold, a lit floor
## ellipse and slow Prana motes rising. Fayde's idle frame sits on the floor, scaled with
## nearest filtering so the pixel art stays crisp. Motes hold still when
## [member animate] is false (reduced motion).
class_name MenuBackdrop
extends Control

const FAYDE_TEXTURE: Texture2D = preload("res://assets/art/characters/fayde.png")
const FAYDE_GLOW: Texture2D = preload("res://assets/art/characters/fayde_glow.png")
## Fayde's sheet is 4×3 frames of 20×32 (ADR-0034); frame 0 is the front idle.
const FAYDE_FRAME := Rect2(0, 0, 20, 32)
const FAYDE_SCALE: float = 7.0
const SKY_TOP := Color(0.03, 0.025, 0.05)
const SKY_BOTTOM := Color(0.09, 0.06, 0.1)
const ARCH_COLOR := Color(1.0, 0.8, 0.35)
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
var _fayde: TextureRect = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var glow := _sprite(FAYDE_GLOW)
	glow.modulate = Color(1, 1, 1, 0.6)
	add_child(glow)
	_fayde = _sprite(FAYDE_TEXTURE)
	add_child(_fayde)
	resized.connect(_place_fayde)
	_place_fayde()


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


func _sprite(tex: Texture2D) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = FAYDE_FRAME
	var r := TextureRect.new()
	r.texture = atlas
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.size = FAYDE_FRAME.size * FAYDE_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _place_fayde() -> void:
	var feet: Vector2 = size * FOCUS + Vector2(0, size.y * 0.18)
	for child: Node in get_children():
		var r := child as TextureRect
		if r != null:
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
		var top := Vector2(centre.x, base_y - w * 1.25)
		draw_line(Vector2(centre.x - w * 0.5, base_y), Vector2(centre.x - w * 0.5, base_y - w * 0.75), col, 2.0)
		draw_line(Vector2(centre.x + w * 0.5, base_y), Vector2(centre.x + w * 0.5, base_y - w * 0.75), col, 2.0)
		draw_arc(Vector2(centre.x, base_y - w * 0.75), w * 0.5, PI, TAU, 32, col, 2.0, true)
		if k == 0:
			draw_line(top, top + Vector2(0, 6), col, 2.0)
	# Lit floor where Fayde stands.
	var floor_c: Vector2 = centre + Vector2(0, size.y * 0.18)
	for r in 5:
		var rr: float = 150.0 - float(r) * 26.0
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
