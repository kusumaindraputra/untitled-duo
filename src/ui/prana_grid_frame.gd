## PranaGridFrame — the octagonal frame around the 3×3 Prana grid (ADR-0042, art bible
## §3.4 "The Space of Decision").
##
## "Octagonal frame (8 sides). Visually distinct from every other UI and environment
## element. Communicates: this is an instrument, not an inventory." Four small Prana
## fragment ornaments sit on the diagonal edges; they do nothing. A MarginContainer,
## so the grid inside keeps its own layout and hit areas.
class_name PranaGridFrame
extends MarginContainer

## Inset of the grid from the frame edge, in px.
const PAD: int = 12
## How far each corner is cut, as a share of the shorter side.
const CUT_SHARE: float = 0.2
## Frame fill (E6 haze, translucent) and edge (E7).
const FILL := Color(UIPalette.VOID, 0.55)
const EDGE := UIPalette.BORDER
const EDGE_WIDTH: float = 2.0
## Ornament half-size in px and how far they blend toward E7 (muted, non-functional).
const ORNAMENT_HALF: float = 4.0
const ORNAMENT_MUTE: float = 0.45
## Prana type per ornament (Ashfire, Voidblue, Stormgold, Deepfrost; clockwise from top-left).
const ORNAMENT_TYPES: Array[int] = [0, 1, 2, 3]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, PAD)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var pts: PackedVector2Array = octagon_points(size, CUT_SHARE)
	if pts.is_empty():
		return
	draw_colored_polygon(pts, FILL)
	var ring := pts.duplicate()
	ring.append(pts[0])
	draw_polyline(ring, EDGE, EDGE_WIDTH, true)
	var centres: PackedVector2Array = ornament_centres(pts)
	for i: int in centres.size():
		var c: Color = PranaTypeToken.type_color(ORNAMENT_TYPES[i]).lerp(EDGE, ORNAMENT_MUTE)
		var o: Vector2 = centres[i]
		var h: float = ORNAMENT_HALF
		draw_colored_polygon(PackedVector2Array([o + Vector2(0, -h), o + Vector2(h, 0),
			o + Vector2(0, h), o + Vector2(-h, 0)]), c)


## Pure: the eight corners of an octagon filling [param rect_size], clockwise from the
## top edge's left end. Each corner is cut by [param cut_share] of the shorter side.
## Empty for a degenerate size.
static func octagon_points(rect_size: Vector2, cut_share: float) -> PackedVector2Array:
	if rect_size.x <= 0.0 or rect_size.y <= 0.0:
		return PackedVector2Array()
	var c: float = minf(rect_size.x, rect_size.y) * clampf(cut_share, 0.0, 0.5)
	var w: float = rect_size.x
	var h: float = rect_size.y
	return PackedVector2Array([
		Vector2(c, 0), Vector2(w - c, 0), Vector2(w, c), Vector2(w, h - c),
		Vector2(w - c, h), Vector2(c, h), Vector2(0, h - c), Vector2(0, c),
	])


## Pure: midpoints of the four diagonal edges of [param pts] (from octagon_points),
## clockwise from the top-left: where the ornaments sit.
static func ornament_centres(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() != 8:
		return PackedVector2Array()
	return PackedVector2Array([
		(pts[7] + pts[0]) * 0.5, (pts[1] + pts[2]) * 0.5,
		(pts[3] + pts[4]) * 0.5, (pts[5] + pts[6]) * 0.5,
	])
