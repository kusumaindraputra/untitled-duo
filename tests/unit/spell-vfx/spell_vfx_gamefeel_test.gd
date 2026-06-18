## spell_vfx_gamefeel_test.gd — Unit tests for SpellVFX game-feel mechanics.
##
## Coverage:
##   Hitstop: _start_hitstop() changes Engine.time_scale; _tick_hitstop() restores it.
##   Hitstop: rapid hits reset/extend the timer (no early-return guard).
##   Screen shake: _tick_shake() does not crash when _camera is null.
##   Enemy flash: request_hit_flash() sets overbright modulate instantly.
##   Enemy flash: request_hit_flash() kills any active _vfx_tween.
##
## GdUnit4 v6.1.3 | Godot 4.6
extends GdUnitTestSuite


var _saved_time_scale: float = 1.0


func before_test() -> void:
	_saved_time_scale = Engine.time_scale


func after_test() -> void:
	Engine.time_scale = _saved_time_scale


# ── Hitstop tests ────────────────────────────────────────────────────────────

## GIVEN a spell hits an enemy
## WHEN _start_hitstop() is called
## THEN Engine.time_scale drops to HITSTOP_TIME_SCALE (near-freeze)
func test_start_hitstop_sets_time_scale_near_zero() -> void:
	var vfx: Node = get_node_or_null("/root/SpellVFX")
	assert_object(vfx).is_not_null()

	vfx._start_hitstop()

	assert_float(Engine.time_scale).is_less_equal(0.1)
	# Cleanup intermediate state so after_test() restore is clean
	vfx._in_hitstop = false


## GIVEN hitstop is active and the timer has expired
## WHEN _tick_hitstop() is called
## THEN Engine.time_scale is restored to 1.0
func test_tick_hitstop_restores_time_scale_after_expiry() -> void:
	var vfx: Node = get_node_or_null("/root/SpellVFX")
	assert_object(vfx).is_not_null()

	vfx._in_hitstop = true
	Engine.time_scale = vfx.HITSTOP_TIME_SCALE
	vfx._hitstop_end_us = Time.get_ticks_usec() - 1  # already expired

	vfx._tick_hitstop()

	assert_float(Engine.time_scale).is_equal_approx(1.0, 0.001)


## GIVEN hitstop is already active with time remaining
## WHEN _start_hitstop() is called again (rapid hit)
## THEN the end timestamp is reset — rapid hits are not silently ignored
func test_start_hitstop_resets_timer_on_rapid_hits() -> void:
	var vfx: Node = get_node_or_null("/root/SpellVFX")
	assert_object(vfx).is_not_null()

	vfx._in_hitstop = true
	Engine.time_scale = vfx.HITSTOP_TIME_SCALE
	var first_end_us: int = Time.get_ticks_usec() + 10_000  # 10 ms remaining
	vfx._hitstop_end_us = first_end_us

	vfx._start_hitstop()

	assert_int(vfx._hitstop_end_us).is_greater(first_end_us)
	vfx._in_hitstop = false


## GIVEN HITSTOP_DURATION_US constant
## THEN it is at least 80 ms so hits are perceptible
func test_hitstop_duration_constant_is_at_least_80ms() -> void:
	var vfx: Node = get_node_or_null("/root/SpellVFX")
	assert_object(vfx).is_not_null()

	assert_int(vfx.HITSTOP_DURATION_US).is_greater_equal(80_000)


# ── Screen shake tests ────────────────────────────────────────────────────────

## GIVEN _camera is null (autoload startup race condition)
## WHEN _tick_shake() is called with an active shake timer
## THEN no crash occurs
func test_tick_shake_does_not_crash_when_camera_null() -> void:
	var vfx: Node = get_node_or_null("/root/SpellVFX")
	assert_object(vfx).is_not_null()

	var prev_camera: Camera2D = vfx._camera
	vfx._camera = null
	vfx._shake_end_us = Time.get_ticks_usec() + 100_000

	vfx._tick_shake()  # must not crash

	vfx._camera = prev_camera
	vfx._shake_end_us = 0
	assert_bool(true).is_true()


# ── Enemy hit flash tests ─────────────────────────────────────────────────────

## GIVEN an enemy with no active VFX tween
## WHEN request_hit_flash() is called
## THEN modulate is set to overbright white immediately
func test_enemy_request_hit_flash_sets_overbright_modulate() -> void:
	var enemy := EnemyInstance.new()
	add_child(enemy)
	auto_free(enemy)
	enemy.modulate = Color.WHITE

	enemy.request_hit_flash()

	assert_float(enemy.modulate.r).is_greater_equal(2.9)
	assert_float(enemy.modulate.g).is_greater_equal(2.9)
	assert_float(enemy.modulate.b).is_greater_equal(2.9)
	assert_float(enemy.modulate.a).is_equal_approx(1.0, 0.01)


## GIVEN an enemy with an active looping _vfx_tween (contact state)
## WHEN request_hit_flash() is called
## THEN _vfx_tween is killed and set to null so it cannot override the flash
func test_enemy_request_hit_flash_kills_active_vfx_tween() -> void:
	var enemy := EnemyInstance.new()
	add_child(enemy)
	auto_free(enemy)

	var looping_tween: Tween = enemy.create_tween().set_loops()
	looping_tween.tween_property(enemy, "modulate", Color(2.2, 0.3, 0.3), 0.12)
	enemy._vfx_tween = looping_tween

	enemy.request_hit_flash()

	assert_object(enemy._vfx_tween).is_null()
