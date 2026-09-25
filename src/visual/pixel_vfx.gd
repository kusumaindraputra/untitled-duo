## pixel_vfx.gd — Pixel-art raster helpers for procedural spell VFX (ADR-0023).
##
## The spell effects keep their procedural shapes (arcs, beams, rings, cones)
## but are rasterised onto the world pixel grid instead of drawn as antialiased
## vectors, so they share the chunky pixel size of the PixelCharacter sprites
## (1 art pixel = 1 world unit, ADR-0022).
##
## Rules applied by every helper:
##   - shapes become 1×1 cells aligned to the world integer grid (no antialiasing)
##   - cells are merged into horizontal runs, so one draw_rect covers a whole run
##   - alpha is quantised into a few flat steps instead of a smooth fade
##   - colour uses a 3-tone ramp (dark / base / light); thick strokes get a light core
##
## Cell (x, y) covers local [x, x + 1) × [y, y + 1). Span lists are flat
## PackedInt32Array triples (y, x0, x1), both x ends inclusive.
class_name PixelVFX
extends RefCounted

## Flat alpha steps used for strokes (1/4, 2/4, 3/4, 1).
const ALPHA_STEPS: int = 4
## Finer steps for large translucent fills such as the range cone.
const FILL_ALPHA_STEPS: int = 8
## Sampling density along a shape, in samples per world pixel (> 1 avoids holes).
const _SAMPLES_PER_PX: float = 1.5
## Distance between parallel sample layers of a thick stroke, in world pixels.
const _LAYER_STEP: float = 0.7


# ── Colour ─────────────────────────────────────────────────────────────────────

## Rounds [param a] to the nearest of [param steps] flat alpha levels (0 hides the cell).
static func quantize_alpha(a: float, steps: int = ALPHA_STEPS) -> float:
	var s: float = float(maxi(steps, 1))
	return clampf(roundf(clampf(a, 0.0, 1.0) * s) / s, 0.0, 1.0)


## 3-tone pixel ramp for [param base]: [dark, base, light], all opaque.
static func palette(base: Color) -> Array[Color]:
	var b: Color = Color(base.r, base.g, base.b, 1.0)
	return [b.darkened(0.45), b, b.lightened(0.55)]


## Returns [param c] with its alpha replaced by the quantised [param alpha].
static func with_alpha(c: Color, alpha: float, steps: int = ALPHA_STEPS) -> Color:
	return Color(c.r, c.g, c.b, quantize_alpha(alpha, steps))


# ── Grid alignment ─────────────────────────────────────────────────────────────

## Local offset that puts cell (0, 0) on the world integer grid under [param ci].
## Keeps effect pixels aligned with each other while the node moves sub-pixel.
static func snap_origin(ci: CanvasItem) -> Vector2:
	if ci is Node2D and (ci as Node2D).is_inside_tree():
		var g: Vector2 = (ci as Node2D).global_position
		return g.floor() - g
	return Vector2.ZERO


# ── Shape → spans ──────────────────────────────────────────────────────────────

