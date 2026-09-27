## PropArt — procedural pixel-art props for each floor motif (ADR-0038).
##
## Like FloorTileAtlas, every prop is painted at runtime from the RoomLook prop
## palette, with no RNG, so the same look always gives the same image. Shapes are
## painted as tones (dark / mid / light / glow) on a small canvas, outlined in the
## dark tone, then coloured. Props are 1 texture pixel per world pixel, the same
## density as the 64×32 floor tiles, and are imported with the project's nearest filter.
class_name PropArt
extends RefCounted

enum Prop {
	BOULDER, ROOT_TANGLE, BROKEN_COLUMN,
	SCRAP_HEAP, GEAR_WHEEL, BENT_GIRDER, RUST_BARREL,
	PIPE_STACK, VALVE_WHEEL, VENT_BOX, CABLE_COIL,
	CRYSTAL_CLUSTER, CRYSTAL_SPIRE, SHARD_ROCK,
	RUBBLE,
	HANG_ROOTS, HANG_CHAIN, HANG_PIPE, HANG_CRYSTAL,
}

const _EMPTY: int = 0
const _DARK: int = 1
const _MID: int = 2
const _LIGHT: int = 3
const _GLOW: int = 4

## Canvas size of each prop, in pixels.
const SIZES: Dictionary = {
	Prop.BOULDER: Vector2i(26, 18),
	Prop.ROOT_TANGLE: Vector2i(28, 20),
	Prop.BROKEN_COLUMN: Vector2i(24, 52),
	Prop.SCRAP_HEAP: Vector2i(42, 28),
	Prop.GEAR_WHEEL: Vector2i(30, 30),
	Prop.BENT_GIRDER: Vector2i(22, 44),
	Prop.RUST_BARREL: Vector2i(16, 22),
	Prop.PIPE_STACK: Vector2i(38, 30),
	Prop.VALVE_WHEEL: Vector2i(22, 38),
	Prop.VENT_BOX: Vector2i(26, 24),
	Prop.CABLE_COIL: Vector2i(26, 14),
	Prop.CRYSTAL_CLUSTER: Vector2i(30, 36),
	Prop.CRYSTAL_SPIRE: Vector2i(16, 50),
	Prop.SHARD_ROCK: Vector2i(28, 24),
	Prop.RUBBLE: Vector2i(24, 20),
	Prop.HANG_ROOTS: Vector2i(20, 26),
	Prop.HANG_CHAIN: Vector2i(10, 30),
	Prop.HANG_PIPE: Vector2i(16, 32),
	Prop.HANG_CRYSTAL: Vector2i(20, 26),
}

static var _cache: Dictionary = {}


## Props standing on the far rim for [param motif].
static func rim_props(motif: RoomLook.Motif) -> Array[int]:
	match motif:
		RoomLook.Motif.SCRAP:
			return [Prop.SCRAP_HEAP, Prop.GEAR_WHEEL, Prop.BENT_GIRDER, Prop.RUST_BARREL]
		RoomLook.Motif.CONDUIT:
			return [Prop.PIPE_STACK, Prop.VALVE_WHEEL, Prop.VENT_BOX, Prop.CABLE_COIL]
		RoomLook.Motif.CRYSTAL:
			return [Prop.CRYSTAL_CLUSTER, Prop.CRYSTAL_SPIRE, Prop.SHARD_ROCK]
	return [Prop.BOULDER, Prop.ROOT_TANGLE]


## Prop hanging off the slab face under the near edges for [param motif].
static func face_prop(motif: RoomLook.Motif) -> int:
	match motif:
		RoomLook.Motif.SCRAP:
			return Prop.HANG_CHAIN
		RoomLook.Motif.CONDUIT:
			return Prop.HANG_PIPE
		RoomLook.Motif.CRYSTAL:
			return Prop.HANG_CRYSTAL
	return Prop.HANG_ROOTS


## True for props that hang down from their anchor instead of standing on it.
static func hangs(prop: int) -> bool:
	return prop >= Prop.HANG_ROOTS


## Returns the painted prop, cached per look and prop.
static func texture(prop: int, look: RoomLook) -> Texture2D:
	var key: String = "%d:%d" % [look.get_instance_id(), prop]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(build_image(prop, look))
	return _cache[key]


