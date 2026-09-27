## OffscreenIndicators — edge-of-screen arrows for enemies the camera cannot see.
##
## The combat camera sits at zoom 2.0 (ADR-0024), so a room is bigger than the
## screen and enemies often fire from outside it. Each living enemy outside the view
## gets a small arrow on the screen edge, pointing at it. Arrows get more opaque the
## closer the enemy is, elites and bosses get a larger gold / violet arrow, and an
## arrow flashes white while its enemy winds up a volley, so off-screen attacks are
## telegraphed too. Dormant enemies (not yet aggroed) are drawn dim.
##
## Lives on the HUD CanvasLayer; wired in debug_game_loop._ready(). Draws nothing
## outside COMBAT_PHASE. Placement maths are static so tests run headless.
class_name OffscreenIndicators
extends Control

## Distance (px) the arrow tip keeps from the screen edge.
const EDGE_MARGIN: float = 26.0
## An enemy this far inside the edge still counts as on-screen (its sprite is visible).
const ONSCREEN_PAD: float = 12.0
## Arrow length / half-width in px for normal and major (elite, boss) enemies.
const ARROW_LEN: float = 14.0
const ARROW_HALF_W: float = 8.0
const MAJOR_SCALE: float = 1.45
## World distance at which an arrow is fully opaque; it fades toward MIN_ALPHA at FAR.
const NEAR_DIST: float = 260.0
const FAR_DIST: float = 1100.0
const MIN_ALPHA: float = 0.35
const DORMANT_ALPHA: float = 0.25

const COLOR_NORMAL := Color(1.0, 0.32, 0.28)
const COLOR_ELITE := Color(1.0, 0.8, 0.25)
## Same hue as a normal enemy: boss colours never appear on UI (art bible §4.3);
## MAJOR_SCALE makes the boss arrow stand out.
const COLOR_BOSS := Color(1.0, 0.32, 0.28)
const COLOR_WINDUP := Color(1.0, 1.0, 1.0)

## Player node; arrows fade by world distance to it. Set by the parent.
var player: Node2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not is_inside_tree() or not _in_combat():
		return
	var vp: Viewport = get_viewport()
	var rect := Rect2(Vector2.ZERO, vp.get_visible_rect().size)
	var xf: Transform2D = vp.get_canvas_transform()
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Node2D
		if enemy == null or not enemy.is_inside_tree():
			continue
		if enemy.has_method(&"is_alive") and not enemy.is_alive():
			continue
		var screen_pos: Vector2 = xf * enemy.global_position
		if not is_offscreen(screen_pos, rect, ONSCREEN_PAD):
			continue
		_draw_arrow(enemy, screen_pos, rect)


func _draw_arrow(enemy: Node2D, screen_pos: Vector2, rect: Rect2) -> void:
	var tip: Vector2 = edge_point(screen_pos, rect, EDGE_MARGIN)
	var dir: Vector2 = (screen_pos - rect.get_center()).normalized()
	var major: bool = _call_bool(enemy, &"is_boss") or _call_bool(enemy, &"is_elite")
	var color: Color = COLOR_NORMAL
	if _call_bool(enemy, &"is_boss"):
		color = COLOR_BOSS
	elif _call_bool(enemy, &"is_elite"):
		color = COLOR_ELITE
	var alpha: float = DORMANT_ALPHA if _call_bool(enemy, &"is_dormant") else 1.0
	if alpha >= 1.0 and is_instance_valid(player):
		alpha = alpha_for_distance(player.global_position.distance_to(enemy.global_position))
	if _call_bool(enemy, &"is_winding_up"):
		# Pulse between the enemy colour and white while a volley charges.
		var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.03)
		color = color.lerp(COLOR_WINDUP, pulse)
		alpha = 1.0
	var s: float = MAJOR_SCALE if major else 1.0
	var back: Vector2 = tip - dir * ARROW_LEN * s
	var side: Vector2 = dir.orthogonal() * ARROW_HALF_W * s
	var pts := PackedVector2Array([tip, back + side, back - side])
	draw_colored_polygon(pts, Color(color.r, color.g, color.b, alpha))
	var outline := PackedVector2Array([tip, back + side, back - side, tip])
	draw_polyline(outline, Color(0.05, 0.03, 0.08, alpha * 0.9), 2.0)


func _in_combat() -> bool:
	var gsm: Node = get_node_or_null(^"/root/GameStateManager")
	return gsm != null and gsm.get_active_state() == GameEnums.GameState.COMBAT_PHASE


static func _call_bool(obj: Object, method: StringName) -> bool:
	return obj.has_method(method) and bool(obj.call(method))


## True when [param screen_pos] lies outside [param rect] shrunk by [param pad].
static func is_offscreen(screen_pos: Vector2, rect: Rect2, pad: float) -> bool:
	return not rect.grow(-pad).has_point(screen_pos)


## Where the arrow tip goes: the point where the ray from the screen centre toward
## [param screen_pos] crosses [param rect] shrunk by [param margin].
static func edge_point(screen_pos: Vector2, rect: Rect2, margin: float) -> Vector2:
	var inner: Rect2 = rect.grow(-margin)
	var c: Vector2 = rect.get_center()
	var d: Vector2 = screen_pos - c
	if d.is_zero_approx():
		return c
	var half: Vector2 = inner.size * 0.5
	var tx: float = INF if is_zero_approx(d.x) else half.x / absf(d.x)
	var ty: float = INF if is_zero_approx(d.y) else half.y / absf(d.y)
	return c + d * minf(tx, ty)


## Arrow opacity for an enemy [param dist] world px away: 1 up close, MIN_ALPHA far.
static func alpha_for_distance(dist: float) -> float:
	var t: float = clampf((dist - NEAR_DIST) / (FAR_DIST - NEAR_DIST), 0.0, 1.0)
	return lerpf(1.0, MIN_ALPHA, t)
