## Rumble — gamepad vibration for impacts and big moves (ADR-0031).
##
## Static helpers, no node. Impacts reuse camera trauma (PlayerController calls
## from_trauma), so every hit that shakes the screen also rumbles, scaled by the
## player's Rumble setting (not by Screen shake). Nothing plays unless the last input
## came from a gamepad. The pulse math (trauma_pulse / scaled) is pure for tests.
class_name Rumble
extends RefCounted

const TUNING: RumbleTuning = preload("res://assets/data/rumble_tuning.tres")


## Weak motor, strong motor and seconds for a camera-trauma [param amount], before the
## player setting. Returns Vector3.ZERO below TUNING.min_trauma.
static func trauma_pulse(amount: float, tuning: RumbleTuning = TUNING) -> Vector3:
	var t: float = clampf(amount, 0.0, 1.0)
	if t < tuning.min_trauma:
		return Vector3.ZERO
	return Vector3(tuning.trauma_weak * t, tuning.trauma_strong * t,
		lerpf(tuning.trauma_min_sec, tuning.trauma_max_sec, t))


## [param pulse] (weak, strong, seconds) with both motors scaled by [param mult].
static func scaled(pulse: Vector3, mult: float) -> Vector3:
	var m: float = clampf(mult, 0.0, 1.0)
	return Vector3(clampf(pulse.x * m, 0.0, 1.0), clampf(pulse.y * m, 0.0, 1.0), pulse.z)


## Rumbles for camera trauma [param amount].
static func from_trauma(amount: float) -> void:
	play(trauma_pulse(amount))


## Light buzz for a Perfect Dodge. Argument list matches perfect_dodge_triggered.
static func on_perfect_dodge(_world_pos: Vector2) -> void:
	play(Vector3(TUNING.perfect_dodge_weak, TUNING.perfect_dodge_strong, TUNING.perfect_dodge_sec))


## Thump for the Special. Argument list matches SpellCastingEffects.special_fired.
static func on_special_fired(_prana_type_id: int, _world_pos: Vector2, _radius: float) -> void:
	play(Vector3(TUNING.special_weak, TUNING.special_strong, TUNING.special_sec))


## Starts [param pulse] (weak, strong, seconds) on the last-used gamepad, scaled by
## the Rumble setting. No-op when the player is on keyboard/mouse or rumble is off.
static func play(pulse: Vector3) -> void:
	var p: Vector3 = scaled(pulse, GameSettings.rumble_multiplier())
	if p.z <= 0.0 or (p.x <= 0.0 and p.y <= 0.0):
		return
	var tree := Engine.get_main_loop() as SceneTree
	var prompts: Node = tree.root.get_node_or_null(^"InputPrompts") if tree != null else null
	if prompts == null or not bool(prompts.get(&"using_pad")):
		return
	Input.start_joy_vibration(int(prompts.get(&"pad_device")), p.x, p.y, p.z)