## Paints [param prop] in [param look]'s prop palette. Deterministic.
static func build_image(prop: int, look: RoomLook) -> Image:
	var size: Vector2i = SIZES.get(prop, Vector2i(16, 16))
	var c := _Canvas.new(size.x, size.y)
	match prop:
		Prop.BOULDER: _boulder(c)
		Prop.ROOT_TANGLE: _root_tangle(c)
		Prop.BROKEN_COLUMN: _broken_column(c)
		Prop.SCRAP_HEAP: _scrap_heap(c)
		Prop.GEAR_WHEEL: _gear_wheel(c)
		Prop.BENT_GIRDER: _bent_girder(c)
		Prop.RUST_BARREL: _rust_barrel(c)
		Prop.PIPE_STACK: _pipe_stack(c)
		Prop.VALVE_WHEEL: _valve_wheel(c)
		Prop.VENT_BOX: _vent_box(c)
		Prop.CABLE_COIL: _cable_coil(c)
		Prop.CRYSTAL_CLUSTER: _crystal_cluster(c)
		Prop.CRYSTAL_SPIRE: _crystal_spire(c)
		Prop.SHARD_ROCK: _shard_rock(c)
		Prop.RUBBLE: _rubble(c)
		Prop.HANG_ROOTS: _hang_roots(c)
		Prop.HANG_CHAIN: _hang_chain(c)
		Prop.HANG_PIPE: _hang_pipe(c)
		Prop.HANG_CRYSTAL: _hang_crystal(c)
	c.outline()
	return c.to_image([Color(0, 0, 0, 0), look.prop_dark, look.prop_mid, look.prop_light, look.prop_glow])


# ── Shapes ─────────────────────────────────────────────────────────────────────

static func _boulder(c: _Canvas) -> void:
	c.ellipse(13, 11, 12, 7, _MID)
	c.ellipse(10, 8, 6, 3, _LIGHT)
	c.ellipse(19, 14, 4, 2, _DARK)


static func _root_tangle(c: _Canvas) -> void:
	c.ellipse(14, 15, 12, 5, _MID)
	c.ellipse(11, 13, 6, 2, _LIGHT)
	c.line(Vector2(4, 16), Vector2(1, 6), _MID)
	c.line(Vector2(9, 12), Vector2(7, 2), _MID)
	c.line(Vector2(20, 12), Vector2(25, 3), _MID)
	c.set_px(7, 2, _GLOW)
	c.set_px(25, 3, _GLOW)


static func _broken_column(c: _Canvas) -> void:
	c.ellipse(12, 47, 11, 4, _MID)
	c.poly([Vector2(4, 12), Vector2(9, 6), Vector2(13, 10), Vector2(17, 4), Vector2(20, 11), Vector2(20, 47), Vector2(4, 47)], _MID)
	c.rect(5, 12, 4, 34, _LIGHT)
	c.rect(15, 14, 1, 32, _DARK)
	c.line(Vector2(10, 18), Vector2(13, 26), _DARK)
	c.line(Vector2(13, 26), Vector2(11, 33), _DARK)
	c.rect(3, 40, 18, 3, _LIGHT)


static func _scrap_heap(c: _Canvas) -> void:
	c.poly([Vector2(1, 27), Vector2(8, 15), Vector2(16, 12), Vector2(24, 6), Vector2(33, 13), Vector2(41, 27)], _MID)
	# A wheel rim, a plank and a pipe sticking out of the pile.
	c.ring(14, 17, 6, 4, _LIGHT)
	c.line(Vector2(22, 8), Vector2(36, 2), _LIGHT)
	c.line(Vector2(22, 9), Vector2(36, 3), _MID)
	c.rect(30, 14, 7, 3, _LIGHT)
	c.ellipse(26, 20, 3, 2, _DARK)
	c.set_px(8, 22, _GLOW)


static func _gear_wheel(c: _Canvas) -> void:
	for i: int in 10:
		var a: float = TAU * i / 10.0
		c.ellipse(15 + roundi(cos(a) * 12.0), 14 + roundi(sin(a) * 12.0), 2, 2, _MID)
	c.ellipse(15, 14, 11, 11, _MID)
	c.ellipse(12, 11, 6, 6, _LIGHT)
	c.ellipse(15, 14, 3, 3, _DARK)
	c.poly([Vector2(0, 29), Vector2(4, 22), Vector2(15, 20), Vector2(26, 22), Vector2(30, 29)], _MID)
	c.rect(0, 26, 30, 4, _MID)


static func _bent_girder(c: _Canvas) -> void:
	c.poly([Vector2(6, 43), Vector2(6, 16), Vector2(13, 4), Vector2(19, 6), Vector2(13, 18), Vector2(13, 43)], _MID)
	c.rect(6, 18, 2, 25, _LIGHT)
	for y: int in [22, 29, 36]:
		c.rect(8, y, 5, 1, _DARK)
	c.set_px(12, 12, _DARK)
	c.ellipse(10, 42, 8, 2, _MID)


