## TutorialTurret — the shot pylon of the guided first room (ADR-0055).
##
## While [member active], it glows for TutorialRoomTuning.shot_telegraph_sec and then
## fires one slow, harmless (0 damage) enemy bullet at Fayde, every shot_interval_sec.
## The bullet is a normal Projectile, so dashing through it counts as a Perfect Dodge
## exactly as in a real fight. Not an enemy: spells pass it and it cannot be hurt.
class_name TutorialTurret
extends Node2D

const TUNING: TutorialRoomTuning = preload("res://assets/data/tutorial_room_tuning.tres")

## Pylon half-height and half-width in px.
const _HALF_H: float = 16.0
const _HALF_W: float = 9.0

## Shots fire only while true. TutorialRoom turns it on for the Perfect Dodge lesson.
var active: bool = false
## Fayde; shots aim at her position at the moment they fire.
var player: Node2D = null
## Shots fired so far (TutorialRoom falls back after TUNING.dodge_fallback_shots).
var shots_fired: int = 0

var _timer: float = 0.0
var _pattern: BulletPattern = null


func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	z_index = 1000
	_pattern = BulletPattern.new()
	_pattern.bullet_radius = TUNING.shot_radius
	_pattern.speed = TUNING.shot_speed
	_pattern.max_range = TUNING.turret_distance * 2.5
	_pattern.motion = BulletPattern.Motion.STRAIGHT


func _process(delta: float) -> void:
	if not active:
		_timer = 0.0
		queue_redraw()
		return
	_timer += delta
	if _timer >= TUNING.shot_interval_sec:
		_timer = 0.0
		fire()
	queue_redraw()


## 0..1 glow of the telegraph before the next shot; 0 while idle.
func charge() -> float:
	if not active:
		return 0.0
	var start: float = TUNING.shot_interval_sec - TUNING.shot_telegraph_sec
	return clampf((_timer - start) / maxf(TUNING.shot_telegraph_sec, 0.01), 0.0, 1.0)


## Fires one harmless bullet at Fayde. Returns the bullet, or null without a target.
func fire() -> Projectile:
	if not is_instance_valid(player) or get_parent() == null:
		return null
	var shot := Projectile.new()
	get_parent().add_child(shot)
	shot.global_position = global_position + Vector2(0.0, -_HALF_H)
	var dir: Vector2 = (player.global_position - shot.global_position).normalized()
	shot.launch_pattern(dir, 0.0, _pattern, TUNING.shot_speed)
	shots_fired += 1
	return shot


func _draw() -> void:
	var c: float = charge()
	var body := PackedVector2Array([
		Vector2(0.0, -_HALF_H * 2.0), Vector2(_HALF_W, -_HALF_H),
		Vector2(0.0, 0.0), Vector2(-_HALF_W, -_HALF_H),
	])
	draw_circle(Vector2.ZERO, 12.0, Color(0.0, 0.0, 0.0, 0.3))
	draw_colored_polygon(body, UIPalette.VOID)
	# Warms from the UI accent to the hostile bullet rim (ADR-0037) as the shot charges.
	var rim: Color = UIPalette.ACCENT.lerp(Projectile.PALETTE.rim, c)
	draw_polyline(body + PackedVector2Array([body[0]]), rim, 2.0)
	if c > 0.0:
		draw_circle(Vector2(0.0, -_HALF_H), 4.0 + 10.0 * c, Color(rim, 0.25 + 0.5 * c))
	draw_circle(Vector2(0.0, -_HALF_H), 2.5, rim)
