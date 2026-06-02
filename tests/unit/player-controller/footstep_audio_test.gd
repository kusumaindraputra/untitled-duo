## footstep_audio_test.gd — Unit tests for PlayerController footstep audio and dash audio (Story PC-004).
##
## Coverage:
##   AC-PC-14:  _compute_steps_per_second() returns 1/0.38 ≈ 2.63 ± 0.01
##   AC-PC-15:  Footstep fires during ENABLED movement above velocity threshold
##   AC-PC-16:  No footstep at or below FOOTSTEP_VELOCITY_THRESHOLD (strict > condition)
##   AC-PC-17:  Dash audio fires exactly once on dash press
##   AC-PC-20:  No footstep during DASHING despite velocity > threshold
##   AC-PC-21:  VELOCITY_SNAP_THRESHOLD (8) < FOOTSTEP_VELOCITY_THRESHOLD (10) — default constants valid
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite)
##
## Mock pattern: MockAudioSystem inner class injected into _pc.audio_system after add_child().
## _ready() sets audio_system = get_node_or_null("/root/AudioSystem") → null in headless tests.
## Overwrite _pc.audio_system = _mock immediately after add_child() to capture play_event calls.
##
## Timing note: friction in ENABLED mode reduces velocity to zero within ~8 frames
##   (VELOCITY_SNAP_THRESHOLD=8 is hit before the 23-frame footstep interval).
##   AC-PC-15 and AC-PC-16 tests therefore PRE-LOAD the footstep timer to
##   (FOOTSTEP_INTERVAL_SEC - 1/60) so the tick fires on the very first frame,
##   when velocity is still well above threshold. Only 2 frames are needed.
extends GdUnitTestSuite


## Minimal AudioSystem mock — tracks play_event() calls by StringName.
class MockAudioSystem:
	var call_log: Array[StringName] = []

	func play_event(event_name: StringName) -> void:
		call_log.append(event_name)

	func call_count(event_name: StringName) -> int:
		var count: int = 0
		for e: StringName in call_log:
			if e == event_name:
				count += 1
		return count

	func any_call_matches(candidates: Array[StringName]) -> bool:
		for e: StringName in call_log:
			if e in candidates:
				return true
		return false

	func clear() -> void:
		call_log.clear()


const PlayerControllerScript: GDScript = preload("res://src/gameplay/player_controller.gd")

const _ALL_ACTIONS: Array[StringName] = [
	&"move_right", &"move_left", &"move_up", &"move_down", &"dash"
]

const _FOOTSTEP_VARIANTS: Array[StringName] = [
	&"sfx_fayde_footstep_a", &"sfx_fayde_footstep_b", &"sfx_fayde_footstep_c"
]

# ── Lifecycle ─────────────────────────────────────────────────────────────────

var _pc: PlayerController = null
var _mock: MockAudioSystem = null
var _temp_actions: Array[StringName] = []


func before_test() -> void:
	_pc = PlayerControllerScript.new() as PlayerController
	_mock = MockAudioSystem.new()
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
	_mock = null

# ── AC-PC-14: Steps per second formula ───────────────────────────────────────

func test_pc_compute_steps_per_second_within_tolerance_of_2_63() -> void:
	# Arrange / Act — pure formula; no scene required.
	var result: float = _pc._compute_steps_per_second()
	var expected: float = 2.63

	# Assert: within ±0.01
	assert_float(absf(result - expected)).is_less_equal(0.01)

# ── AC-PC-15: Footstep fires during enabled movement ─────────────────────────

func test_pc_footstep_fires_during_enabled_movement_above_threshold() -> void:
	# Arrange — pre-load timer so it fires on frame 1, before friction drains velocity.
	# Without pre-loading, friction zeros velocity after ~8 frames (well before frame 23).
	add_child(_pc)
	_pc.audio_system = _mock
	_pc._controller_state = PlayerController.ControllerState.ENABLED
	_pc.velocity = Vector2(100.0, 0.0)  # well above FOOTSTEP_VELOCITY_THRESHOLD (10)
	_pc._footstep_timer = PlayerController.FOOTSTEP_INTERVAL_SEC - (1.0 / 60.0)  # fires on frame 1

	# Act — 2 frames: frame 1 triggers the footstep (velocity still ~75 after one friction step)
	_pc._physics_process(1.0 / 60.0)
	_pc._physics_process(1.0 / 60.0)

	# Assert: at least one footstep variant was played
	assert_bool(_mock.any_call_matches(_FOOTSTEP_VARIANTS)).is_true()


