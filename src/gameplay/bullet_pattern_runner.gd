## BulletPatternRunner — pure timing + geometry for one BulletPattern layer (ADR-0018).
##
## Owned by an EnemyInstance (one runner per pattern layer). tick() advances the
## firing cycle and returns the events the owner must act on this frame:
##   { "type": EVENT_WINDUP }                          — start the telegraph flash
##   { "type": EVENT_FIRE, "angles": PackedFloat32Array, "speed": float, "volley": int }
## No nodes, no scene tree: every rule here is covered by headless unit tests.
class_name BulletPatternRunner
extends RefCounted

const EVENT_WINDUP: StringName = &"windup"
const EVENT_FIRE: StringName = &"fire"

var pattern: BulletPattern = null

## Seconds until the next firing starts (windup included).
var _cooldown: float = 0.0
## True while volleys of the current firing are still pending.
var _firing: bool = false
var _volleys_left: int = 0
var _volley_timer: float = 0.0
var _volley_index: int = 0
## Angle locked at the start of a firing (FAN / RING / SPIRAL keep it for every volley).
var _locked_angle: float = 0.0
## Total volleys fired over this runner's life — drives SPIRAL rotation across firings.
var _total_volleys: int = 0
var _windup_sent: bool = false


func _init(p: BulletPattern) -> void:
	pattern = p
	_cooldown = maxf(p.initial_delay, 0.0) if p != null else 0.0


## True when this layer may fire at [param hp_ratio] (0..1 of owner max HP).
func is_active(hp_ratio: float) -> bool:
	return pattern != null and hp_ratio <= pattern.hp_threshold


## Advances the cycle by [param delta]. [param aim_angle] is the current angle toward
## Fayde in radians. Returns this frame's events (usually empty).
func tick(delta: float, aim_angle: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if pattern == null:
		return events
	if _firing:
		_volley_timer -= delta
		while _firing and _volley_timer <= 0.0:
			events.append(_emit_volley(aim_angle))
			_volley_timer += maxf(pattern.burst_interval, 0.0)
		return events
	_cooldown -= delta
	if not _windup_sent and pattern.windup_sec > 0.0 and _cooldown <= pattern.windup_sec:
		_windup_sent = true
		events.append({ "type": EVENT_WINDUP })
	if _cooldown <= 0.0:
		_firing = true
		_volleys_left = maxi(pattern.bursts, 1)
		_volley_index = 0
		_locked_angle = aim_angle
		_volley_timer = 0.0
		events.append(_emit_volley(aim_angle))
		_volley_timer += maxf(pattern.burst_interval, 0.0)
	return events


## Resets the cycle (preparation phase, stun). Keeps the SPIRAL rotation.
func reset() -> void:
	_firing = false
	_volleys_left = 0
	_volley_timer = 0.0
	_windup_sent = false
	_cooldown = maxf(pattern.initial_delay, 0.0) if pattern != null else 0.0


func _emit_volley(aim_angle: float) -> Dictionary:
	var base: float = aim_angle if pattern.shape == BulletPattern.Shape.AIMED else _locked_angle
	var angles: PackedFloat32Array = compute_angles(pattern, base, _total_volleys)
	var ev: Dictionary = {
		"type": EVENT_FIRE,
		"angles": angles,
		"speed": pattern.speed + pattern.speed_step * float(_volley_index),
		"volley": _volley_index,
	}
	_volley_index += 1
	_total_volleys += 1
	_volleys_left -= 1
	if _volleys_left <= 0:
		_firing = false
		_windup_sent = false
		_cooldown = maxf(pattern.interval, 0.05)
	return ev


## Returns the bullet angles (radians) of one volley of [param p].
## [param aim_angle] is the angle toward Fayde; [param volley_number] is how many
## volleys this layer fired before (spin_deg × volley_number rotates the volley).
static func compute_angles(p: BulletPattern, aim_angle: float, volley_number: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n: int = maxi(p.count, 1)
	var base: float = aim_angle if p.aim_at_player else 0.0
	base += deg_to_rad(p.spin_deg) * float(volley_number)
	match p.shape:
		BulletPattern.Shape.RING, BulletPattern.Shape.SPIRAL:
			var step: float = TAU / float(n)
			for i: int in n:
				out.append(wrapf(base + step * float(i), -PI, PI))
		_:  # AIMED, FAN — spread evenly across spread_deg, centred on base
			if n == 1 or is_zero_approx(p.spread_deg):
				for i: int in n:
					out.append(wrapf(base, -PI, PI))
			else:
				var spread: float = deg_to_rad(p.spread_deg)
				var start: float = base - spread * 0.5
				var fan_step: float = spread / float(n - 1)
				for i: int in n:
					out.append(wrapf(start + fan_step * float(i), -PI, PI))
	return out
