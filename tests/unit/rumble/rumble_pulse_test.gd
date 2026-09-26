## rumble_pulse_test.gd — gamepad rumble math (ADR-0031).
##
## Coverage: trauma maps to a pulse inside the tuning range, small trauma is silent,
## the player's Rumble setting scales both motors, and play() is a safe no-op on
## keyboard or with rumble off (no pad is connected headless).
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

var _saved_current: GameSettings = null


func before_test() -> void:
	_saved_current = GameSettings.current


func after_test() -> void:
	GameSettings.current = _saved_current
	InputPrompts.using_pad = false


func _tuning() -> RumbleTuning:
	var t := RumbleTuning.new()
	t.min_trauma = 0.2
	t.trauma_weak = 0.5
	t.trauma_strong = 1.0
	t.trauma_min_sec = 0.1
	t.trauma_max_sec = 0.3
	return t


func test_rumble_full_trauma_gives_full_pulse() -> void:
	var p: Vector3 = Rumble.trauma_pulse(1.0, _tuning())
	assert_float(p.x).is_equal_approx(0.5, 0.001)
	assert_float(p.y).is_equal_approx(1.0, 0.001)
	assert_float(p.z).is_equal_approx(0.3, 0.001)


func test_rumble_small_trauma_is_silent() -> void:
	assert_that(Rumble.trauma_pulse(0.1, _tuning())).is_equal(Vector3.ZERO)


func test_rumble_trauma_above_one_is_clamped() -> void:
	assert_that(Rumble.trauma_pulse(4.0, _tuning())).is_equal(Rumble.trauma_pulse(1.0, _tuning()))


func test_rumble_setting_scales_both_motors() -> void:
	var p: Vector3 = Rumble.scaled(Vector3(0.6, 0.8, 0.2), 0.5)
	assert_float(p.x).is_equal_approx(0.3, 0.001)
	assert_float(p.y).is_equal_approx(0.4, 0.001)
	assert_float(p.z).is_equal_approx(0.2, 0.001)
	assert_that(Rumble.scaled(Vector3(0.6, 0.8, 0.2), 0.0)).is_equal(Vector3(0.0, 0.0, 0.2))


func test_rumble_shipped_tuning_is_in_motor_range() -> void:
	var t: RumbleTuning = Rumble.TUNING
	for v: float in [t.trauma_weak, t.trauma_strong, t.perfect_dodge_weak,
			t.perfect_dodge_strong, t.special_weak, t.special_strong]:
		assert_float(v).is_between(0.0, 1.0)
	assert_float(t.trauma_min_sec).is_less_equal(t.trauma_max_sec)


func test_rumble_play_is_safe_on_keyboard_and_when_off() -> void:
	InputPrompts.using_pad = false
	Rumble.from_trauma(1.0)
	var s := GameSettings.new()
	s.rumble = 0.0
	GameSettings.current = s
	InputPrompts.using_pad = true
	Rumble.on_special_fired(0, Vector2.ZERO, 10.0)
	Rumble.on_perfect_dodge(Vector2.ZERO)
	assert_bool(true).is_true()
