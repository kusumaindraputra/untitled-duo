## bullet_art.gd — Baked enemy bullet art, drawn as batchable quads (ADR-0050).
##
## Projectile used to draw its trail, glow, rims, core and pip with draw_line and
## draw_circle every frame. On the Compatibility renderer those polygons never batch, so
## every bullet cost about two draw calls and a busy boss phase went past the 200 draw
## call budget on the web build. BulletArt bakes the same layers once into a small
## texture (per radius and outline option) and every bullet draws four textured quads
## with draw_primitive. Quads that share a texture batch into one draw call.
##
## Look is unchanged: the same palette colours and ring widths (ADR-0032, ADR-0037),
## baked at TEXELS_PER_PX with an anti-aliased edge.
class_name BulletArt
extends RefCounted

## Texels per world pixel. Combat zoom is 2.0, so bullets are baked at screen size.
const TEXELS_PER_PX: int = 2
## Empty texels around each atlas cell so linear filtering never bleeds between cells.
const CELL_PAD: int = 2
## Relative size of the glow disc, the white pip and their alphas (as Projectile drew).
const GLOW_MULT: float = 2.5
const GLOW_ALPHA: float = 0.16
const PIP_MULT: float = 0.3

static var _cache: Dictionary = {}

var texture: ImageTexture = null
## The baked pixels (a few hundred texels), kept for tests and screenshots.
var image: Image = null
## Half sizes of the body, core and pip quads, px (each baked cell, padding excluded).
var body_half: float = 0.0
var core_half: float = 0.0
var pip_half: float = 0.0
## Normalised UV rects of each cell.
var body_uv: Rect2 = Rect2()
var core_uv: Rect2 = Rect2()
var pip_uv: Rect2 = Rect2()
var white_uv: Rect2 = Rect2()


## Baked art for a bullet of [param bullet_radius] px, with or without the
## high-contrast outline. Cached; the first call per key bakes the texture.
static func for_bullet(bullet_radius: float, outline: bool, rim: Color, separator: Color) -> BulletArt:
	var key: String = "%.2f|%s|%s|%s" % [bullet_radius, outline, rim.to_html(), separator.to_html()]
	var art: BulletArt = _cache.get(key) as BulletArt
	if art == null:
		art = BulletArt.new()
		art._bake(bullet_radius, outline, rim, separator)
		_cache[key] = art
	return art


## Number of baked textures (test hook).
static func cache_size() -> int:
	return _cache.size()


## Drops every baked texture (tests).
static func clear_cache() -> void:
	_cache.clear()


## Outer radius of the body layers, px: the glow, or the white outline ring when on.
static func body_radius(bullet_radius: float, outline: bool) -> float:
	var r: float = bullet_radius * GLOW_MULT
	if outline:
		r = maxf(r, bullet_radius + Projectile.OUTLINE_WHITE)
	return maxf(r, bullet_radius + Projectile.RIM_WIDTH)


## Anti-aliased coverage (0..1) of a disc of [param r] texels at distance [param d].
static func disc_coverage(d: float, r: float) -> float:
	return clampf(r - d + 0.5, 0.0, 1.0)


## Draws the trail, body, core and pip of one bullet on [param item] at its origin.
## [param trail] is the trail end relative to the bullet (zero length = no trail).
func draw(item: CanvasItem, trail: Vector2, trail_color: Color, trail_width: float,
		core_color: Color, fade: float) -> void:
	if trail.length_squared() > 0.25:
		var side: Vector2 = trail.normalized().orthogonal() * (trail_width * 0.5)
		_quad(item, PackedVector2Array([side, trail + side, trail - side, -side]), white_uv, trail_color)
	_square(item, body_half, body_uv, Color(1.0, 1.0, 1.0, fade))
	_square(item, core_half, core_uv, core_color)
	_square(item, pip_half, pip_uv, Color(1.0, 1.0, 1.0, 0.9 * fade))


func _square(item: CanvasItem, half: float, uv: Rect2, color: Color) -> void:
	_quad(item, PackedVector2Array([Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half)]), uv, color)


func _quad(item: CanvasItem, points: PackedVector2Array, uv: Rect2, color: Color) -> void:
	var uvs := PackedVector2Array([uv.position, Vector2(uv.end.x, uv.position.y), uv.end,
		Vector2(uv.position.x, uv.end.y)])
	item.draw_primitive(points, PackedColorArray([color, color, color, color]), uvs, texture)


