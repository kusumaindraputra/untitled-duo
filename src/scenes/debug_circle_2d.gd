## debug_circle_2d.gd — Isometric grey-box placeholder visual (ADR-0001).
##
## Draws an isometric-appropriate humanoid silhouette instead of a flat circle:
##   - flat shadow ellipse at feet  (ground-contact depth cue — art bible Ref 6)
##   - body rectangle + head circle (~34px total, within 32–48px isometric target)
##   - vertical accent above head   (player only — "single vertical accent", art bible 3.2)
##   - facing direction arrow / cast beam (player only)
##
## Origin (0,0) = feet / ground-contact point.
## Remove when real sprites replace PlayerController and EnemyInstance.
extends Node2D

## Body fill colour. Player = Color.WHITE; enemies = per-EnemyInstance.tscn export.
@export var color: Color = Color.WHITE
## Legacy radius export — kept so EnemyInstance.tscn loads without error.
@export var radius: float = 8.0
## True once a PixelCharacter sprite draws the body (ADR-0022): only the ground
## shadow and the player's aim / cast beam are drawn here.
@export var hide_body: bool = false

const _BODY_W: float = 12.0
const _BODY_H: float = 24.0
const _HEAD_R: float = 5.0
const _SHADOW_RX: float = 10.0
const _SHADOW_RY: float = 4.0

func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var outline: Color = color.darkened(0.45)

	# Ground-contact shadow — the single most important isometric depth cue.
	# Ellipse at feet tells the eye exactly where on the floor the entity stands.
	_draw_ellipse(Vector2(0.0, 2.0), _SHADOW_RX, _SHADOW_RY, Color(0.0, 0.0, 0.0, 0.50))

	var head_cy: float = -_BODY_H - _HEAD_R
	if not hide_body:
		# Body — feet at origin, extends upward (negative Y)
		var body_rect := Rect2(-_BODY_W * 0.5, -_BODY_H, _BODY_W, _BODY_H)
		draw_rect(body_rect, outline)
		draw_rect(body_rect.grow(-1.0), color)

		# Head — sits directly above the body
		draw_circle(Vector2(0.0, head_cy), _HEAD_R + 1.0, outline)
		draw_circle(Vector2(0.0, head_cy), _HEAD_R, color)

	var parent := get_parent()
	if not (parent and parent.has_method(&"get_facing_direction")):
		return

	if not hide_body:
		# Vertical accent — player-only identifier (art bible 3.2: "single vertical accent")
		var accent_base_y: float = head_cy - _HEAD_R
		draw_line(
			Vector2(0.0, accent_base_y),
			Vector2(0.0, accent_base_y - 9.0),
			color.lightened(0.35),
			2.0
		)

	# Facing direction arrow or cast beam
	var dir: Vector2 = parent.get_facing_direction()
	var casting: bool = parent.get(&"_cast_beam_timer") > 0.0
	if casting:
		var prana_type: int = parent.get(&"_cast_prana_type") if parent.get(&"_cast_prana_type") != null else -1
		_draw_cast_beam(dir, prana_type)
	else:
		draw_line(Vector2.ZERO, dir * (_BODY_W * 0.5 + 8.0), Color.YELLOW, 2.0)


## Draws a per-prana-type cast beam. Placeholder until real sprites replace this node.
## DamageClass enum: FIRE=0, SHADOW=1, LIGHTNING=2, ICE=3, NATURE=4.
func _draw_cast_beam(dir: Vector2, prana_type: int) -> void:
	match prana_type:
		0: # Fire — short thick orange-red burst
			draw_line(Vector2.ZERO, dir * 68.0, Color(1.0, 0.35, 0.05, 1.0), 5.0)
			draw_line(Vector2.ZERO, dir * 48.0, Color(1.0, 0.75, 0.2, 0.7), 3.0)
		1: # Shadow — long thin purple ray
			draw_line(Vector2.ZERO, dir * 95.0, Color(0.45, 0.1, 0.85, 1.0), 2.0)
			draw_line(Vector2.ZERO, dir * 85.0, Color(0.8, 0.4, 1.0, 0.5), 1.0)
		2: # Lightning — zigzag bolt
			var perp: Vector2 = Vector2(-dir.y, dir.x)
			var pts := PackedVector2Array([
				Vector2.ZERO,
				dir * 30.0 + perp * 6.0,
				dir * 55.0 - perp * 5.0,
				dir * 100.0,
			])
			draw_polyline(pts, Color(1.0, 1.0, 0.1, 1.0), 2.5, true)
		3: # Ice — medium blue crystalline line
			draw_line(Vector2.ZERO, dir * 72.0, Color(0.3, 0.75, 1.0, 1.0), 4.0)
			var perp: Vector2 = Vector2(-dir.y, dir.x)
			draw_line(dir * 36.0 - perp * 5.0, dir * 36.0 + perp * 5.0, Color(0.7, 0.95, 1.0, 0.9), 2.0)
		4: # Nature — medium thick green pulse
			draw_line(Vector2.ZERO, dir * 75.0, Color(0.15, 0.85, 0.25, 1.0), 4.0)
			draw_line(Vector2.ZERO, dir * 55.0, Color(0.6, 1.0, 0.4, 0.6), 2.0)
		_: # Unresolved — original gold fallback
			draw_line(Vector2.ZERO, dir * 80.0, Color(1.0, 0.8, 0.2, 1.0), 3.0)


## Draws a filled ellipse using a polygon approximation.
## Godot 4 has no native draw_ellipse — draw_colored_polygon is the cleanest substitute.
func _draw_ellipse(center: Vector2, rx: float, ry: float, c: Color) -> void:
	const SEGS: int = 12
	var pts := PackedVector2Array()
	pts.resize(SEGS)
	for i: int in SEGS:
		var a: float = TAU * i / SEGS
		pts[i] = center + Vector2(cos(a) * rx, sin(a) * ry)
	draw_colored_polygon(pts, c)
