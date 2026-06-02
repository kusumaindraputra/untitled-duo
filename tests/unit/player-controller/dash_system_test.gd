## dash_system_test.gd — Unit tests for PlayerController dash system (Story PC-003).
##
## Coverage:
##   AC-PC-05:  ENABLED + cooldown expired + dash pressed → DASHING, is_invincible, velocity ≈ DASH_SPEED
##   AC-PC-06:  DASHING for DASH_DURATION frames → ENABLED, not invincible, cooldown > 0
##   AC-PC-07:  Dash blocked when cooldown active → state unchanged, velocity unchanged
##   AC-PC-08:  No movement input → dash uses _last_facing_dir (default Vector2.RIGHT)
##   AC-PC-13:  _compute_dash_distance() returns DASH_SPEED * DASH_DURATION (≈ 60.0 ± 1 px)
##   AC-PC-18:  get_dash_cooldown_remaining() returns correct value after 0.6s elapsed
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite)
##
## Input note: Input.action_press() / Input.is_action_just_pressed() work in headless mode
## when the action exists in InputMap. before_test() registers missing actions; after_test()
## removes only the ones it added. add_child() is required for tests that call _physics_process()
## so that move_and_slide() has a valid physics body RID.
##
## Timing note: AC-PC-06 drives the accumulator via _physics_process(1.0/60.0) calls.
##   ceil(DASH_DURATION * 60) = ceil(0.15 * 60) = 9 frames to exhaust the timer.
##   We run 10 frames (one extra) to guarantee the expiry branch executes.
## AC-PC-18 simulates 0.6s via 36 frames at 60fps on the cooldown timer directly,
##   then reads get_dash_cooldown_remaining() and checks within ±0.05s of 1.4s.
extends GdUnitTestSuite

const PlayerControllerScript: GDScript = preload("res://src/gameplay/player_controller.gd")

const _ALL_ACTIONS: Array[StringName] = [
	&"move_right", &"move_left", &"move_up", &"move_down", &"dash"
]

# ── Lifecycle ─────────────────────────────────────────────────────────────────

## Shared instance — cleaned up in after_test() even when assertions fail.
var _pc: PlayerController = null
## Tracks actions we added so we only remove ones we own.
var _temp_actions: Array[StringName] = []


func before_test() -> void:
	_pc = PlayerControllerScript.new() as PlayerController
	_temp_actions.clear()
	for action: StringName in _ALL_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			_temp_actions.append(action)


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

# ── AC-PC-05: Dash state, invincibility, and velocity ────────────────────────

func test_pc_dash_sets_dashing_state_on_press() -> void:
	# Arrange
	add_child(_pc)
	_pc._controller_state = PlayerController.ControllerState.ENABLED
	_pc._dash_cooldown_timer = 0.0
	Input.action_press(&"dash")

	# Act
	_pc._physics_process(1.0 / 60.0)
	Input.action_release(&"dash")

	# Assert
	assert_int(int(_pc.get_controller_state())).is_equal(
		int(PlayerController.ControllerState.DASHING))


func test_pc_dash_sets_invincible_on_press() -> void:
	# Arrange
	add_child(_pc)
	_pc._controller_state = PlayerController.ControllerState.ENABLED
	_pc._dash_cooldown_timer = 0.0
	Input.action_press(&"dash")

	# Act
	_pc._physics_process(1.0 / 60.0)
	Input.action_release(&"dash")

	# Assert
	assert_bool(_pc.is_invincible()).is_true()


func test_pc_dash_velocity_within_one_percent_of_dash_speed() -> void:
	# Arrange — rightward input so dash_dir = Vector2.RIGHT; no walls needed.
	add_child(_pc)
	_pc._controller_state = PlayerController.ControllerState.ENABLED
	_pc._dash_cooldown_timer = 0.0
	Input.action_press(&"move_right")
	Input.action_press(&"dash")

	# Act — velocity is set inside _physics_process before move_and_slide().
	# In a wall-free unit scene the velocity is not modified by collision.
	_pc._physics_process(1.0 / 60.0)
	Input.action_release(&"move_right")
	Input.action_release(&"dash")

	# Assert: within 1% of DASH_SPEED (400 ± 4)
	var tolerance: float = PlayerController.DASH_SPEED * 0.01
	assert_float(_pc.velocity.length()).is_between(
		PlayerController.DASH_SPEED - tolerance,
		PlayerController.DASH_SPEED + tolerance)

# ── AC-PC-06: Dash expires after DASH_DURATION ────────────────────────────────

func test_pc_dash_expires_to_enabled_after_duration() -> void:
	# Arrange — start mid-dash with timer at full duration.
	add_child(_pc)
	_pc._controller_state = PlayerController.ControllerState.DASHING
	_pc._is_invincible = true
	_pc._dash_duration_timer = PlayerController.DASH_DURATION

	# Act — ceil(0.15 * 60) = 9 frames; run 10 to guarantee expiry branch executes.
	var expire_frames: int = ceili(PlayerController.DASH_DURATION * 60.0) + 1
	for _i: int in range(expire_frames):
		_pc._physics_process(1.0 / 60.0)

	# Assert
	assert_int(int(_pc.get_controller_state())).is_equal(
		int(PlayerController.ControllerState.ENABLED))


