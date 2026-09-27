## quad_batch.gd — Static flat-coloured quads drawn by one CanvasItem (ADR-0050).
##
## On the Compatibility renderer every Polygon2D and Line2D is its own draw call, so the
## room's rim ledge and platform edge (hundreds of small faces) cost more draw calls than
## the whole fight. A QuadBatch keeps the same faces as four-point primitives in one
## node; primitives with no texture batch into a single draw call. Drawn once, redrawn
## only when quads change.
class_name QuadBatch
extends Node2D

var _points: Array[PackedVector2Array] = []
var _colors: Array[PackedColorArray] = []


## Adds a quad with one colour per corner ([param points] and [param colors] hold 4).
func add_quad(points: PackedVector2Array, colors: PackedColorArray) -> void:
	assert(points.size() == 4 and colors.size() == 4)
	_points.append(points)
	_colors.append(colors)
	queue_redraw()


## Adds a quad in one flat colour.
func add_flat(points: PackedVector2Array, color: Color) -> void:
	add_quad(points, PackedColorArray([color, color, color, color]))


## Adds a straight segment [param a]–[param b] of [param width] px as a quad, the way a
## Line2D with no caps draws it.
func add_segment(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	if a.is_equal_approx(b):
		return
	var side: Vector2 = (b - a).normalized().orthogonal() * (width * 0.5)
	add_flat(PackedVector2Array([a + side, b + side, b - side, a - side]), color)


## Number of quads (tests).
func quad_count() -> int:
	return _points.size()


## Corners of quad [param i] (tests).
func quad_points(i: int) -> PackedVector2Array:
	return _points[i]


func _draw() -> void:
	for i: int in _points.size():
		draw_primitive(_points[i], _colors[i], PackedVector2Array())
