## projectile.gd — Enemy bullet. Straight, sine or homing flight; damages Fayde by
## distance against her small hurtbox, grazes when it passes close, despawns at range.
## Layer: Gameplay | Story: S8-05 (bullet-hell prototype), SX-GF-03 (gamefeel pass),
## ADR-0018 (bullet patterns, graze, cancel, pooling)
class_name Projectile
extends Area2D

## Default speed / range for bullets launched without a BulletPattern (legacy launch()).
const PROJECTILE_SPEED: float = 220.0
const MAX_RANGE: float = 400.0
## Distance from max range where the bullet starts fading.
const DESPAWN_FADE_DIST: float = 50.0
## Trail length grows to this max over TRAIL_GROW_TIME seconds.
const TRAIL_MAX_LENGTH: float = 30.0
const TRAIL_GROW_TIME: float = 0.15
## Legacy launch() bullets have no pattern: they use the palette's mob core (ADR-0037).
const DEFAULT_ACCENT: StringName = EnemyBulletPalette.DEFAULT_ACCENT
const DEFAULT_RADIUS: float = 4.0

## Every live enemy bullet is in this group — bullet cancel queries it (ADR-0018).
const GROUP: StringName = &"enemy_bullet"

## Collision layer bits (matching project conventions).
## Layer 4 (bit 3, value 8): Projectiles. Mask: walls (bit 0, value 1) and full-cover
## pillars (bit 5, value 32, ADR-0020) —
## Fayde is hit by a distance check against BulletHellTuning.player_hurt_radius,
## so her 8 px movement body no longer defines what counts as a hit.
const COLLISION_LAYER_PROJECTILE: int = 8
const COLLISION_MASK_WALLS: int = 1
const COLLISION_MASK_FULL_COVER: int = 32

const TUNING: BulletHellTuning = preload("res://assets/data/bullet_hell_tuning.tres")
const PALETTE: EnemyBulletPalette = preload("res://assets/data/enemy_bullet_palette.tres")
## High-contrast outline widths past the bullet radius, px (ADR-0032). They sit outside
## the family rim so the option keeps the enemy colour ring (ADR-0037).
const OUTLINE_WHITE: float = 5.5
const OUTLINE_BLACK: float = 3.5
## Family rim ring and dark separator widths past the bullet radius, px (ADR-0037).
const RIM_WIDTH: float = 2.5
const SEPARATOR_WIDTH: float = 1.0

## Who fired this bullet with which attack, for the death recap (DeathRecap.cause()).
## Set by the shooter after launch; cleared on reuse.
var cause: Dictionary = {}

var _direction: Vector2 = Vector2.RIGHT
var _base_damage: float = 1.5
var _distance_traveled: float = 0.0
## Seconds since launch — drives trail growth, sine phase and homing window.
var _alive_time: float = 0.0
## True once the bullet is spent (hit, wall, range, cancel) — guards double despawn.
var _freed: bool = false
var _speed: float = PROJECTILE_SPEED
var _max_range: float = MAX_RANGE
var _radius: float = DEFAULT_RADIUS
## Core colour from the pattern accent; the rim is always PALETTE.rim.
var _color: Color = PALETTE.core_for(DEFAULT_ACCENT)
var _motion: BulletPattern.Motion = BulletPattern.Motion.STRAIGHT
var _sine_amplitude: float = 0.0
var _sine_frequency: float = 0.0
var _homing_turn: float = 0.0
var _homing_duration: float = 0.0
## Centre-line position for SINE motion; the drawn position oscillates around it.
var _line_pos: Vector2 = Vector2.ZERO
## Each bullet grazes at most once.
var _grazed: bool = false
## True once an Assist auto-dash (F2) dodged this bullet.
var _auto_dodged: bool = false
var _player: Node2D = null
var _shape: CircleShape2D = null
## Pool that owns this bullet; null for bullets created with Projectile.new() directly.
var _pool: Node = null


func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	_shape = CircleShape2D.new()
	_shape.radius = _radius
	var col := CollisionShape2D.new()
	col.shape = _shape
	add_child(col)
	collision_layer = COLLISION_LAYER_PROJECTILE
	collision_mask = COLLISION_MASK_WALLS | COLLISION_MASK_FULL_COVER
	monitoring = true
	# Must stay monitorable: in Godot 4.6 an Area2D with monitorable = false no longer
	# reports body_entered for static bodies, so bullets flew through walls and would
	# fly through pillars (ADR-0020). No Area2D masks the projectile layer (8), so
	# being monitorable adds no unwanted overlaps.
	monitorable = true
	z_index = 2100  # above every y-sorted entity (1..2000) so bullets stay readable
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _freed:
		return
	_alive_time += delta
	_advance(delta)
	_distance_traveled += _speed * delta
	queue_redraw()
	_check_player()
	if not _freed and _distance_traveled >= _max_range:
		_despawn()


