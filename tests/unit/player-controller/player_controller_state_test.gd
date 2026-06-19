## player_controller_state_test.gd — Unit tests for PlayerController (Story PC-001).
##
## Coverage:
##   AC-PC-03:  DISABLED state zeroes velocity during _physics_process
##   AC-PC-04:  preparation_started signal disables controller (integration, scene tree)
##   AC-PC-10:  _on_preparation_started sets DISABLED and zeroes velocity
##   AC-PC-11:  _on_combat_started sets ENABLED (non-boss and boss variants)
##   AC-PC-12:  Mid-dash preparation_started clears state, velocity, and invincibility
##   AC-PC-13:  room_cleared does NOT change controller state (player walks to exit)
##   AC-PC-14:  room_cleared signal connection exists in scene tree (regression: bug fix)
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite)
extends GdUnitTestSuite

const PlayerControllerScript = preload("res://src/gameplay/player_controller.gd")

# ── Helpers ───────────────────────────────────────────────────────────────────

## Creates a new PlayerController instance. Not added to the scene tree unless
## the test requires _ready() to fire (e.g. signal connection tests).
func _make_pc() -> PlayerController:
	var pc := PlayerControllerScript.new() as PlayerController
	return pc

# ── AC-PC-03: DISABLED state zeroes velocity ──────────────────────────────────

func test_pc_disabled_state_physics_process_zeroes_velocity() -> void:
	# Arrange
	var pc: PlayerController = _make_pc()
	pc.velocity = Vector2(100.0, 0.0)

	# Act
	pc._physics_process(1.0 / 60.0)

	# Assert
	assert_vector(pc.velocity).is_equal(Vector2.ZERO)
	pc.free()


# ── AC-PC-04: preparation_started signal disables via scene tree (integration) ─

func test_pc_preparation_started_signal_disables_via_tree_integration() -> void:
	# Arrange — add to tree so _ready() fires and signals connect
	var pc: PlayerController = _make_pc()
	add_child(pc)
	pc._controller_state = PlayerController.ControllerState.ENABLED
	var initial_pos: Vector2 = pc.global_position

	# Act
	GameStateManager.preparation_started.emit(0, 0)

	# Assert
	assert_int(pc.get_controller_state()).is_equal(PlayerController.ControllerState.DISABLED)
	assert_vector(pc.global_position).is_equal(initial_pos)

	# Cleanup — use free() to prevent GdUnit4 orphan monitor crash (same fix as
	# scene_manager_test: monitor runs synchronously before queue_free processes).
	remove_child(pc)
	pc.free()


# ── AC-PC-10: _on_preparation_started disables and zeroes velocity ────────────

func test_pc_on_preparation_started_disables_and_zeroes_velocity() -> void:
	# Arrange
	var pc: PlayerController = _make_pc()
	pc._controller_state = PlayerController.ControllerState.ENABLED
	pc.velocity = Vector2(120.0, 0.0)

	# Act
	pc._on_preparation_started()

	# Assert
	assert_int(pc.get_controller_state()).is_equal(PlayerController.ControllerState.DISABLED)
	assert_vector(pc.velocity).is_equal(Vector2.ZERO)
	pc.free()


# ── AC-PC-11: _on_combat_started enables controller (non-boss) ────────────────

func test_pc_on_combat_started_non_boss_enables_controller() -> void:
	# Arrange
	var pc: PlayerController = _make_pc()
	pc._controller_state = PlayerController.ControllerState.DISABLED

	# Act
	pc._on_combat_started(false)

	# Assert
	assert_int(pc.get_controller_state()).is_equal(PlayerController.ControllerState.ENABLED)
	pc.free()


# ── AC-PC-11: _on_combat_started enables controller (boss) ───────────────────

func test_pc_on_combat_started_boss_enables_controller() -> void:
	# Arrange
	var pc: PlayerController = _make_pc()
	pc._controller_state = PlayerController.ControllerState.DISABLED

	# Act
	pc._on_combat_started(true)

	# Assert
	assert_int(pc.get_controller_state()).is_equal(PlayerController.ControllerState.ENABLED)
	pc.free()


# ── AC-PC-12: Mid-dash preparation_started clears all three states ────────────

func test_pc_mid_dash_preparation_started_clears_all_three_states() -> void:
	# Arrange
	var pc: PlayerController = _make_pc()
	pc._controller_state = PlayerController.ControllerState.DASHING
	pc._is_invincible = true
	pc.velocity = Vector2(400.0, 0.0)

	# Act
	pc._on_preparation_started()

	# Assert
	assert_int(pc.get_controller_state()).is_equal(PlayerController.ControllerState.DISABLED)
	assert_vector(pc.velocity).is_equal(Vector2.ZERO)
	assert_bool(pc.is_invincible()).is_false()
	pc.free()


# ── AC-PC-13: room_cleared keeps controller ENABLED (player walks to exit) ───

func test_pc_on_room_cleared_does_not_disable_controller() -> void:
	# Arrange
	var pc: PlayerController = _make_pc()
	pc._controller_state = PlayerController.ControllerState.ENABLED

	# Act — room_cleared fires after last wave; player must still move to the door
	pc._on_room_cleared()

	# Assert — state unchanged so player can walk to the exit
	assert_int(pc.get_controller_state()).is_equal(PlayerController.ControllerState.ENABLED)
	pc.free()


# ── AC-PC-14: room_cleared signal wired in scene tree (regression) ────────────

func test_pc_room_cleared_signal_connected_via_tree_integration() -> void:
	# Regression: room_cleared was never connected, so zooming out after the last
	# wave was missing — exit door appeared off-screen in the void below the floor.
	var pc: PlayerController = _make_pc()
	add_child(pc)

	assert_bool(GameStateManager.room_cleared.is_connected(pc._on_room_cleared)).is_true()

	remove_child(pc)
	pc.free()
