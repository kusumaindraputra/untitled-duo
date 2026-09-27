## screen_shake_state_test.gd — ShakeState math and the ScreenShake autoload (ADR-0040).
##
## Coverage:
##   trauma adds, clamps, decays linearly in real time and scales by settings
##   directional kick points along the blow, clamps, and springs back to rest
##   step() offset is zero at rest and bounded by max offset + kick
##   presets are ordered LIGHT < MEDIUM < HEAVY < MASSIVE
##   Screen shake 0 and Reduce motion scale the autoload's shakes
##   the autoload writes the active camera's offset and zeroes it at rest
##
## Framework: GdUnit4 v6.1.3 | Godot 4.6
extends GdUnitTestSuite

const TUNING: ShakeTuning = preload("res://assets/data/shake_tuning.tres")

var _prev_settings: GameSettings = null


func before_test() -> void:
	_prev_settings = GameSettings.current
	GameSettings.current = null
	ScreenShake.reset()


func after_test() -> void:
	ScreenShake.reset()
	GameSettings.current = _prev_settings


# ── Trauma ────────────────────────────────────────────────────────────────────

func test_shake_state_add_trauma_accumulates_and_clamps() -> void:
	var s := ShakeState.new(TUNING)
	s.add_trauma(0.3)
	s.add_trauma(0.3)
	assert_float(s.trauma).is_equal_approx(0.6, 0.0001)
	s.add_trauma(0.9)
	assert_float(s.trauma).is_equal(1.0)


func test_shake_state_trauma_decays_by_tuning_rate() -> void:
	var s := ShakeState.new(TUNING)
	s.add_trauma(0.8)
	s.step(0.1)
	assert_float(s.trauma).is_equal_approx(0.8 - TUNING.trauma_decay * 0.1, 0.0001)
	s.step(10.0)
	assert_float(s.trauma).is_equal(0.0)


func test_shake_state_multiplier_scales_trauma() -> void:
	var s := ShakeState.new(TUNING)
	s.add_trauma(0.8, Vector2.ZERO, 0.5)
	assert_float(s.trauma).is_equal_approx(0.4, 0.0001)
	s.add_trauma(0.8, Vector2.RIGHT, 0.0)
	assert_float(s.trauma).is_equal_approx(0.4, 0.0001)
	assert_bool(s.kick == Vector2.ZERO).is_true()


# ── Kick ──────────────────────────────────────────────────────────────────────

func test_shake_state_kick_points_along_direction() -> void:
	var s := ShakeState.new(TUNING)
	s.add_trauma(0.5, Vector2(0.0, -3.0))
	assert_float(s.kick.x).is_equal_approx(0.0, 0.0001)
	assert_float(s.kick.y).is_equal_approx(-0.5 * TUNING.kick_per_trauma_px, 0.0001)


func test_shake_state_kick_clamps_to_max() -> void:
	var s := ShakeState.new(TUNING)
	for i: int in range(10):
		s.add_kick(Vector2.RIGHT, 5.0)
	assert_float(s.kick.length()).is_equal_approx(TUNING.kick_max_px, 0.0001)


func test_shake_state_kick_springs_back_to_rest() -> void:
	var s := ShakeState.new(TUNING)
	s.add_kick(Vector2.RIGHT, 6.0)
	var before: float = s.kick.length()
	s.step(0.05)
	assert_float(s.kick.length()).is_less(before)
	for i: int in range(60):
		s.step(1.0 / 60.0)
	assert_bool(s.kick == Vector2.ZERO).is_true()
	assert_bool(s.is_idle()).is_true()


# ── Offset ────────────────────────────────────────────────────────────────────

func test_shake_state_offset_zero_at_rest() -> void:
	var s := ShakeState.new(TUNING)
	assert_bool(s.step(0.016) == Vector2.ZERO).is_true()


func test_shake_state_offset_bounded_by_max_offset_and_kick() -> void:
	var s := ShakeState.new(TUNING)
	s.add_trauma(1.0, Vector2.DOWN)
	var bound: float = TUNING.max_offset_px * sqrt(2.0) + TUNING.kick_max_px
	for i: int in range(30):
		var off: Vector2 = s.step(1.0 / 60.0)
		assert_float(off.length()).is_less_equal(bound)


func test_shake_state_same_steps_give_same_offsets() -> void:
	var a := ShakeState.new(TUNING)
	var b := ShakeState.new(TUNING)
	a.add_trauma(0.7, Vector2.LEFT)
	b.add_trauma(0.7, Vector2.LEFT)
	for i: int in range(5):
		assert_bool(a.step(0.016).is_equal_approx(b.step(0.016))).is_true()


func test_shake_state_reset_clears_everything() -> void:
	var s := ShakeState.new(TUNING)
	s.add_trauma(0.9, Vector2.UP)
	s.step(0.016)
	s.reset()
	assert_bool(s.is_idle()).is_true()
	assert_bool(s.offset == Vector2.ZERO).is_true()


func test_shake_tuning_presets_are_ordered() -> void:
	var light: float = TUNING.preset(ShakeState.Strength.LIGHT)
	var medium: float = TUNING.preset(ShakeState.Strength.MEDIUM)
	var heavy: float = TUNING.preset(ShakeState.Strength.HEAVY)
	var massive: float = TUNING.preset(ShakeState.Strength.MASSIVE)
	assert_float(light).is_greater(0.0)
	assert_float(medium).is_greater(light)
	assert_float(heavy).is_greater(medium)
	assert_float(massive).is_greater(heavy)
	assert_float(massive).is_less_equal(1.0)


# ── Autoload + settings ───────────────────────────────────────────────────────

func test_screen_shake_impact_uses_preset() -> void:
	ScreenShake.impact(ShakeState.Strength.MEDIUM)
	assert_float(ScreenShake.get_trauma()).is_equal_approx(TUNING.medium, 0.0001)


func test_screen_shake_off_in_settings_adds_nothing() -> void:
	var s := GameSettings.new()
	s.screen_shake = 0.0
	GameSettings.current = s
	ScreenShake.impact(ShakeState.Strength.MASSIVE, Vector2.RIGHT)
	ScreenShake.kick(Vector2.RIGHT, 6.0)
	assert_float(ScreenShake.get_trauma()).is_equal(0.0)
	assert_bool(ScreenShake.state.kick == Vector2.ZERO).is_true()


func test_screen_shake_reduce_motion_scales_down() -> void:
	var s := GameSettings.new()
	s.reduce_motion = true
	GameSettings.current = s
	ScreenShake.add_trauma(0.6)
	assert_float(ScreenShake.get_trauma()).is_equal_approx(0.6 * TUNING.reduce_motion_scale, 0.0001)


func test_screen_shake_writes_camera_offset_then_rests_at_zero() -> void:
	var cam := Camera2D.new()
	add_child(cam)
	cam.make_current()
	ScreenShake.add_trauma(0.8, Vector2.RIGHT)
	ScreenShake.tick(0.016)
	assert_bool(cam.offset == Vector2.ZERO).is_false()
	for i: int in range(120):
		ScreenShake.tick(1.0 / 60.0)
	assert_bool(cam.offset == Vector2.ZERO).is_true()
	ScreenShake.reset()
	cam.free()