func _draw() -> void:
	var fade: float = 1.0
	if _distance_traveled > _max_range - DESPAWN_FADE_DIST:
		fade = clampf((_max_range - _distance_traveled) / DESPAWN_FADE_DIST, 0.0, 1.0)
	var c: Color = _color
	var rim: Color = PALETTE.rim
	var sep: Color = PALETTE.separator
	# Trail and glow in the hostile family colour (ADR-0037), so every enemy shot
	# reads as one family however its core is tinted.
	var trail_len: float = lerpf(0.0, TRAIL_MAX_LENGTH, clampf(_alive_time / TRAIL_GROW_TIME, 0.0, 1.0))
	draw_line(-_direction * trail_len, Vector2.ZERO, Color(rim.r, rim.g, rim.b, 0.45 * fade), 3.0, true)
	draw_circle(Vector2.ZERO, _radius * 2.5, Color(rim.r, rim.g, rim.b, 0.16 * fade))
	# ADR-0032 high-contrast option: a thick white ring around a black one, so the
	# bullet's edge reads on any floor and against any other effect.
	if GameSettings.bullet_outline_on():
		draw_circle(Vector2.ZERO, _radius + OUTLINE_WHITE, Color(1.0, 1.0, 1.0, fade))
		draw_circle(Vector2.ZERO, _radius + OUTLINE_BLACK, Color(0.0, 0.0, 0.0, fade))
	# Family rim, dark separator, accent core, white pip.
	draw_circle(Vector2.ZERO, _radius + RIM_WIDTH, Color(rim.r, rim.g, rim.b, fade))
	draw_circle(Vector2.ZERO, _radius + SEPARATOR_WIDTH, Color(sep.r, sep.g, sep.b, sep.a * fade))
	draw_circle(Vector2.ZERO, _radius, Color(c.r, c.g, c.b, 0.95 * fade))
	draw_circle(Vector2.ZERO, _radius * 0.3, Color(1.0, 1.0, 1.0, 0.9 * fade))


## Sets the travel direction (normalised) and damage amount. Call after add_child().
## Legacy entry point: flies straight at PROJECTILE_SPEED for MAX_RANGE.
func launch(direction: Vector2, base_damage: float) -> void:
	_direction = direction.normalized()
	_base_damage = base_damage
	_line_pos = position
	_resolve_player()
	add_to_group(GROUP)


## Launches with the bullet parameters of [param p] at [param bullet_speed].
## Call after add_child() and after setting global_position.
func launch_pattern(direction: Vector2, base_damage: float, p: BulletPattern, bullet_speed: float) -> void:
	_speed = bullet_speed
	_max_range = p.max_range
	_radius = p.bullet_radius
	_color = p.core_color()
	_motion = p.motion
	_sine_amplitude = p.sine_amplitude
	_sine_frequency = p.sine_frequency
	_homing_turn = deg_to_rad(p.homing_turn_deg)
	_homing_duration = p.homing_duration
	if _shape != null:
		_shape.radius = _radius
	launch(direction, base_damage)


## Clears this bullet without damage (Perfect Cast, Special, wave clear).
## Spawns a small pop so the player sees the screen being wiped.
func cancel() -> void:
	if _freed:
		return
	_spawn_impact_burst(Color(1.0, 0.95, 0.6, 1.0))
	_despawn()


## Returns true while the bullet is in flight.
func is_live() -> bool:
	return not _freed


## Pool hook: restores a spent bullet to its launch defaults before reuse.
func reset_for_reuse() -> void:
	_freed = false
	_grazed = false
	_auto_dodged = false
	_alive_time = 0.0
	_distance_traveled = 0.0
	_speed = PROJECTILE_SPEED
	_max_range = MAX_RANGE
	_radius = DEFAULT_RADIUS
	_color = PALETTE.core_for(DEFAULT_ACCENT)
	_motion = BulletPattern.Motion.STRAIGHT
	cause = {}
	visible = true
	process_mode = PROCESS_MODE_PAUSABLE


## Removes every live enemy bullet within [param radius] of [param origin].
## Returns how many were cancelled. radius < 0 clears all of them.
static func cancel_in_radius(tree: SceneTree, origin: Vector2, radius: float) -> int:
	if tree == null:
		return 0
	var n: int = 0
	var r2: float = radius * radius
	for node: Node in tree.get_nodes_in_group(GROUP):
		var p := node as Projectile
		if p == null or not p.is_live():
			continue
		if radius < 0.0 or p.global_position.distance_squared_to(origin) <= r2:
			p.cancel()
			n += 1
	return n


# ── Private ───────────────────────────────────────────────────────────────────

func _advance(delta: float) -> void:
	match _motion:
		BulletPattern.Motion.HOMING:
			if _alive_time <= _homing_duration and is_instance_valid(_player):
				var want: float = (_player.global_position - global_position).angle()
				var cur: float = _direction.angle()
				var diff: float = wrapf(want - cur, -PI, PI)
				var step: float = clampf(diff, -_homing_turn * delta, _homing_turn * delta)
				_direction = Vector2.from_angle(cur + step)
			position += _direction * _speed * delta
		BulletPattern.Motion.SINE:
			_line_pos += _direction * _speed * delta
			var lateral: float = sin(_alive_time * _sine_frequency * TAU) * _sine_amplitude
			position = _line_pos + _direction.orthogonal() * lateral
		_:
			position += _direction * _speed * delta


