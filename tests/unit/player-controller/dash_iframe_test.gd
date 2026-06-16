## dash_iframe_test.gd — Unit tests for S8-02: dash pass-through + blinking.
##
## Coverage:
##   test_01: is_invincible() true while _is_invincible flag set and DASHING
##   test_02: is_invincible() false after DASH_DURATION expires
##   test_03: collision_mask == COLLISION_MASK_DASHING while DASHING
##   test_04: collision_mask == COLLISION_MASK_NORMAL after dash expires
##   test_05: modulate.a toggles to dim after one BLINK_INTERVAL while invincible
##   test_06: modulate.a restored to 1.0 when not invincible
##   test_07: _on_preparation_started() restores collision_mask and modulate.a mid-dash
##   test_08: COLLISION_MASK_DASHING != COLLISION_MASK_NORMAL (constant sanity)
##
## Framework: GdUnit4 (extends GdUnitTestSuite)
## add_child() required for tests driving _physics_process() with DASHING state
## (move_and_slide() needs a valid physics RID). Teardown: remove_child() + free().
## Tests not reaching move_and_slide() also use add_child() via shared lifecycle.
extends GdUnitTestSuite

const PlayerControllerScript: GDScript = preload("res://src/gameplay/player_controller.gd")

const _ALL_ACTIONS: Array[StringName] = [
	&"move_right", &"move_left", &"move_up", &"move_down", &"dash"
]

var _pc: PlayerController = null
var _temp_actions: Array[StringName] = []


func before_test() -> void:
	_pc = PlayerControllerScript.new() as PlayerController
	_temp_actions.clear()
	for action: StringName in _ALL_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			_temp_actions.append(action)
	add_child(_pc)


func after_test() -> void:
	for action: StringName in _ALL_ACTIONS:
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


# ── test_01: is_invincible true while DASHING ────────────────────────────────

func test_iframe_is_invincible_true_while_dashing() -> void:
	# Arrange
	_pc._is_invincible = true
	_pc._controller_state = PlayerController.ControllerState.DASHING
	_pc._dash_duration_timer = PlayerController.DASH_DURATION

	# Act
	_pc._physics_process(0.01)

	# Assert
	assert_bool(_pc.is_invincible()).is_true()


# ── test_02: is_invincible false after DASH_DURATION ─────────────────────────

func test_iframe_is_invincible_false_after_dash_expires() -> void:
	# Arrange
	_pc._is_invincible = true
	_pc._controller_state = PlayerController.ControllerState.DASHING
	_pc._dash_duration_timer = PlayerController.DASH_DURATION

	# Act — drive past DASH_DURATION in one step
	_pc._physics_process(PlayerController.DASH_DURATION + 0.01)

	# Assert
	assert_bool(_pc.is_invincible()).is_false()


# ── test_03: collision_mask is DASHING value while invincible/DASHING ────────

func test_iframe_collision_mask_is_dashing_while_dashing() -> void:
	# Arrange — simulate mid-dash state (collision_mask already set to DASHING)
	_pc._is_invincible = true
	_pc._controller_state = PlayerController.ControllerState.DASHING
	_pc._dash_duration_timer = PlayerController.DASH_DURATION
	_pc.collision_mask = PlayerController.COLLISION_MASK_DASHING

	# Act
	_pc._physics_process(0.01)

	# Assert — mask must still be DASHING (not restored yet)
	assert_int(_pc.collision_mask).is_equal(PlayerController.COLLISION_MASK_DASHING)


# ── test_04: collision_mask restored to NORMAL after dash expires ─────────────

func test_iframe_collision_mask_restored_after_dash_expires() -> void:
	# Arrange
	_pc._is_invincible = true
	_pc._controller_state = PlayerController.ControllerState.DASHING
	_pc._dash_duration_timer = PlayerController.DASH_DURATION
	_pc.collision_mask = PlayerController.COLLISION_MASK_DASHING

	# Act — drive past DASH_DURATION
	_pc._physics_process(PlayerController.DASH_DURATION + 0.01)

	# Assert
	assert_int(_pc.collision_mask).is_equal(PlayerController.COLLISION_MASK_NORMAL)


# ── test_05: modulate.a toggles to dim after one BLINK_INTERVAL ──────────────

func test_iframe_blink_dims_modulate_after_one_interval() -> void:
	# Arrange — invincible but DISABLED so move_and_slide not reached
	_pc._is_invincible = true
	_pc._controller_state = PlayerController.ControllerState.DISABLED
	_pc.modulate.a = 1.0
	_pc._blink_timer = 0.0

	# Act — drive just past one blink interval
	_pc._physics_process(PlayerController.BLINK_INTERVAL + 0.001)

	# Assert — alpha should have toggled to dim value
	assert_float(_pc.modulate.a).is_less(0.5)


# ── test_06: modulate.a restored to 1.0 when not invincible ──────────────────

func test_iframe_blink_restores_modulate_when_not_invincible() -> void:
	# Arrange — not invincible, alpha currently dimmed
	_pc._is_invincible = false
	_pc._controller_state = PlayerController.ControllerState.DISABLED
	_pc.modulate.a = 0.25

	# Act
	_pc._physics_process(0.01)

	# Assert
	assert_float(_pc.modulate.a).is_equal(1.0)


# ── test_07: preparation_started restores mask and modulate mid-dash ──────────

func test_iframe_preparation_started_restores_mask_and_modulate() -> void:
	# Arrange — simulate mid-dash state
	_pc._is_invincible = true
	_pc.collision_mask = PlayerController.COLLISION_MASK_DASHING
	_pc.modulate.a = 0.25

	# Act
	_pc._on_preparation_started()

	# Assert
	assert_bool(_pc._is_invincible).is_false()
	assert_int(_pc.collision_mask).is_equal(PlayerController.COLLISION_MASK_NORMAL)
	assert_float(_pc.modulate.a).is_equal(1.0)


# ── test_08: constant sanity — DASHING mask != NORMAL mask ───────────────────

func test_iframe_collision_mask_constants_differ() -> void:
	assert_int(PlayerController.COLLISION_MASK_DASHING).is_not_equal(
		PlayerController.COLLISION_MASK_NORMAL)