# ── Baking ────────────────────────────────────────────────────────────────────

func _bake(bullet_radius: float, outline: bool, rim: Color, separator: Color) -> void:
	var s: float = float(TEXELS_PER_PX)
	var radius: float = bullet_radius
	var body_px: int = ceili(body_radius(bullet_radius, outline) * 2.0 * s) + 2
	var core_px: int = ceili(radius * 2.0 * s) + 2
	var pip_px: int = ceili(radius * PIP_MULT * 2.0 * s) + 2
	body_half = float(body_px) / (2.0 * s)
	core_half = float(core_px) / (2.0 * s)
	pip_half = float(pip_px) / (2.0 * s)
	var white_px: int = 4
	# One row: body | core | pip | white.
	var w: int = body_px + core_px + pip_px + white_px + CELL_PAD * 5
	var h: int = body_px + CELL_PAD * 2
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var x: int = CELL_PAD
	var body_layers: Array = [[bullet_radius * GLOW_MULT, Color(rim.r, rim.g, rim.b, GLOW_ALPHA)]]
	if outline:
		body_layers.append([bullet_radius + Projectile.OUTLINE_WHITE, Color.WHITE])
		body_layers.append([bullet_radius + Projectile.OUTLINE_BLACK, Color.BLACK])
	body_layers.append([bullet_radius + Projectile.RIM_WIDTH, Color(rim.r, rim.g, rim.b, 1.0)])
	body_layers.append([bullet_radius + Projectile.SEPARATOR_WIDTH, separator])
	_paint_cell(img, x, CELL_PAD, body_px, body_layers, s)
	body_uv = _uv(x, CELL_PAD, body_px, w, h)
	x += body_px + CELL_PAD
	_paint_cell(img, x, CELL_PAD, core_px, [[radius, Color.WHITE]], s)
	core_uv = _uv(x, CELL_PAD, core_px, w, h)
	x += core_px + CELL_PAD
	_paint_cell(img, x, CELL_PAD, pip_px, [[radius * PIP_MULT, Color.WHITE]], s)
	pip_uv = _uv(x, CELL_PAD, pip_px, w, h)
	x += pip_px + CELL_PAD
	img.fill_rect(Rect2i(x, CELL_PAD, white_px, white_px), Color.WHITE)
	# Sample the middle of the white cell only, so filtering never reaches its edge.
	white_uv = Rect2((float(x) + 1.5) / float(w), (float(CELL_PAD) + 1.5) / float(h),
		1.0 / float(w), 1.0 / float(h))
	image = img
	texture = ImageTexture.create_from_image(img)


## Paints concentric discs ([radius px, colour], outermost first) into a square cell,
## compositing each over the last. [param s] is texels per px.
func _paint_cell(img: Image, x0: int, y0: int, size: int, layers: Array, s: float) -> void:
	var centre: float = float(size) * 0.5
	for py: int in size:
		for px: int in size:
			var d: float = Vector2(float(px) + 0.5 - centre, float(py) + 0.5 - centre).length()
			var out := Color(0, 0, 0, 0)
			for layer: Array in layers:
				var c: Color = layer[1]
				var a: float = c.a * disc_coverage(d, float(layer[0]) * s)
				if a <= 0.0:
					continue
				out = _over(out, Color(c.r, c.g, c.b, a))
			img.set_pixel(x0 + px, y0 + py, out)


static func _over(dst: Color, src: Color) -> Color:
	var a: float = src.a + dst.a * (1.0 - src.a)
	if a <= 0.0:
		return Color(0, 0, 0, 0)
	var r: float = (src.r * src.a + dst.r * dst.a * (1.0 - src.a)) / a
	var g: float = (src.g * src.a + dst.g * dst.a * (1.0 - src.a)) / a
	var b: float = (src.b * src.a + dst.b * dst.a * (1.0 - src.a)) / a
	return Color(r, g, b, a)


static func _uv(x: int, y: int, size: int, w: int, h: int) -> Rect2:
	return Rect2(float(x) / float(w), float(y) / float(h), float(size) / float(w), float(size) / float(h))
