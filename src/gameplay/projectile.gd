## projectile.gd — Straight-line projectile fired by SHOOTER enemies.
## Moves in a locked direction, damages the player on overlap, despawns at max range.
## Layer: Gameplay | Story: S8-05 (bullet-hell prototype), SX-GF-03 (gamefeel pass)
class_name Projectile
extends Area2D

const PROJECTILE_SPEED: float = 220.0
const MAX_RANGE: float = 400.0
## Distance from MAX_RANGE where trail starts fading.
const DESPAWN_FADE_DIST: float = 50.0
## Trail length grows to this max over TRAIL_GROW_TIME seconds.
const TRAIL_MAX_LENGTH: float = 30.0
const TRAIL_GROW_TIME: float = 0.15

## Collision layer bits (matching project conventions).
## Layer 4 (bit 3, value  8): Projectiles.
## Layer 1 (bit 0, value  1): Walls/Walls.
## Layer 2 (bit 1, value  2): Player.
const COLLISION_LAYER_PROJECTILE: int = 8
const COLLISION_MASK_WALLS_AND_PLAYER: int = 3  # bits 0+1: walls (1) + player (2)

var _direction: Vector2 = Vector2.RIGHT
var _base_damage: float = 1.5
var _distance_traveled: float = 0.0
## Seconds since launch — drives trail growth.
var _alive_time: float = 0.0
## True after queue_free is called — guards against double-free on simultaneous wall+range hit.
var _freed: bool = false


func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	var shape := CircleShape2D.new()
	shape.radius = 4.0
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	collision_layer = COLLISION_LAYER_PROJECTILE
	collision_mask = COLLISION_MASK_WALLS_AND_PLAYER
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_alive_time += delta
	position += _direction * PROJECTILE_SPEED * delta
	_distance_traveled += PROJECTILE_SPEED * delta
	queue_redraw()
	if _distance_traveled >= MAX_RANGE and not _freed:
		_freed = true
		queue_free()


func _draw() -> void:
	var fade: float = 1.0
	if _distance_traveled > MAX_RANGE - DESPAWN_FADE_DIST:
		fade = (MAX_RANGE - _distance_traveled) / DESPAWN_FADE_DIST
		fade = clampf(fade, 0.0, 1.0)
	# Trail line behind the projectile.
	var trail_len: float = lerpf(0.0, TRAIL_MAX_LENGTH, clampf(_alive_time / TRAIL_GROW_TIME, 0.0, 1.0))
	var trail_start: Vector2 = -_direction * trail_len
	draw_line(trail_start, Vector2.ZERO, Color(0.15, 0.35, 0.9, 0.5 * fade), 3.0, true)
	# Outer glow circle.
	draw_circle(Vector2.ZERO, 10.0, Color(0.15, 0.35, 0.9, 0.15 * fade))
	# Core circle.
	draw_circle(Vector2.ZERO, 5.0, Color(0.6, 0.8, 1.0, 0.9 * fade))


## Sets the travel direction (normalised) and damage amount. Call after add_child().
func launch(direction: Vector2, base_damage: float) -> void:
	_direction = direction.normalized()
	_base_damage = base_damage


func _on_body_entered(body: Node2D) -> void:
	if _freed:
		return
	if body.is_in_group(&"player"):
		HealthAndDamage.apply_damage(
			body, _base_damage, GameEnums.DamageClass.NONE, GameEnums.DamageSource.CONTACT)
		_freed = true
		queue_free()
		return
	# Wall impact — brief impact flash then despawn.
	_spawn_impact_burst()
	_freed = true
	queue_free()


## Spawns a brief impact burst at the projectile's position when it hits a wall.
## Modulate pulse: scale 1→3 over 0.10s with alpha 0.8→0, then auto-free.
func _spawn_impact_burst() -> void:
	var burst := _WallImpact.new()
	burst.global_position = global_position
	# Attach to the same parent (arena/WaveManager) so it outlives the projectile.
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	parent_node.add_child(burst)


## Inner class: short-lived wall-impact flash.
## Draws an expanding ring + starburst, auto-frees after 0.12 s.
class _WallImpact extends Node2D:
	const IMPACT_DURATION: float = 0.12

	var _start_us: int = 0

	func _ready() -> void:
		process_mode = PROCESS_MODE_ALWAYS
		z_index = 95
		_start_us = Time.get_ticks_usec()

	func _process(_delta: float) -> void:
		if Time.get_ticks_usec() - _start_us >= int(IMPACT_DURATION * 1_000_000.0):
			queue_free()
		else:
			queue_redraw()

	func _draw() -> void:
		var elapsed: float = float(Time.get_ticks_usec() - _start_us) / 1_000_000.0
		var p: float = clampf(elapsed / IMPACT_DURATION, 0.0, 1.0)
		var alpha: float = 1.0 - p
		var c: Color = Color(0.4, 0.6, 1.0, alpha)
		# Expanding ring.
		var ring_r: float = lerpf(4.0, 22.0, p)
		draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 12, c, 2.5, true)
		# 4-point starburst.
		for i: int in 4:
			var angle: float = (TAU / 4.0) * float(i)
			var spoke_len: float = lerpf(5.0, 18.0, p)
			draw_line(Vector2.ZERO, Vector2.from_angle(angle) * spoke_len,
					Color(c.r, c.g, c.b, alpha * 0.6), 2.0, true)
