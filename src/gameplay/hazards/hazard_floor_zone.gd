## hazard_floor_zone.gd — Floor vent that cycles dormant → warning → burning (ADR-0020).
##
## One cycle is off_sec + telegraph_sec + on_sec. While burning, Fayde takes
## spec.damage if she stands inside the iso circle (dash i-frames still apply).
## phase_offset lets several vents in one room take turns.
class_name HazardFloorZone
extends StageHazard

enum Phase { DORMANT = 0, TELEGRAPH = 1, BURNING = 2 }


## Pure: vent phase [param t] seconds into the hazard's life for [param s].
static func phase_at(t: float, s: HazardSpec) -> Phase:
	var cycle: float = maxf(s.off_sec + s.telegraph_sec + s.on_sec, 0.01)
	var local: float = fposmod(t + s.phase_offset, cycle)
	if local < s.off_sec:
		return Phase.DORMANT
	if local < s.off_sec + s.telegraph_sec:
		return Phase.TELEGRAPH
	return Phase.BURNING


## Current phase (DORMANT while the hazard is off).
func get_phase() -> Phase:
	if not _active or spec == null:
		return Phase.DORMANT
	return phase_at(_active_time, spec)


## Phase seen on the previous tick, so the ignite cue plays once per burn.
var _last_phase: Phase = Phase.DORMANT


func _hazard_tick(_delta: float) -> void:
	var phase: Phase = get_phase()
	if phase == Phase.BURNING and _last_phase != Phase.BURNING:
		Sfx.play(&"sfx_vent_ignite")
	_last_phase = phase
	if phase != Phase.BURNING or not is_instance_valid(_player):
		return
	if in_iso_radius(_player.global_position - global_position, spec.zone_radius):
		_hit_player(false)


func _ready() -> void:
	super._ready()
	z_index = 3  # on the floor, under debris and entities


func _draw() -> void:
	if spec == null:
		return
	var r: float = spec.zone_radius
	var c: Color = spec.color
	var ring: PackedVector2Array = CoverPillar._ellipse(Vector2.ZERO, r, r * 0.5)
	# Grate: always visible so the player can plan around it in preparation.
	draw_colored_polygon(ring, Color(0.1, 0.08, 0.1, 0.55))
	ring.append(ring[0])
	draw_polyline(ring, Color(c.r, c.g, c.b, 0.35), 1.5, true)
	for k: int in 3:
		var y: float = (float(k) - 1.0) * r * 0.22
		draw_line(Vector2(-r * 0.6, y), Vector2(r * 0.6, y), Color(0.3, 0.28, 0.3, 0.7), 1.5)
	match get_phase():
		Phase.TELEGRAPH:
			var cycle: float = spec.off_sec + spec.telegraph_sec + spec.on_sec
			var local: float = fposmod(_active_time + spec.phase_offset, maxf(cycle, 0.01)) - spec.off_sec
			var p: float = clampf(local / maxf(spec.telegraph_sec, 0.01), 0.0, 1.0)
			draw_colored_polygon(CoverPillar._ellipse(Vector2.ZERO, r * p, r * p * 0.5), Color(c.r, c.g, c.b, 0.25))
			draw_polyline(ring, Color(c.r, c.g, c.b, 0.6 + 0.4 * p), 2.5, true)
		Phase.BURNING:
			draw_colored_polygon(CoverPillar._ellipse(Vector2.ZERO, r, r * 0.5), Color(c.r, c.g, c.b, 0.55))
			draw_colored_polygon(CoverPillar._ellipse(Vector2(0, -2), r * 0.6, r * 0.3), Color(1.0, 0.9, 0.6, 0.5))
			draw_polyline(ring, Color(1, 1, 1, 0.8), 2.5, true)
