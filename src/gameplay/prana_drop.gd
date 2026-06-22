## PranaDrop — a collectible Prana fragment dropped when an enemy dies.
##
## Spawned by EnemyInstance on death (rolled against EnemyType.drop_rate). Draws a
## small bobbing gem in the Prana type colour. Uses distance-based pickup (no
## physics layers): drifts toward Fayde within MAGNET_RADIUS and is collected within
## PICKUP_RADIUS, adding to PranaInventory (found via group). Frees itself on the
## next preparation phase so uncollected drops don't linger into the next room.
class_name PranaDrop
extends Node2D

## Pixels within which the drop is collected on contact with Fayde.
const PICKUP_RADIUS: float = 22.0
## Pixels within which the drop magnetises toward Fayde.
const MAGNET_RADIUS: float = 72.0
## Magnet drift speed in px/s when inside MAGNET_RADIUS.
const MAGNET_SPEED: float = 240.0
## Vertical bob amplitude / frequency for the idle float.
const BOB_AMPLITUDE: float = 4.0
const BOB_FREQUENCY: float = 2.4
## Half-size of the gem diamond in px.
const GEM_RADIUS: float = 9.0

## Prana type id this drop grants (0–4). Set via setup() before add_child.
var prana_type_id: int = 0

var _color: Color = Color.WHITE
var _spawn_us: int = 0
var _collected: bool = false


## Configures the drop's Prana type. Call before adding to the tree.
func setup(type_id: int) -> void:
	prana_type_id = type_id


func _ready() -> void:
	add_to_group(&"prana_drop")
	z_index = 40
	_spawn_us = Time.get_ticks_usec()
	_color = _resolve_color(prana_type_id)
	# Pop-in scale (small overshoot) so the drop reads as "appearing".
	scale = Vector2.ZERO
	var tw: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.22)
	# Vanish if the player leaves the room without collecting.
	GameStateManager.preparation_started.connect(_on_preparation_started)


func _exit_tree() -> void:
	if GameStateManager.preparation_started.is_connected(_on_preparation_started):
		GameStateManager.preparation_started.disconnect(_on_preparation_started)


func _process(delta: float) -> void:
	queue_redraw()  # animate bob/pulse
	if _collected:
		return
	var player: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
	if not is_instance_valid(player):
		return
	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()
	if dist <= PICKUP_RADIUS:
		_collect()
	elif dist <= MAGNET_RADIUS and dist > 0.001:
		global_position += to_player / dist * MAGNET_SPEED * delta


func _draw() -> void:
	var elapsed: float = float(Time.get_ticks_usec() - _spawn_us) / 1_000_000.0
	var bob: float = sin(elapsed * TAU * BOB_FREQUENCY) * BOB_AMPLITUDE
	var c: Vector2 = Vector2(0.0, bob)
	var r: float = GEM_RADIUS
	# Diamond gem: outline → body → bright core.
	var pts: PackedVector2Array = PackedVector2Array([
		c + Vector2(0.0, -r), c + Vector2(r * 0.72, 0.0),
		c + Vector2(0.0, r), c + Vector2(-r * 0.72, 0.0),
	])
	draw_colored_polygon(pts, _color)
	var core: PackedVector2Array = PackedVector2Array([
		c + Vector2(0.0, -r * 0.45), c + Vector2(r * 0.34, 0.0),
		c + Vector2(0.0, r * 0.45), c + Vector2(-r * 0.34, 0.0),
	])
	draw_colored_polygon(core, _color.lightened(0.5))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]),
		Color(0, 0, 0, 0.5), 1.5)


## Resolves the display colour for [param type_id] from PranaCatalog, falling back
## to the Art Bible token palette, then white.
func _resolve_color(type_id: int) -> Color:
	var pt: PranaType = PranaCatalog.get_type(type_id)
	if pt != null:
		return pt.color
	if type_id >= 0 and type_id < PranaTypeToken.TYPE_COLORS.size():
		return PranaTypeToken.TYPE_COLORS[type_id]
	return Color.WHITE


## Adds this drop to the run inventory and despawns with a brief flash.
func _collect() -> void:
	if _collected:
		return
	_collected = true
	var inv: Node = get_tree().get_first_node_in_group(&"prana_inventory")
	if inv != null and inv.has_method(&"add"):
		inv.add(prana_type_id, 1)
	var audio: Node = get_node_or_null("/root/AudioSystem")
	if audio != null and audio.has_method(&"has_event") and audio.has_event(&"sfx_prana_collected"):
		audio.play_event(&"sfx_prana_collected")
	# Quick collect pop: scale up + fade, then free.
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.6, 1.6), 0.14)
	tw.tween_property(self, "modulate:a", 0.0, 0.14)
	tw.chain().tween_callback(queue_free)


func _on_preparation_started(_idx: int = 0, _rem: int = 0) -> void:
	queue_free()
