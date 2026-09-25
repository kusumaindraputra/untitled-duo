## hazard_sweep_laser.gd — Pylon with rotating beam arms (ADR-0020).
##
## After a short harmless telegraph, each arm is a live beam that sweeps the room.
## Pillars and arena walls cut the beam short (pillars are not worn down by it), so a
## pillar is a safe pocket for one pass. Touching a beam deals spec.damage; dashing through counts as
## a Perfect Dodge; passing close grazes.
class_name HazardSweepLaser
extends StageHazard

## Physics layer for the pylon base: half cover.
const BASE_LAYER: int = 16
const BASE_RADIUS: float = 14.0
## Seconds before the same arm can graze again.
const GRAZE_COOLDOWN_SEC: float = 0.6
## Beams stop at walls (1, unless spec.stop_at_walls is off) and pillars (32).
const WALL_LAYER: int = 1

var _angle: float = 0.0
## Current length of each arm after pillars cut it.
var _lengths: PackedFloat32Array = PackedFloat32Array()
var _graze_cd: float = 0.0


func _ready() -> void:
	super._ready()
	var body := StaticBody2D.new()
	body.collision_layer = BASE_LAYER
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = BASE_RADIUS
	shape.shape = circle
	body.add_child(shape)
	add_child(body)
	z_index = 2080  # beams draw over the floor and entities, under bullets


## Pure: angle of arm [param arm] after [param t] seconds at [param deg_per_sec],
## with [param arm_count] arms spread evenly.
static func arm_angle(t: float, deg_per_sec: float, arm: int, arm_count: int) -> float:
	return deg_to_rad(deg_per_sec) * t + TAU * float(arm) / float(maxi(arm_count, 1))


## True once the telegraph is over and the beams hurt.
func is_live() -> bool:
	return _active and _active_time >= spec.warmup_sec


## Distance from [param point] (global) to the nearest arm, using current lengths.
func distance_to_arms(point: Vector2) -> float:
	var best: float = INF
	for i: int in maxi(spec.arm_count, 1):
		var dir: Vector2 = Vector2.from_angle(arm_angle(_active_time, spec.rotation_deg_per_sec, i, spec.arm_count))
		var a: Vector2 = global_position + dir * spec.arm_inner_radius
		var seg_len: float = _lengths[i] if i < _lengths.size() else _reach()
		var b: Vector2 = a + dir * seg_len
		best = minf(best, point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b)))
	return best


func _on_activated() -> void:
	_live_cue_played = false
	_lengths.resize(maxi(spec.arm_count, 1))
	for i: int in _lengths.size():
		_lengths[i] = _reach()


## Beam reach past the inner radius, before anything blocks it.
func _reach() -> float:
	return maxf(spec.arm_length - spec.arm_inner_radius, 0.0)


## True once the live-beam cue has played for this activation.
var _live_cue_played: bool = false


func _hazard_tick(delta: float) -> void:
	_graze_cd = maxf(_graze_cd - delta, 0.0)
	if not _live_cue_played and is_live():
		_live_cue_played = true
		Sfx.play(&"sfx_laser_fire")
	var world: World2D = get_world_2d() if is_inside_tree() else null
	for i: int in _lengths.size():
		var a: float = arm_angle(_active_time, spec.rotation_deg_per_sec, i, spec.arm_count)
		var start: Vector2 = global_position + Vector2.from_angle(a) * spec.arm_inner_radius
		var mask: int = CoverPillar.LAYER_FULL_COVER | (WALL_LAYER if spec.stop_at_walls else 0)
		_lengths[i] = float(CoverPillar.cast_beam(world, start, a, _reach(), mask)["length"])
	if not is_live() or not is_instance_valid(_player):
		return
	var d: float = distance_to_arms(_player.global_position)
	if d <= spec.beam_width + TUNING.player_hurt_radius:
		_hit_player(true)
	elif _graze_cd <= 0.0 and d <= spec.beam_width + Projectile.graze_radius_of(_player):
		_graze_cd = GRAZE_COOLDOWN_SEC
		SpellCastingEffects.register_graze(_player.global_position, 1.0)


func _draw() -> void:
	if spec == null:
		return
	var c: Color = spec.color
	draw_colored_polygon(CoverPillar._ellipse(Vector2(0, 2), BASE_RADIUS * 1.3, BASE_RADIUS * 0.6), Color(0, 0, 0, 0.5))
	draw_colored_polygon(CoverPillar._ellipse(Vector2(0, -6), BASE_RADIUS, BASE_RADIUS * 0.5), Color(0.2, 0.18, 0.24, 1.0))
	draw_circle(Vector2(0, -10), 5.0, Color(c.r, c.g, c.b, 0.9 if _active else 0.35))
	if not _active:
		return
	for i: int in _lengths.size():
		var dir: Vector2 = Vector2.from_angle(arm_angle(_active_time, spec.rotation_deg_per_sec, i, spec.arm_count))
		var start: Vector2 = dir * spec.arm_inner_radius
		var end: Vector2 = start + dir * _lengths[i]
		if is_live():
			draw_line(start, end, Color(c.r, c.g, c.b, 0.3), spec.beam_width * 3.0, true)
			draw_line(start, end, Color(c.r, c.g, c.b, 0.95), spec.beam_width * 2.0, true)
			draw_line(start, end, Color(1, 1, 1, 0.9), spec.beam_width * 0.7, true)
		else:
			var p: float = clampf(_active_time / maxf(spec.warmup_sec, 0.01), 0.0, 1.0)
			draw_line(start, end, Color(c.r, c.g, c.b, 0.2 + 0.4 * p), 1.0 + p, true)
