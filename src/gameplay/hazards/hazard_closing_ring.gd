## hazard_closing_ring.gd — Danger band that closes in from the room edge (ADR-0020).
##
## After ring_delay_sec, the safe area shrinks from ring_start_scale to ring_min_scale
## of the room diamond over ring_close_sec. Standing outside it deals spec.damage
## (post-hit grace spaces the ticks). Pushes long fights toward the centre instead of
## letting the player kite around the rim forever.
class_name HazardClosingRing
extends StageHazard

## Room diamond half-extents in pixels. Set by IsometricRoom before add_child().
var half_extents: Vector2 = Vector2(640, 384)


## Pure: safe-area scale [param t] seconds after combat started, for [param s].
static func scale_at(t: float, s: HazardSpec) -> float:
	if t <= s.ring_delay_sec:
		return s.ring_start_scale
	var p: float = clampf((t - s.ring_delay_sec) / maxf(s.ring_close_sec, 0.01), 0.0, 1.0)
	return lerpf(s.ring_start_scale, s.ring_min_scale, p)


## Pure: diamond norm of [param offset] for a room with [param extents] (1.0 = wall).
static func diamond_norm(offset: Vector2, extents: Vector2) -> float:
	return absf(offset.x) / maxf(extents.x, 1.0) + absf(offset.y) / maxf(extents.y, 1.0)


## Current safe-area scale (ring_start_scale while inactive).
func get_safe_scale() -> float:
	return scale_at(_active_time, spec) if _active else spec.ring_start_scale


func _ready() -> void:
	super._ready()
	z_index = 3


func _hazard_tick(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	if diamond_norm(_player.global_position - global_position, half_extents) > get_safe_scale():
		_hit_player(false)


func _draw() -> void:
	if spec == null or not _active:
		return
	var c: Color = spec.color
	var s: float = get_safe_scale()
	var outer: float = 1.6
	var ex: Vector2 = half_extents
	# The band is four quads between the outer and the safe diamond.
	var o: Array[Vector2] = [Vector2(ex.x * outer, 0), Vector2(0, ex.y * outer), Vector2(-ex.x * outer, 0), Vector2(0, -ex.y * outer)]
	var i_: Array[Vector2] = [Vector2(ex.x * s, 0), Vector2(0, ex.y * s), Vector2(-ex.x * s, 0), Vector2(0, -ex.y * s)]
	var moving: bool = _active_time > spec.ring_delay_sec
	var alpha: float = 0.32 if moving else 0.12
	for k: int in 4:
		var n: int = (k + 1) % 4
		draw_colored_polygon(PackedVector2Array([o[k], o[n], i_[n], i_[k]]), Color(c.r, c.g, c.b, alpha))
	var edge := PackedVector2Array([i_[0], i_[1], i_[2], i_[3], i_[0]])
	draw_polyline(edge, Color(c.r, c.g, c.b, 0.9 if moving else 0.45), 3.0, true)
