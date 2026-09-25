## FloorTileAtlas — builds the procedural isometric floor tiles for a RoomLook (ADR-0021).
##
## One horizontal atlas strip of 64×32 diamond tiles, one per Variant. Every pixel
## is derived from the RoomLook colours plus an integer hash, so the same look
## always produces the same image (no RNG, deterministic tests). Rooms pick a
## variant per cell with variant_for_cell(), which is also hash-based, so a room
## looks the same every time it is built.
class_name FloorTileAtlas
extends RefCounted

enum Variant { PLAIN, WORN, CRACKED, GLYPH }

const TILE_W: int = 64
const TILE_H: int = 32
const VARIANT_COUNT: int = 4

## Share of the diamond (by normalised distance) given to the bevel edge.
const _BEVEL: float = 0.88
const _HALF_H: int = 16


## Returns the atlas image: VARIANT_COUNT tiles side by side, RGBA8.
static func build_image(look: RoomLook) -> Image:
	var img := Image.create(TILE_W * VARIANT_COUNT, TILE_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for v: int in VARIANT_COUNT:
		_paint_tile(img, v * TILE_W, v, look)
	return img


## Returns the atlas as a texture ready for a TileSetAtlasSource.
static func build_texture(look: RoomLook) -> Texture2D:
	return ImageTexture.create_from_image(build_image(look))


## Returns the atlas coordinate of the tile variant drawn at [param cell].
## Deterministic: the same cell and look always give the same variant.
static func variant_for_cell(cell: Vector2i, look: RoomLook) -> int:
	var roll: float = hash01(cell.x, cell.y, 17)
	if roll < look.glyph_chance:
		return Variant.GLYPH
	roll -= look.glyph_chance
	if roll < look.crack_chance:
		return Variant.CRACKED
	roll -= look.crack_chance
	if roll < look.worn_chance:
		return Variant.WORN
	return Variant.PLAIN


## Integer hash of (a, b, salt) mapped to [0, 1). Pure, platform independent.
static func hash01(a: int, b: int, salt: int) -> float:
	var h: int = (a * 374761393 + b * 668265263 + salt * 2147483647) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF) / float(0x1000000)


## True when pixel ([param x], [param y]) of a tile lies inside the diamond.
static func in_diamond(x: int, y: int) -> bool:
	return _diamond_dist(x, y) <= 1.0


static func _diamond_dist(x: int, y: int) -> float:
	var hw: float = TILE_W / 2.0
	var hh: float = TILE_H / 2.0
	return absf(x - hw + 0.5) / hw + absf(y - hh + 0.5) / hh


static func _paint_tile(img: Image, ox: int, variant: int, look: RoomLook) -> void:
	var base: Color = look.floor_alt if variant == Variant.WORN else look.floor_base
	for y: int in TILE_H:
		for x: int in TILE_W:
			var d: float = _diamond_dist(x, y)
			if d > 1.0:
				continue
			var c: Color = base
			if variant == Variant.WORN and hash01(floori(x / 6.0), floori(y / 3.0), variant) < 0.35:
				c = look.floor_base.lerp(look.floor_alt, 0.5)
			var g: float = (hash01(x, y, variant + 101) - 0.5) * 2.0 * look.grain
			c = Color(c.r + g, c.g + g, c.b + g, 1.0)
			if d > _BEVEL:
				# Upper edges catch the light, lower edges read as the seam.
				c = look.floor_highlight if y < _HALF_H else look.floor_seam
			img.set_pixel(ox + x, y, c)
	if variant == Variant.CRACKED:
		_paint_crack(img, ox, look)
	elif variant == Variant.GLYPH:
		_paint_glyph(img, ox, look)


## A jagged crack running roughly across the tile.
static func _paint_crack(img: Image, ox: int, look: RoomLook) -> void:
	var x: int = 18
	var y: int = 11
	for step: int in 26:
		if in_diamond(x, y) and _diamond_dist(x, y) < _BEVEL:
			img.set_pixel(ox + x, y, look.floor_seam)
		x += 1
		if hash01(step, 3, 7) < 0.45:
			y += 1 if hash01(step, 5, 9) < 0.7 else -1
		y = clampi(y, 4, TILE_H - 5)


## A small etched ring-and-bar glyph at the tile centre.
static func _paint_glyph(img: Image, ox: int, look: RoomLook) -> void:
	var cx: float = TILE_W / 2.0
	var cy: float = TILE_H / 2.0
	for y: int in TILE_H:
		for x: int in TILE_W:
			var dx: float = (x + 0.5 - cx) / 2.0  # iso squash: ring is twice as wide
			var dy: float = y + 0.5 - cy
			var r: float = sqrt(dx * dx + dy * dy)
			var on_ring: bool = r > 4.0 and r < 5.2
			var on_bar: bool = absf(dy) < 0.6 and absf(dx) < 3.0
			if on_ring or on_bar:
				img.set_pixel(ox + x, y, look.floor_base.lerp(look.floor_accent, 0.7))