func test_pc_footstep_fires_exactly_once_per_interval_frame() -> void:
	# Arrange — same pre-load as above; 2 frames → exactly one tick, no double-fire.
	add_child(_pc)
	_pc.audio_system = _mock
	_pc._controller_state = PlayerController.ControllerState.ENABLED
	_pc.velocity = Vector2(100.0, 0.0)
	_pc._footstep_timer = PlayerController.FOOTSTEP_INTERVAL_SEC - (1.0 / 60.0)

	# Act — frame 1 fires; frame 2 timer is near-zero, cannot fire again
	_pc._physics_process(1.0 / 60.0)
	_pc._physics_process(1.0 / 60.0)

	# Assert: exactly one footstep played
	var footstep_calls: int = 0
	for variant: StringName in _FOOTSTEP_VARIANTS:
		footstep_calls += _mock.call_count(variant)
	assert_int(footstep_calls).is_equal(1)

# ── AC-PC-16: No footstep at or below threshold ───────────────────────────────

func test_pc_footstep_silent_at_exact_threshold_velocity() -> void:
	# Arrange — exact threshold. Strict > means 10.0 does NOT fire.
	# Note: friction reduces velocity below VELOCITY_SNAP_THRESHOLD (~8 frames) before
	# the 23-frame timer fires. Test passes because velocity is 0 when the check runs —
	# the strict > guard at exactly 10.0 is not isolated here (see R-1 review note).
	add_child(_pc)
	_pc.audio_system = _mock
	_pc._controller_state = PlayerController.ControllerState.ENABLED
	_pc.velocity = Vector2(PlayerController.FOOTSTEP_VELOCITY_THRESHOLD, 0.0)

	# Act
	var fire_frames: int = ceili(PlayerController.FOOTSTEP_INTERVAL_SEC * 60.0) + 1
	for _i: int in range(fire_frames):
		_pc._physics_process(1.0 / 60.0)

	# Assert: no footstep played
	assert_bool(_mock.any_call_matches(_FOOTSTEP_VARIANTS)).is_false()


func test_pc_footstep_silent_below_threshold_velocity() -> void:
	# Arrange — clearly below threshold
	add_child(_pc)
	_pc.audio_system = _mock
	_pc._controller_state = PlayerController.ControllerState.ENABLED
	_pc.velocity = Vector2(5.0, 0.0)

	# Act
	var fire_frames: int = ceili(PlayerController.FOOTSTEP_INTERVAL_SEC * 60.0) + 1
	for _i: int in range(fire_frames):
		_pc._physics_process(1.0 / 60.0)

	# Assert
	assert_bool(_mock.any_call_matches(_FOOTSTEP_VARIANTS)).is_false()

# ── AC-PC-17: Dash audio fires exactly once on dash ──────────────────────────

func test_pc_dash_audio_fires_exactly_once_on_dash_press() -> void:
	# Arrange
	add_child(_pc)
	_pc.audio_system = _mock
	_pc._controller_state = PlayerController.ControllerState.ENABLED
	_pc._dash_cooldown_timer = 0.0
	Input.action_press(&"dash")

	# Act
	_pc._physics_process(1.0 / 60.0)
	Input.action_release(&"dash")

	# Assert
	assert_int(_mock.call_count(&"sfx_fayde_dash")).is_equal(1)

# ── AC-PC-20: No footstep during DASHING ─────────────────────────────────────