static func _rust_barrel(c: _Canvas) -> void:
	c.rect(2, 4, 12, 16, _MID)
	c.ellipse(8, 4, 6, 2, _LIGHT)
	c.ellipse(8, 20, 6, 2, _MID)
	c.rect(3, 6, 3, 13, _LIGHT)
	c.rect(2, 9, 12, 1, _DARK)
	c.rect(2, 15, 12, 1, _DARK)


static func _pipe_stack(c: _Canvas) -> void:
	for row: Array in [[4, 22], [16, 22], [10, 12]]:
		var x0: int = row[0]
		var y: int = row[1]
		c.rect(x0, y - 5, 18, 10, _MID)
		c.rect(x0, y - 4, 18, 2, _LIGHT)
		c.ellipse(x0 + 18, y, 3, 5, _LIGHT)
		c.ellipse(x0 + 18, y, 1, 2, _DARK)


static func _valve_wheel(c: _Canvas) -> void:
	c.rect(8, 12, 6, 26, _MID)
	c.rect(8, 12, 2, 26, _LIGHT)
	c.rect(6, 30, 10, 3, _LIGHT)
	c.ring(11, 8, 9, 5, _MID)
	c.line(Vector2(3, 8), Vector2(19, 8), _MID)
	c.line(Vector2(11, 3), Vector2(11, 13), _MID)
	c.ellipse(11, 8, 1, 1, _GLOW)


static func _vent_box(c: _Canvas) -> void:
	c.poly([Vector2(1, 8), Vector2(13, 2), Vector2(25, 8), Vector2(25, 22), Vector2(13, 23), Vector2(1, 22)], _MID)
	c.poly([Vector2(1, 8), Vector2(13, 2), Vector2(25, 8), Vector2(13, 13)], _LIGHT)
	for y: int in [15, 18]:
		c.rect(4, y, 7, 1, _DARK)
	c.rect(16, 15, 6, 4, _DARK)
	c.rect(17, 16, 4, 2, _GLOW)


static func _cable_coil(c: _Canvas) -> void:
	c.ellipse(13, 8, 12, 5, _MID)
	c.ring(13, 7, 9, 3, _LIGHT)
	c.ellipse(13, 7, 5, 1, _DARK)
	c.line(Vector2(23, 9), Vector2(25, 13), _MID)


static func _shard(c: _Canvas, base_x: int, base_y: int, w: int, h: int, lean: int) -> void:
	var tip := Vector2(base_x + lean, base_y - h)
	c.poly([Vector2(base_x - w, base_y), tip, Vector2(base_x + w, base_y)], _MID)
	c.poly([Vector2(base_x - w, base_y), tip, Vector2(base_x, base_y)], _LIGHT)
	c.line(Vector2(base_x, base_y - 2), tip + Vector2(0, 3), _GLOW)


static func _crystal_cluster(c: _Canvas) -> void:
	c.ellipse(15, 32, 13, 4, _MID)
	_shard(c, 8, 33, 4, 18, -3)
	_shard(c, 21, 33, 4, 22, 3)
	_shard(c, 14, 34, 5, 32, 0)


static func _crystal_spire(c: _Canvas) -> void:
	c.ellipse(8, 46, 7, 3, _MID)
	_shard(c, 8, 47, 5, 46, 1)


static func _shard_rock(c: _Canvas) -> void:
	c.ellipse(14, 18, 13, 6, _MID)
	c.ellipse(10, 16, 6, 3, _LIGHT)
	_shard(c, 18, 16, 3, 14, 2)
	_shard(c, 9, 15, 2, 8, -2)


## Half-cover debris in the arena (ADR-0039): a squat rock pile, lit from the top left.
static func _rubble(c: _Canvas) -> void:
	c.ellipse(12, 15, 11, 4, _DARK)
	c.poly([Vector2(2, 15), Vector2(5, 6), Vector2(11, 2), Vector2(17, 4), Vector2(21, 10), Vector2(21, 15)], _MID)
	c.poly([Vector2(5, 7), Vector2(11, 2), Vector2(16, 4), Vector2(12, 8), Vector2(6, 10)], _LIGHT)
	c.poly([Vector2(14, 15), Vector2(17, 9), Vector2(21, 10), Vector2(21, 15)], _DARK)
	c.line(Vector2(9, 10), Vector2(12, 14), _DARK)
	c.set_px(7, 8, _GLOW)


static func _hang_roots(c: _Canvas) -> void:
	for r: Array in [[3, 20], [8, 25], [13, 16], [17, 22]]:
		c.line(Vector2(r[0], 0), Vector2(r[0] + 1, r[1]), _MID)
	c.set_px(9, 25, _GLOW)
	c.set_px(14, 16, _GLOW)