## Spans of a filled disc of [param radius] centred on the local origin.
static func disc_spans(radius: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	if radius <= 0.0:
		return out
	var ry: int = ceili(radius)
	for y: int in range(-ry, ry + 1):
		var r: Vector2i = _row_range(radius, y)
		if r.x <= r.y:
			out.append_array([y, r.x, r.y])
	return out


## Spans of a full ring: mid-radius [param radius], [param width] pixels thick.
static func ring_spans(radius: float, width: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var ro: float = radius + width * 0.5
	var ri: float = radius - width * 0.5
	if ro <= 0.0:
		return out
	var ry: int = ceili(ro)
	for y: int in range(-ry, ry + 1):
		var outer: Vector2i = _row_range(ro, y)
		if outer.x > outer.y:
			continue
		var inner: Vector2i = _row_range(ri, y) if ri > 0.0 else Vector2i(1, 0)
		if inner.x > inner.y:
			out.append_array([y, outer.x, outer.y])
			continue
		if inner.x - 1 >= outer.x:
			out.append_array([y, outer.x, inner.x - 1])
		if outer.y >= inner.y + 1:
			out.append_array([y, inner.y + 1, outer.y])
	return out


## Spans of a convex polygon [param pts] (local coordinates). Rows are sampled
## at cell centres; [param row_stride] > 1 keeps only every Nth row (scanline fill).
static func convex_polygon_spans(pts: PackedVector2Array, row_stride: int = 1) -> PackedInt32Array:
	var out := PackedInt32Array()
	if pts.size() < 3:
		return out
	var min_y: float = INF
	var max_y: float = -INF
	for p: Vector2 in pts:
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	var stride: int = maxi(row_stride, 1)
	for y: int in range(floori(min_y), ceili(max_y) + 1):
		if posmod(y, stride) != 0:
			continue
		var yc: float = float(y) + 0.5
		var x_min: float = INF
		var x_max: float = -INF
		for i: int in pts.size():
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % pts.size()]
			if a.y == b.y or (a.y - yc) * (b.y - yc) > 0.0:
				continue
			var x: float = lerpf(a.x, b.x, (yc - a.y) / (b.y - a.y))
			x_min = minf(x_min, x)
			x_max = maxf(x_max, x)
		if x_min > x_max:
			continue
		var x0: int = ceili(x_min - 0.5)
		var x1: int = floori(x_max - 0.5)
		if x0 <= x1:
			out.append_array([y, x0, x1])
	return out


## Cells of a straight stroke from [param a] to [param b], [param width] pixels thick.
static func line_cells(a: Vector2, b: Vector2, width: float, into: Dictionary = {}) -> Dictionary:
	var length: float = a.distance_to(b)
	var n: int = maxi(ceili(length * _SAMPLES_PER_PX), 1)
	var perp: Vector2 = (b - a).normalized().orthogonal() if length > 0.0 else Vector2.ZERO
	for off: float in _layers(width):
		var o: Vector2 = perp * off
		for i: int in n + 1:
			var p: Vector2 = a.lerp(b, float(i) / float(n)) + o
			into[Vector2i(floori(p.x), floori(p.y))] = true
	return into


## Cells of a polyline through [param pts], [param width] pixels thick.
static func polyline_cells(pts: PackedVector2Array, width: float, into: Dictionary = {}) -> Dictionary:
	for i: int in range(pts.size() - 1):
		line_cells(pts[i], pts[i + 1], width, into)
	return into


## Cells of an arc around [param center] from angle [param a_from] to [param a_to].
static func arc_cells(center: Vector2, radius: float, a_from: float, a_to: float,
		width: float, into: Dictionary = {}) -> Dictionary:
	for off: float in _layers(width):
		var rr: float = radius + off
		if rr <= 0.0:
			continue
		var n: int = maxi(ceili(absf(a_to - a_from) * rr * _SAMPLES_PER_PX), 1)
		for i: int in n + 1:
			var p: Vector2 = center + Vector2.from_angle(lerpf(a_from, a_to, float(i) / float(n))) * rr
			into[Vector2i(floori(p.x), floori(p.y))] = true
	return into


## Merges a cell set into sorted horizontal spans.
static func cells_to_spans(cells: Dictionary) -> PackedInt32Array:
	var keys: Array = cells.keys()
	keys.sort_custom(func(p: Vector2i, q: Vector2i) -> bool:
		return p.y < q.y or (p.y == q.y and p.x < q.x))
	var out := PackedInt32Array()
	var i: int = 0
	while i < keys.size():
		var c: Vector2i = keys[i]
		var x1: int = c.x
		var j: int = i + 1
		while j < keys.size() and (keys[j] as Vector2i).y == c.y and (keys[j] as Vector2i).x == x1 + 1:
			x1 += 1
			j += 1
		out.append_array([c.y, c.x, x1])
		i = j
	return out


# ── Drawing ────────────────────────────────────────────────────────────────────

## Draws [param spans] on [param ci] as flat rects. [param offset] shifts every
## cell (use [method snap_origin], plus a centre for off-origin shapes).
static func draw_spans(ci: CanvasItem, spans: PackedInt32Array, color: Color,
		offset: Vector2 = Vector2.ZERO) -> void:
	if color.a <= 0.0:
		return
	var i: int = 0
	while i + 2 < spans.size():
		ci.draw_rect(Rect2(offset.x + spans[i + 1], offset.y + spans[i],
				spans[i + 2] - spans[i + 1] + 1, 1), color)
		i += 3


## Pixel stroke from [param a] to [param b] with a light core when 3+ px wide.
static func stroke_line(ci: CanvasItem, a: Vector2, b: Vector2, width: float,
		base: Color, alpha: float) -> void:
	stroke_polyline(ci, PackedVector2Array([a, b]), width, base, alpha)


## Pixel polyline with a light core when 3+ px wide.
static func stroke_polyline(ci: CanvasItem, pts: PackedVector2Array, width: float,
		base: Color, alpha: float) -> void:
	var o: Vector2 = snap_origin(ci)
	var ramp: Array[Color] = palette(base)
	draw_spans(ci, cells_to_spans(polyline_cells(pts, width)), with_alpha(ramp[1], alpha), o)
	if width >= 3.0:
		draw_spans(ci, cells_to_spans(polyline_cells(pts, width - 2.0)), with_alpha(ramp[2], alpha), o)


## Pixel arc around the local origin with a light core when 3+ px wide.
static func stroke_arc(ci: CanvasItem, radius: float, a_from: float, a_to: float,
		width: float, base: Color, alpha: float) -> void:
	var o: Vector2 = snap_origin(ci)
	var ramp: Array[Color] = palette(base)
	draw_spans(ci, cells_to_spans(arc_cells(Vector2.ZERO, radius, a_from, a_to, width)),
			with_alpha(ramp[1], alpha), o)
	if width >= 3.0:
		draw_spans(ci, cells_to_spans(arc_cells(Vector2.ZERO, radius, a_from, a_to, width - 2.0)),
				with_alpha(ramp[2], alpha), o)


## Full pixel ring around the local origin with a dark rim and a light core.
static func stroke_ring(ci: CanvasItem, radius: float, width: float,
		base: Color, alpha: float) -> void:
	var o: Vector2 = snap_origin(ci)
	var ramp: Array[Color] = palette(base)
	draw_spans(ci, ring_spans(radius, width), with_alpha(ramp[1], alpha), o)
	if width >= 3.0:
		draw_spans(ci, ring_spans(radius, width - 2.0), with_alpha(ramp[2], alpha), o)


## Filled pixel disc at [param center]: base body with a dark rim.
static func fill_disc(ci: CanvasItem, center: Vector2, radius: float,
		base: Color, alpha: float) -> void:
	var o: Vector2 = snap_origin(ci) + center.round()
	var ramp: Array[Color] = palette(base)
	draw_spans(ci, disc_spans(radius), with_alpha(ramp[0], alpha), o)
	draw_spans(ci, disc_spans(radius - 1.0), with_alpha(ramp[2], alpha), o)


## Translucent scanline fill of a convex polygon (every [param row_stride] rows).
static func fill_polygon(ci: CanvasItem, pts: PackedVector2Array, color: Color,
		alpha: float, row_stride: int = 1) -> void:
	draw_spans(ci, convex_polygon_spans(pts, row_stride),
			with_alpha(color, alpha, FILL_ALPHA_STEPS), snap_origin(ci))


# ── Internals ──────────────────────────────────────────────────────────────────

## Inclusive cell x-range of a circle of [param radius] on row [param y]
## (sampled at the cell centre). Empty rows return x > y.
static func _row_range(radius: float, y: int) -> Vector2i:
	var yc: float = float(y) + 0.5
	var h: float = radius * radius - yc * yc
	if h < 0.0:
		return Vector2i(1, 0)
	var xr: float = sqrt(h)
	return Vector2i(ceili(-xr - 0.5), floori(xr - 0.5))


## Perpendicular sample offsets that cover a stroke [param width] pixels wide.
static func _layers(width: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var half: float = maxf(width - 1.0, 0.0) * 0.5
	var off: float = -half
	while off <= half + 0.001:
		out.append(off)
		off += _LAYER_STEP
	if out.is_empty() or out[out.size() - 1] < half - 0.001:
		out.append(half)
	return out
