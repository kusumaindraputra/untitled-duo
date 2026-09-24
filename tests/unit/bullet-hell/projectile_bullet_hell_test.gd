## projectile_bullet_hell_test.gd — Pattern bullets, graze, dash pass-through, cancel (ADR-0018).
##
## Coverage:
##   launch_pattern copies speed / range / radius from the BulletPattern
##   SINE motion drifts sideways; HOMING turns toward the player
##   Hurtbox: bullet hitting a dashing player passes through and grazes
##   Graze: close pass adds Special meter once per bullet
##   cancel_in_radius: clears inside radius only; radius < 0 clears all
##
## The fake player is a Node2D in group "player" with is_invincible() — never a real
## PlayerController, so HealthAndDamage's Fayde HP is not touched.
extends GdUnitTestSuite

const DT: float = 1.0 / 60.0
const TUNING: BulletHellTuning = preload("res://assets/data/bullet_hell_tuning.tres")


class _FakePlayer extends Node2D:
	var invincible: bool = false

	func is_invincible() -> bool:
		return invincible


var _nodes: Array[Node] = []
var _meter_before: float = 0.0


func before_test() -> void:
	_meter_before = SpellCastingEffects._special_meter
	SpellCastingEffects._special_meter = 0.0


func after_test() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			n.free()
	_nodes.clear()
	# Impact bursts spawned under the suite during grazes / cancels.
	for child: Node in get_children():
		if child is Node2D:
			remove_child(child)
			child.free()
	SpellCastingEffects._special_meter = _meter_before


func _player(at: Vector2) -> _FakePlayer:
	var p := _FakePlayer.new()
	p.add_to_group(&"player")
	add_child(p)
	p.global_position = at
	_nodes.append(p)
	return p


func _bullet(at: Vector2) -> Projectile:
	var b := Projectile.new()
	add_child(b)
	b.global_position = at
	_nodes.append(b)
	return b


func _pattern() -> BulletPattern:
	var p := BulletPattern.new()
	p.speed = 100.0
	p.max_range = 300.0
	p.bullet_radius = 5.0
	return p


func test_launch_pattern_copies_bullet_params() -> void:
	var b := _bullet(Vector2.ZERO)
	b.launch_pattern(Vector2.RIGHT, 3.0, _pattern(), 150.0)
	assert_float(b._speed).is_equal(150.0)
	assert_float(b._max_range).is_equal(300.0)
	assert_float(b._radius).is_equal(5.0)


func test_sine_motion_moves_off_the_centre_line() -> void:
	var p := _pattern()
	p.motion = BulletPattern.Motion.SINE
	p.sine_amplitude = 20.0
	p.sine_frequency = 1.0
	var b := _bullet(Vector2.ZERO)
	b.launch_pattern(Vector2.RIGHT, 1.0, p, 100.0)
	for _i: int in 15:  # 0.25 s → sin(90°) → full amplitude
		b._physics_process(DT)
	assert_float(absf(b.position.y)).is_greater(15.0)


func test_homing_turns_toward_player() -> void:
	_player(Vector2(0.0, 200.0))
	var p := _pattern()
	p.motion = BulletPattern.Motion.HOMING
	p.homing_turn_deg = 180.0
	p.homing_duration = 2.0
	var b := _bullet(Vector2.ZERO)
	b.launch_pattern(Vector2.RIGHT, 1.0, p, 100.0)
	for _i: int in 20:
		b._physics_process(DT)
	assert_float(b._direction.y).is_greater(0.3)


func test_bullet_passes_through_dashing_player_and_grazes() -> void:
	var fake := _player(Vector2(10.0, 0.0))
	fake.invincible = true
	var b := _bullet(Vector2.ZERO)
	b.launch_pattern(Vector2.RIGHT, 1.0, _pattern(), 600.0)  # reaches the player in 1 frame
	b._physics_process(DT)
	assert_bool(b.is_live()).is_true()
	assert_float(SpellCastingEffects.get_special_meter()).is_equal_approx(
		TUNING.graze_meter_gain * TUNING.dash_graze_mult, 0.001)


func test_graze_adds_meter_once_per_bullet() -> void:
	# Player sits 15 px off the line: outside hurtbox (5 + 3), inside graze (5 + 20).
	_player(Vector2(30.0, 15.0))
	var b := _bullet(Vector2.ZERO)
	b.launch_pattern(Vector2.RIGHT, 1.0, _pattern(), 100.0)
	for _i: int in 30:
		b._physics_process(DT)
	assert_bool(b.is_live()).is_true()
	assert_float(SpellCastingEffects.get_special_meter()).is_equal_approx(TUNING.graze_meter_gain, 0.001)


func test_far_bullet_does_not_graze() -> void:
	_player(Vector2(30.0, 80.0))
	var b := _bullet(Vector2.ZERO)
	b.launch_pattern(Vector2.RIGHT, 1.0, _pattern(), 100.0)
	for _i: int in 30:
		b._physics_process(DT)
	assert_float(SpellCastingEffects.get_special_meter()).is_equal(0.0)


func test_cancel_in_radius_clears_only_nearby_bullets() -> void:
	var near := _bullet(Vector2(10.0, 0.0))
	near.launch(Vector2.RIGHT, 1.0)
	var far := _bullet(Vector2(500.0, 0.0))
	far.launch(Vector2.RIGHT, 1.0)
	var n: int = Projectile.cancel_in_radius(get_tree(), Vector2.ZERO, 50.0)
	assert_int(n).is_equal(1)
	assert_bool(near.is_live()).is_false()
	assert_bool(far.is_live()).is_true()


func test_cancel_in_radius_negative_clears_all() -> void:
	var a := _bullet(Vector2(10.0, 0.0))
	a.launch(Vector2.RIGHT, 1.0)
	var b := _bullet(Vector2(900.0, 0.0))
	b.launch(Vector2.RIGHT, 1.0)
	var n: int = Projectile.cancel_in_radius(get_tree(), Vector2.ZERO, -1.0)
	assert_int(n).is_equal(2)
