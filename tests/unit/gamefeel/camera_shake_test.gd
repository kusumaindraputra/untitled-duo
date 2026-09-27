## camera_shake_test.gd — PlayerController.add_camera_trauma forwards to ScreenShake.
##
## Since ADR-0040 the player no longer owns a shake: add_camera_trauma() adds to the
## shared ScreenShake autoload (and rumbles). The shake math itself is covered in
## tests/unit/screen-shake/.
##
## Framework: GdUnit4 v6.1.3 | Godot 4.6
extends GdUnitTestSuite

var _prev_settings: GameSettings = null


func before_test() -> void:
	_prev_settings = GameSettings.current
	GameSettings.current = null
	ScreenShake.reset()


func after_test() -> void:
	ScreenShake.reset()
	GameSettings.current = _prev_settings


## GIVEN a fresh PlayerController (not in tree)
## WHEN add_camera_trauma(0.4) is called
## THEN the shared ScreenShake holds 0.4 trauma
func test_add_camera_trauma_feeds_screen_shake() -> void:
	var player := PlayerController.new()

	player.add_camera_trauma(0.4)

	assert_float(ScreenShake.get_trauma()).is_equal_approx(0.4, 0.001)
	player.free()


## GIVEN two calls of 0.7 and 0.6
## THEN the shared trauma clamps at 1.0
func test_add_camera_trauma_clamps_at_one() -> void:
	var player := PlayerController.new()

	player.add_camera_trauma(0.7)
	player.add_camera_trauma(0.6)

	assert_float(ScreenShake.get_trauma()).is_equal_approx(1.0, 0.001)
	player.free()


## GIVEN a direction
## WHEN add_camera_trauma is called with it
## THEN the view kicks along that direction
func test_add_camera_trauma_with_direction_kicks_view() -> void:
	var player := PlayerController.new()

	player.add_camera_trauma(0.5, Vector2.LEFT)

	assert_float(ScreenShake.state.kick.x).is_less(0.0)
	assert_float(ScreenShake.state.kick.y).is_equal_approx(0.0, 0.001)
	player.free()

