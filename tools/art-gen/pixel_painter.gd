## PixelPainter — tiny pixel-art drawing kit for the character sprite generator.
##
## Draws into one frame cell of a sprite sheet. Shapes can be flat or auto-shaded
## (light from the top-left, per the art bible), and outline() adds the 1 px dark
## outline once a frame is finished. Offline tool only; the game never loads it.

extends RefCounted

var img: Image
var ox: int = 0
var oy: int = 0
var w: int = 0
var h: int = 0


func _init(image: Image, cell_w: int, cell_h: int) -> void:
	img = image
	w = cell_w
	h = cell_h


## Points the painter at cell ([param col], [param row]).
func cell(col: int, row: int) -> void:
	ox = col * w
	oy = row * h


func px(x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= w or y >= h:
		return
	img.set_pixel(ox + x, oy + y, c)


func get_px(x: int, y: int) -> Color:
	if x < 0 or y < 0 or x >= w or y >= h:
		return Color(0, 0, 0, 0)
	return img.get_pixel(ox + x, oy + y)


func rect(x: int, y: int, rw: int, rh: int, c: Color) -> void:
	for yy: int in range(y, y + rh):
		for xx: int in range(x, x + rw):
			px(xx, yy, c)


func line(x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var dx: int = absi(x1 - x0)
	var dy: int = -absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	while true:
		px(x0, y0, c)
		if x0 == x1 and y0 == y1:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


## Filled ellipse centred on ([param cx], [param cy]) (half-pixel centres allowed).
## With [param shaded], the top-left rim is lightened and the bottom-right darkened.
func ellipse(cx: float, cy: float, rx: float, ry: float, c: Color, shaded: bool = false) -> void:
	for y: int in range(floori(cy - ry) - 1, ceili(cy + ry) + 2):
		for x: int in range(floori(cx - rx) - 1, ceili(cx + rx) + 2):
			var nx: float = (x + 0.5 - cx) / maxf(rx, 0.01)
			var ny: float = (y + 0.5 - cy) / maxf(ry, 0.01)
			if nx * nx + ny * ny > 1.0:
				continue
			px(x, y, _shade(c, nx, ny) if shaded else c)


## Filled polygon (points in cell pixels). Shading uses the polygon's bounding box.
func poly(points: PackedVector2Array, c: Color, shaded: bool = false) -> void:
	var r := Rect2(points[0], Vector2.ZERO)
	for p: Vector2 in points:
		r = r.expand(p)
	var centre: Vector2 = r.get_center()
	var half: Vector2 = r.size * 0.5
	for y: int in range(floori(r.position.y), ceili(r.end.y) + 1):
		for x: int in range(floori(r.position.x), ceili(r.end.x) + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			if not Geometry2D.is_point_in_polygon(p, points):
				continue
			if shaded:
				var nx: float = (p.x - centre.x) / maxf(half.x, 0.01)
				var ny: float = (p.y - centre.y) / maxf(half.y, 0.01)
				px(x, y, _shade(c, nx, ny))
			else:
				px(x, y, c)


## Adds a 1 px outline around every opaque pixel of the current cell.
func outline(c: Color) -> void:
	var edge: Array[Vector2i] = []
	for y: int in h:
		for x: int in w:
			if get_px(x, y).a > 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Color = get_px(x + d.x, y + d.y)
				if n.a > 0.0 and not n.is_equal_approx(c):
					edge.append(Vector2i(x, y))
					break
	for e: Vector2i in edge:
		px(e.x, e.y, c)


static func _shade(c: Color, nx: float, ny: float) -> Color:
	var d: float = nx * 0.6 + ny * 0.8
	if d < -0.55:
		return c.lightened(0.22)
	if d > 0.45:
		return c.darkened(0.28)
	return c


## Returns a Prana colour pushed down to enemy-marker saturation (art bible §5.2: 50–60 %).
static func marker(prana: Color, sat: float = 0.55) -> Color:
	return Color.from_hsv(prana.h, minf(prana.s, sat), prana.v * 0.9)
