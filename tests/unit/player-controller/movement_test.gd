## movement_test.gd — Unit tests for PlayerController movement (Story PC-002).
##
## Coverage:
##   AC-PC-01:  ENABLED + rightward input → velocity.x > 0 and velocity.length() ≤ MOVE_SPEED
##   AC-PC-02:  Friction decelerates velocity to Vector2.ZERO within theoretical frame bound
##   AC-PC-19:  Rightward input → get_facing_direction() returns Vector2(1, 0) post-snap
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite)
##
## Input note: Input.action_press() is synthetic input and works in headless mode.
## AC-PC-01 and AC-PC-19 use Input.action_press() to drive _physics_process() with
## a non-zero input_dir, exercising the full code path (not a formula replay).
## AC-PC-02 calls _physics_process() in a loop — Input.get_vector() returns ZERO in
## headless (no action pressed), so the friction path runs naturally.
## add_child() is required for all tests that call _physics_process() so that
## move_and_slide() has a valid physics body RID.
##
## Actions note: movement actions may not be in InputMap in headless CI if project.godot
## has not been opened in the editor yet. before_test() registers any missing actions;
## after_test() removes only the ones it added, so project-defined actions are untouched.
extends GdUnitTestSuite

const PlayerControllerScript: GDScript = preload("res://src/gameplay/player_controller.gd")

const _MOVE_ACTIONS: Array[StringName] = [
	&"move_right", &"move_left", &"move_up", &"move_down"
]

# ── Lifecycle ─────────────────────────────────────────────────────────────────

## Shared instance — cleaned up in after_test() even when assertions fail.
var _pc: PlayerController = null
## Tracks actions we added so we only remove ones we own.
var _temp_actions: Array[StringName] = []


func before_test() -> void:
	_pc = PlayerControllerScript.new() as PlayerController
	_temp_actions.clear()
	for action: StringName in _MOVE_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			_temp_actions.append(action)


func after_test() -> void:
	for action: StringName in _MOVE_ACTIONS:
		if InputMap.has_action(action):
			Input.action_release(action)
	for action: StringName in _temp_actions:
		InputMap.erase_action(action)
	_temp_actions.clear()
	if is_instance_valid(_pc):
		if _pc.is_inside_tree():
			remove_child(_pc)
		_pc.free()
	_pc = null

# ── AC-PC-01: Movement acceleration formula ──────────────────────────────────

func test_pc_movement_one_frame_rightward_gives_positive_x_velocity() -> void:
	add_child(_pc)
	_pc._controller_state = PlayerController.ControllerState.ENABLED
	Input.action_press(&"move_right")
	_pc._physics_process(1.0 / 60.0)
	Input.action_release(&"move_right")
	assert_float(_pc.velocity.x).is_greater(0.0)
	assert_float(_pc.velocity.length()).is_less_equal(PlayerController.MOVE_SPEED)


func test_pc_movement_diagonal_input_normalized_velocity_within_speed() -> void:
	# Edge case: diagonal input is normalized before the lerp — velocity.length() must not exceed MOVE_SPEED.
	add_child(_pc)
	_pc._controller_state = PlayerController.ControllerState.ENABLED
	Input.action_press(&"move_right")
	Input.action_press(&"move_down")
	_pc._physics_process(1.0 / 60.0)
	Input.action_release(&"move_right")
	Input.action_release(&"move_down")
	assert_float(_pc.velocity.length()).is_less_equal(PlayerController.MOVE_SPEED + 0.001)

# ── AC-PC-02: Friction decelerates to Vector2.ZERO within frame bound ─────────

func test_pc_friction_decelerates_to_zero_within_frame_bound() -> void:
	# Input.get_vector() returns ZERO in headless → friction path runs every tick.
	add_child(_pc)
	_pc._controller_state = PlayerController.ControllerState.ENABLED
	_pc.velocity = Vector2(PlayerController.MOVE_SPEED, 0.0)

	# Theoretical upper bound from AC-PC-02 (defaults: ceil(log(8/120)/log(0.75)) = 10).
	var max_frames: int = ceili(
		log(PlayerController.VELOCITY_SNAP_THRESHOLD / PlayerController.MOVE_SPEED)
		/ log(1.0 - PlayerController.MOVE_FRICTION))

	var frames: int = 0
	while _pc.velocity != Vector2.ZERO and frames <= max_frames:
		_pc._physics_process(1.0 / 60.0)
		frames += 1

	assert_vector(_pc.velocity).is_equal(Vector2.ZERO)
	assert_int(frames).is_less_equal(max_frames)


func test_pc_friction_snaps_to_exactly_zero_not_near_zero() -> void:
	# Verifies the snap guard fires: without it, lerp approaches but never reaches ZERO.
	add_child(_pc)
	_pc._controller_state = PlayerController.ControllerState.ENABLED
	_pc.velocity = Vector2(PlayerController.VELOCITY_SNAP_THRESHOLD * 0.5, 0.0)

	_pc._physics_process(1.0 / 60.0)

	assert_vector(_pc.velocity).is_equal(Vector2.ZERO)

# ── AC-PC-19: Facing direction stored post-snap ───────────────────────────────

func test_pc_facing_direction_defaults_to_right() -> void:
	assert_vector(_pc.get_facing_direction()).is_equal(Vector2.RIGHT)


func test_pc_snap_to_8dir_pure_right_returns_right() -> void:
	var result: Vector2 = _pc._snap_to_8dir(Vector2(1.0, 0.0))
	assert_vector(result).is_equal(Vector2(1.0, 0.0))


func test_pc_snap_to_8dir_diagonal_snaps_to_45_degrees() -> void:
	var result: Vector2 = _pc._snap_to_8dir(Vector2(1.0, 1.0))
	assert_float(result.x).is_equal_approx(cos(PI / 4.0), 0.0001)
	assert_float(result.y).is_equal_approx(sin(PI / 4.0), 0.0001)


func test_pc_facing_direction_updated_on_rightward_physics_process() -> void:
	add_child(_pc)
	_pc._controller_state = PlayerController.ControllerState.ENABLED
	Input.action_press(&"move_right")
	_pc._physics_process(1.0 / 60.0)
	Input.action_release(&"move_right")
	assert_vector(_pc.get_facing_direction()).is_equal(Vector2(1.0, 0.0))


func test_pc_get_cast_position_equals_global_position() -> void:
	# Story 001 coverage — cast position API.
	add_child(_pc)
	assert_vector(_pc.get_cast_position()).is_equal(_pc.global_position)