## Distance-based hit / graze against Fayde (ADR-0018). Dash i-frames let the bullet
## pass through and count as a bigger graze instead of being consumed.
func _check_player() -> void:
	if not is_instance_valid(_player):
		return
	var dist: float = global_position.distance_to(_player.global_position)
	var dashing: bool = _player.has_method(&"is_invincible") and _player.is_invincible()
	if dist <= _radius + TUNING.player_hurt_radius:
		if dashing:
			# ADR-0019 — a dash through a bullet that would have hit is a Perfect Dodge.
			# An Assist auto-dash (F2) lets the bullet pass but earns no Perfect Dodge.
			if _auto_dodged:
				return
			if _player.has_method(&"register_perfect_dodge"):
				_player.register_perfect_dodge(global_position)
			_graze(TUNING.dash_graze_mult)
			return
		if _player.has_method(&"try_auto_dash") and _player.try_auto_dash():
			_auto_dodged = true
			return
		HealthAndDamage.apply_damage(
			_player, _base_damage, GameEnums.DamageClass.NONE, GameEnums.DamageSource.CONTACT, cause)
		_despawn()
		return
	if dist <= _radius + graze_radius_of(_player):
		_graze(TUNING.dash_graze_mult if dashing else 1.0)


## Graze ring radius for [param player]: its sigil-scaled get_graze_radius() when it
## has one, else BulletHellTuning.graze_radius. Shared by bullets, lasers and mortars.
static func graze_radius_of(player: Node) -> float:
	if is_instance_valid(player) and player.has_method(&"get_graze_radius"):
		return float(player.get_graze_radius())
	return TUNING.graze_radius


func _graze(mult: float) -> void:
	if _grazed:
		return
	_grazed = true
	SpellCastingEffects.register_graze(global_position, mult)
	_spawn_impact_burst(Color(1.0, 1.0, 1.0, 0.8), 0.5)


func _resolve_player() -> void:
	if _player == null and is_inside_tree():
		_player = get_tree().get_first_node_in_group(&"player") as Node2D


func _despawn() -> void:
	if _freed:
		return
	_freed = true
	visible = false
	if is_in_group(GROUP):
		remove_from_group(GROUP)
	if is_instance_valid(_pool) and _pool.has_method(&"release"):
		_pool.call_deferred(&"release", self)
	else:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _freed:
		return
	# ADR-0020 — a pillar absorbs the bullet and wears down.
	if body is CoverPillar:
		(body as CoverPillar).take_hit(1)
	# Wall / pillar impact — brief impact flash in the family colour, then despawn.
	_spawn_impact_burst(PALETTE.rim)
	_despawn()


## Spawns a brief impact burst at the bullet's position (wall hit, cancel, graze).
func _spawn_impact_burst(c: Color, size_mult: float = 1.0) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var burst := _WallImpact.new()
	burst.color = c
	burst.size_mult = size_mult
	burst.global_position = global_position
	# Attach to the same parent (arena/WaveManager/pool) so it outlives the bullet.
	parent_node.add_child(burst)


## Inner class: short-lived impact flash.
## Draws an expanding ring + starburst, auto-frees after 0.12 s.
class _WallImpact extends Node2D:
	const IMPACT_DURATION: float = 0.12

	var color: Color = Color(0.4, 0.6, 1.0, 1.0)
	var size_mult: float = 1.0
	var _start_us: int = 0

	func _ready() -> void:
		process_mode = PROCESS_MODE_ALWAYS
		z_index = 2150
		_start_us = Time.get_ticks_usec()

	func _process(_delta: float) -> void:
		if Time.get_ticks_usec() - _start_us >= int(IMPACT_DURATION * 1_000_000.0):
			queue_free()
		else:
			queue_redraw()

	func _draw() -> void:
		var elapsed: float = float(Time.get_ticks_usec() - _start_us) / 1_000_000.0
		var p: float = clampf(elapsed / IMPACT_DURATION, 0.0, 1.0)
		var alpha: float = (1.0 - p) * color.a
		var c: Color = Color(color.r, color.g, color.b, alpha)
		# Expanding ring.
		var ring_r: float = lerpf(4.0, 22.0, p) * size_mult
		draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 12, c, 2.5, true)
		# 4-point starburst.
		for i: int in 4:
			var angle: float = (TAU / 4.0) * float(i)
			var spoke_len: float = lerpf(5.0, 18.0, p) * size_mult
			draw_line(Vector2.ZERO, Vector2.from_angle(angle) * spoke_len,
					Color(c.r, c.g, c.b, alpha * 0.6), 2.0, true)
