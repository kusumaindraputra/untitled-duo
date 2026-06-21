## camera_shake_test.gd — Unit tests for PlayerController trauma-based camera shake.
##
## Coverage:
##   add_camera_trauma accumulates _trauma correctly
##   add_camera_trauma clamps _trauma at 1.0
##   _physics_process decays _trauma each frame
##
## Framework: GdUnit4 v6.1.3 | Godot 4.6
extends GdUnitTestSuite


# ── AC-SHAKE-01: trauma accumulates ──────────────────────────────────────────

## GIVEN a fresh PlayerController (not in tree — no Autoload signal connections)
## WHEN add_camera_trauma(0.4) is called
## THEN _trauma equals 0.4
func test_add_camera_trauma_sets_trauma() -> void:
	var player := PlayerController.new()

	player.add_camera_trauma(0.4)

	assert_float(player._trauma).is_equal_approx(0.4, 0.001)
	player.free()


# ── AC-SHAKE-02: trauma clamps at 1.0 ────────────────────────────────────────

## GIVEN _trauma = 0.7
## WHEN add_camera_trauma(0.6) is called (would total 1.3)
## THEN _trauma is clamped at 1.0
func test_add_camera_trauma_clamps_at_one() -> void:
	var player := PlayerController.new()
	player._trauma = 0.7

	player.add_camera_trauma(0.6)

	assert_float(player._trauma).is_equal_approx(1.0, 0.001)
	player.free()


# ── AC-SHAKE-03: trauma addition is cumulative ────────────────────────────────

## GIVEN _trauma starts at 0.0
## WHEN add_camera_trauma(0.2) is called twice
## THEN _trauma equals 0.4
func test_add_camera_trauma_accumulates_across_calls() -> void:
	var player := PlayerController.new()

	player.add_camera_trauma(0.2)
	player.add_camera_trauma(0.2)

	assert_float(player._trauma).is_equal_approx(0.4, 0.001)
	player.free()


# ── AC-SHAKE-04: trauma decays each physics frame ─────────────────────────────

## GIVEN PlayerController in the scene tree, _trauma = 0.8, controller DISABLED
## WHEN _physics_process(0.1) is called
## THEN _trauma has decreased by TRAUMA_DECAY * delta (= 3.5 * 0.1 = 0.35)
func test_physics_process_decays_trauma() -> void:
	var player := PlayerController.new()
	add_child(player)
	auto_free(player)
	player._trauma = 0.8
	# DISABLED state exits early after the camera-shake block — no move_and_slide called.
	player._controller_state = PlayerController.ControllerState.DISABLED

	player._physics_process(0.1)

	var expected: float = maxf(0.8 - PlayerController.TRAUMA_DECAY * 0.1, 0.0)
	assert_float(player._trauma).is_equal_approx(expected, 0.001)