static func _hang_chain(c: _Canvas) -> void:
	for i: int in 6:
		c.ring(5, 2 + i * 4, 2 if i % 2 == 0 else 1, 2, _LIGHT if i % 2 == 0 else _MID)
	c.rect(2, 25, 6, 4, _MID)


static func _hang_pipe(c: _Canvas) -> void:
	c.rect(4, 0, 7, 24, _MID)
	c.rect(4, 0, 2, 24, _LIGHT)
	c.rect(2, 10, 11, 3, _LIGHT)
	c.ellipse(7, 25, 4, 2, _DARK)
	c.set_px(7, 28, _GLOW)
	c.set_px(7, 31, _GLOW)


static func _hang_crystal(c: _Canvas) -> void:
	for s: Array in [[5, 3, 14], [11, 4, 24], [16, 3, 12]]:
		var x: int = s[0]
		var w: int = s[1]
		var tip := Vector2(x, s[2])
		c.poly([Vector2(x - w, 0), tip, Vector2(x + w, 0)], _MID)
		c.poly([Vector2(x - w, 0), tip, Vector2(x, 0)], _LIGHT)
		c.line(Vector2(x, 1), tip - Vector2(0, 3), _GLOW)


# ── Canvas ─────────────────────────────────────────────────────────────────────

## A small tone canvas: one byte per pixel (0 = empty, 1–4 = dark/mid/light/glow).
class _Canvas:
	var w: int
	var h: int
	var px: PackedByteArray

	func _init(width: int, height: int) -> void:
		w = width
		h = height
		px = PackedByteArray()
		px.resize(w * h)

	func set_px(x: int, y: int, tone: int) -> void:
		if x >= 0 and y >= 0 and x < w and y < h:
			px[y * w + x] = tone

	func get_px(x: int, y: int) -> int:
		if x < 0 or y < 0 or x >= w or y >= h:
			return 0
		return px[y * w + x]

	func rect(x: int, y: int, rw: int, rh: int, tone: int) -> void:
		for yy: int in range(y, y + rh):
			for xx: int in range(x, x + rw):
				set_px(xx, yy, tone)

	func ellipse(cx: int, cy: int, rx: int, ry: int, tone: int) -> void:
		for yy: int in range(cy - ry, cy + ry + 1):
			for xx: int in range(cx - rx, cx + rx + 1):
				var dx: float = (xx - cx) / maxf(rx + 0.5, 0.5)
				var dy: float = (yy - cy) / maxf(ry + 0.5, 0.5)
				if dx * dx + dy * dy <= 1.0:
					set_px(xx, yy, tone)

	func ring(cx: int, cy: int, rx: int, ry: int, tone: int) -> void:
		for yy: int in range(cy - ry, cy + ry + 1):
			for xx: int in range(cx - rx, cx + rx + 1):
				var dx: float = (xx - cx) / maxf(rx + 0.5, 0.5)
				var dy: float = (yy - cy) / maxf(ry + 0.5, 0.5)
				var d: float = dx * dx + dy * dy
				if d <= 1.0 and d >= 0.45:
					set_px(xx, yy, tone)

	func poly(points: Array, tone: int) -> void:
		var pts := PackedVector2Array(points)
		for yy: int in h:
			for xx: int in w:
				if Geometry2D.is_point_in_polygon(Vector2(xx + 0.5, yy + 0.5), pts):
					set_px(xx, yy, tone)

	func line(a: Vector2, b: Vector2, tone: int) -> void:
		var steps: int = maxi(int(maxf(absf(b.x - a.x), absf(b.y - a.y))), 1)
		for i: int in steps + 1:
			var p: Vector2 = a.lerp(b, float(i) / steps)
			set_px(roundi(p.x), roundi(p.y), tone)

	## Pixels on the shape's border become the dark outline (glow pixels stay lit).
	func outline() -> void:
		var out: PackedByteArray = px.duplicate()
		for yy: int in h:
			for xx: int in w:
				var t: int = get_px(xx, yy)
				if t == 0 or t == 4:
					continue
				if get_px(xx - 1, yy) == 0 or get_px(xx + 1, yy) == 0 \
						or get_px(xx, yy - 1) == 0 or get_px(xx, yy + 1) == 0:
					out[yy * w + xx] = 1
		px = out

	func to_image(palette: Array[Color]) -> Image:
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for yy: int in h:
			for xx: int in w:
				img.set_pixel(xx, yy, palette[get_px(xx, yy)])
		return img