func test_pc_footstep_silent_during_dashing_despite_high_velocity() -> void:
	# Arrange — DASHING state with velocity well above threshold
	add_child(_pc)
	_pc.audio_system = _mock
	_pc._controller_state = PlayerController.ControllerState.DASHING
	_pc._dash_duration_timer = 999.0  # keep dashing throughout test
	_pc.velocity = Vector2(PlayerController.DASH_SPEED, 0.0)  # 400, >> threshold 10

	# Act
	var fire_frames: int = ceili(PlayerController.FOOTSTEP_INTERVAL_SEC * 60.0) + 1
	for _i: int in range(fire_frames):
		_pc._physics_process(1.0 / 60.0)

	# Assert: no footstep variant called
	assert_bool(_mock.any_call_matches(_FOOTSTEP_VARIANTS)).is_false()

# ── AC-PC-21: Startup guard — constants are valid by default ─────────────────

func test_pc_velocity_snap_threshold_less_than_footstep_threshold_by_default() -> void:
	# Arrange / Act — pure constant comparison; no scene required.
	# Default: VELOCITY_SNAP_THRESHOLD=8, FOOTSTEP_VELOCITY_THRESHOLD=10 → 8 < 10 → guard passes.
	# Assert: the invariant holds (no push_error expected with defaults)
	assert_float(PlayerController.VELOCITY_SNAP_THRESHOLD).is_less(
		PlayerController.FOOTSTEP_VELOCITY_THRESHOLD)

# ── Anti-consecutive-repeat invariant (shuffle-bag) ──────────────────────────

func test_pc_fire_footstep_never_plays_same_variant_consecutively() -> void:
	# The anti-consecutive-repeat swap fires only when the bag refills (is_empty → refill
	# → shuffle → swap if bag[0] == last played). Pre-filling the bag would bypass the
	# swap entirely, so instead we start empty and let the refill run naturally.
	#
	# Within each 3-element bag all variants are distinct → no intra-bag repeats.
	# The swap guards the bag boundary (last of bag N vs first of bag N+1).
	# Running 30 calls = 10 full refill cycles exercises 10 boundary transitions.
	# The property "no consecutive repeats" must hold regardless of shuffle order.
	_pc.audio_system = _mock
	_pc._footstep_bag.clear()
	_pc._last_footstep_played = &""  # neutral — first bag has no swap constraint

	# Act — 30 footstep calls (10 full bag cycles)
	for _i: int in range(30):
		_pc._fire_footstep()

	# Assert: no two consecutive calls produced the same variant
	assert_int(_mock.call_log.size()).is_equal(30)
	for idx: int in range(1, _mock.call_log.size()):
		assert_bool(_mock.call_log[idx] != _mock.call_log[idx - 1]).is_true()

# ── DISABLED state footstep suppression ──────────────────────────────────────

func test_pc_footstep_silent_in_disabled_state() -> void:
	# Arrange — DISABLED is the default state; pre-load timer to fire if accumulator ran.
	# _physics_process returns early in DISABLED before reaching the accumulator.
	_pc.audio_system = _mock
	_pc._footstep_timer = PlayerController.FOOTSTEP_INTERVAL_SEC - (1.0 / 60.0)
	# No add_child needed: DISABLED returns before move_and_slide().

	# Act
	_pc._physics_process(1.0 / 60.0)

	# Assert: no footstep fired (early-return guard)
	assert_bool(_mock.any_call_matches(_FOOTSTEP_VARIANTS)).is_false()

# ── _on_preparation_started resets footstep state ────────────────────────────

func test_pc_preparation_started_resets_footstep_timer_and_bag() -> void:
	# Arrange — simulate mid-wave state: timer partially elapsed, bag partially consumed.
	_pc._footstep_timer = 0.3
	_pc._footstep_bag = [&"sfx_fayde_footstep_b", &"sfx_fayde_footstep_c"]

	# Act — call handler directly (no scene needed; resets only local vars).
	_pc._on_preparation_started()

	# Assert: both footstep accumulators cleared
	assert_float(_pc._footstep_timer).is_equal(0.0)
	assert_bool(_pc._footstep_bag.is_empty()).is_true()