func test_pc_dash_clears_invincible_after_duration() -> void:
	# Arrange
	add_child(_pc)
	_pc._controller_state = PlayerController.ControllerState.DASHING
	_pc._is_invincible = true
	_pc._dash_duration_timer = PlayerController.DASH_DURATION

	# Act
	var expire_frames: int = ceili(PlayerController.DASH_DURATION * 60.0) + 1
	for _i: int in range(expire_frames):
		_pc._physics_process(1.0 / 60.0)

	# Assert
	assert_bool(_pc.is_invincible()).is_false()


func test_pc_dash_starts_cooldown_after_duration() -> void:
	# Arrange
	add_child(_pc)
	_pc._controller_state = PlayerController.ControllerState.DASHING
	_pc._is_invincible = true
	_pc._dash_duration_timer = PlayerController.DASH_DURATION

	# Act
	var expire_frames: int = ceili(PlayerController.DASH_DURATION * 60.0) + 1
	for _i: int in range(expire_frames):
		_pc._physics_process(1.0 / 60.0)

	# Assert: cooldown timer must be > 0 (exact value will be slightly less than
	# DASH_COOLDOWN because some frames ran after expiry, but it must be positive).
	assert_float(_pc.get_dash_cooldown_remaining()).is_greater(0.0)

# ── AC-PC-07: Dash blocked during cooldown ────────────────────────────────────

func test_pc_dash_blocked_when_cooldown_active_state_unchanged() -> void:
	# Arrange
	add_child(_pc)
	_pc._controller_state = PlayerController.ControllerState.ENABLED
	_pc._dash_cooldown_timer = 1.0  # cooldown still active
	_pc.velocity = Vector2(60.0, 0.0)
	Input.action_press(&"dash")

	# Act
	_pc._physics_process(1.0 / 60.0)
	Input.action_release(&"dash")

	# Assert: still ENABLED, not DASHING
	assert_int(int(_pc.get_controller_state())).is_equal(
		int(PlayerController.ControllerState.ENABLED))


func test_pc_dash_blocked_when_cooldown_active_velocity_not_overridden() -> void:
	# Arrange
	add_child(_pc)
	_pc._controller_state = PlayerController.ControllerState.ENABLED
	_pc._dash_cooldown_timer = 1.0
	# Set velocity directly; after one ENABLED frame with no movement input,
	# friction will reduce it slightly — so we assert it is less than DASH_SPEED,
	# not that it is exactly unchanged (move_and_slide may also clip it in scene).
	# The key invariant: dash was NOT triggered, so velocity.length() << DASH_SPEED.
	_pc.velocity = Vector2(60.0, 0.0)
	Input.action_press(&"dash")

	# Act
	_pc._physics_process(1.0 / 60.0)
	Input.action_release(&"dash")

	# Assert: velocity nowhere near DASH_SPEED (400) — dash did not fire.
	assert_float(_pc.velocity.length()).is_less(PlayerController.DASH_SPEED * 0.5)

# ── AC-PC-08: Default dash direction is Vector2.RIGHT ────────────────────────

func test_pc_dash_default_direction_is_right_when_no_input() -> void:
	# Arrange — default _last_facing_dir = Vector2.RIGHT; no movement input pressed.
	add_child(_pc)
	_pc._controller_state = PlayerController.ControllerState.ENABLED
	_pc._dash_cooldown_timer = 0.0
	# Ensure facing direction is at default (no previous movement in this test).
	assert_vector(_pc.get_facing_direction()).is_equal(Vector2.RIGHT)
	Input.action_press(&"dash")

	# Act
	_pc._physics_process(1.0 / 60.0)
	Input.action_release(&"dash")

	# Assert: velocity points rightward — x positive, y zero within float tolerance.
	assert_float(_pc.velocity.x).is_greater(0.0)
	assert_float(_pc.velocity.y).is_equal_approx(0.0, 0.0001)

# ── AC-PC-13: Dash distance formula ──────────────────────────────────────────

func test_pc_compute_dash_distance_within_one_pixel_of_60() -> void:
	# Arrange / Act — pure formula; no scene setup required.
	var result: float = _pc._compute_dash_distance()
	var expected: float = 60.0  # DASH_SPEED (400) * DASH_DURATION (0.15)

	# Assert: within ±1 px
	assert_float(absf(result - expected)).is_less(1.0)

# ── AC-PC-18: Dash cooldown remaining after partial elapsed time ──────────────

func test_pc_dash_cooldown_remaining_after_0_6s_elapsed() -> void:
	# Arrange — set cooldown timer to full DASH_COOLDOWN (2.0s) directly,
	# simulating the moment a dash just expired. No add_child needed — we drive
	# the cooldown path of _physics_process which does not call move_and_slide
	# in a way that requires a tree RID (ENABLED state handles movement; we set
	# DISABLED so only the cooldown countdown runs). Use DISABLED to avoid the
	# move_and_slide requirement; cooldown countdown is unconditional.
	add_child(_pc)
	_pc._controller_state = PlayerController.ControllerState.ENABLED
	_pc._dash_cooldown_timer = PlayerController.DASH_COOLDOWN  # 2.0s

	# Act — simulate 36 frames = 0.6s at 60fps (ceil(0.6 * 60) = 36).
	var elapsed_frames: int = 36
	for _i: int in range(elapsed_frames):
		_pc._physics_process(1.0 / 60.0)

	# Assert: remaining ≈ 1.4s, tolerance ±0.05s.
	var remaining: float = _pc.get_dash_cooldown_remaining()
	var expected_remaining: float = 1.4
	var tolerance: float = 0.05
	assert_float(absf(remaining - expected_remaining)).is_less_equal(tolerance)
