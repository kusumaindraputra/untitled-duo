## enemy_laser.gd — Telegraphed laser beam fired by a LASER BulletPattern (ADR-0018).
## A thin warning line tracks the owner for telegraph_sec, locks, then the beam is live
## for active_sec. Fayde is hit when her hurtbox touches the beam segment; standing
## just outside it grazes once. Dash i-frames pass through (CONTACT damage source).
class_name EnemyLaser
extends Node2D

enum Phase { TELEGRAPH = 0, ACTIVE = 1, DONE = 2 }

const TUNING: BulletHellTuning = preload("res://assets/data/bullet_hell_tuning.tres")

var pattern: BulletPattern = null
var damage: float = 10.0
## ADR-0019 difficulty curve: multiplies pattern.telegraph_sec (set by the firing enemy).
var telegraph_mult: float = 1.0
## Beam angle (radians). Locked when the telegraph ends.
var angle: float = 0.0
## Node the beam is anchored to during the telegraph (the firing enemy).
var anchor: Node2D = null

var _phase: Phase = Phase.TELEGRAPH
var _timer: float = 0.0
var _grazed: bool = false
var _player: Node2D = null


func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	z_index = 2090
	_timer = _telegraph_sec()
	if is_inside_tree():
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
	add_to_group(&"enemy_hazard")


func _physics_process(delta: float) -> void:
	if pattern == null:
		queue_free()
		return
	_timer -= delta
	match _phase:
		Phase.TELEGRAPH:
			if is_instance_valid(anchor):
				global_position = anchor.global_position
				# Track Fayde for the first 70 % of the telegraph, then lock so the
				# final beam line is a promise the player can read and sidestep.
				if is_instance_valid(_player) and _timer > _telegraph_sec() * 0.3:
					angle = (_player.global_position - global_position).angle()
			if _timer <= 0.0:
				_phase = Phase.ACTIVE
				_timer = pattern.active_sec
		Phase.ACTIVE:
			_check_player()
			if _timer <= 0.0:
				_phase = Phase.DONE
				queue_free()
	queue_redraw()


func _draw() -> void:
	if pattern == null:
		return
	var end: Vector2 = Vector2.from_angle(angle) * pattern.length
	var c: Color = pattern.color
	if _phase == Phase.TELEGRAPH:
		var p: float = 1.0 - clampf(_timer / maxf(_telegraph_sec(), 0.01), 0.0, 1.0)
		draw_line(Vector2.ZERO, end, Color(c.r, c.g, c.b, 0.25 + 0.35 * p), 1.0 + p, true)
	elif _phase == Phase.ACTIVE:
		draw_line(Vector2.ZERO, end, Color(c.r, c.g, c.b, 0.35), pattern.width * 3.0, true)
		draw_line(Vector2.ZERO, end, Color(c.r, c.g, c.b, 0.95), pattern.width * 2.0, true)
		draw_line(Vector2.ZERO, end, Color(1.0, 1.0, 1.0, 0.95), pattern.width * 0.7, true)


## Distance from [param point] (global) to the beam segment.
func distance_to_beam(point: Vector2) -> float:
	var a: Vector2 = global_position
	var b: Vector2 = a + Vector2.from_angle(angle) * (pattern.length if pattern != null else 0.0)
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b))


## Test hook — current phase.
func get_phase() -> Phase:
	return _phase


func _check_player() -> void:
	if not is_instance_valid(_player):
		return
	var d: float = distance_to_beam(_player.global_position)
	if d <= pattern.width + TUNING.player_hurt_radius:
		if _player.has_method(&"register_perfect_dodge"):
			_player.register_perfect_dodge(_player.global_position)  # ADR-0019
		# CONTACT source: dash i-frames and post-hit grace both apply, so the beam
		# cannot multi-hit through the grace window.
		HealthAndDamage.apply_damage(
			_player, damage, GameEnums.DamageClass.NONE, GameEnums.DamageSource.CONTACT)
	elif not _grazed and d <= pattern.width + Projectile.graze_radius_of(_player):
		_grazed = true
		SpellCastingEffects.register_graze(_player.global_position, 1.0)


## Telegraph length after the difficulty curve.
func _telegraph_sec() -> float:
	return (pattern.telegraph_sec if pattern != null else 0.8) * maxf(telegraph_mult, 0.05)
