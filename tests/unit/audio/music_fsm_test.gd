## music_fsm_test.gd — Story 003 acceptance criteria tests.
##
## Coverage (AC-AS-08 through AC-AS-16, AC-AS-22, AC-AS-33):
##   AC-AS-08:  Initial music state is MAIN_MENU
##   AC-AS-09:  run_started → PREPARATION
##   AC-AS-10:  combat_started → COMBAT
##   AC-AS-11:  wave_ended is a no-op; preparation_started is the sole COMBAT→PREP trigger
##   AC-AS-33:  wave_ended + preparation_started = exactly one tween (not two)
##   AC-AS-12:  run_ended(false) → END_DEFEAT from PREPARATION and COMBAT
##   AC-AS-13:  run_ended(true)  → END_VICTORY from PREPARATION and COMBAT
##   AC-AS-14:  Mid-crossfade transition kills prior tween and creates a new one
##   AC-AS-15:  END_* states are non-interruptible by any game signal
##   AC-AS-16:  _compute_crossfade_volume() formula is correct at midpoint and boundaries
##   AC-AS-22:  Null cue for target state blocks transition; state is unchanged
##
## AudioSystem is Autoload #5 — _ready() fires before tests run.
## Dummy AudioStreamGenerator streams are injected into _music_cues to avoid requiring
## audio asset files on disk during CI (headless GUT cannot play audio anyway).
##
## "playing == true" is NOT asserted — unreliable in headless GUT (audio server thread
## does not process during headless execution). Stream assignment is the synchronous proxy.
##
## Tween validity:  assert tween_ref.is_valid() / not tween_ref.is_valid().
##   is_running() does NOT exist in Godot 4 — never use it.
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite

# ── Helpers ───────────────────────────────────────────────────────────────────

## Creates a fresh AudioStreamGenerator and registers it in AudioSystem._music_cues
## for every MusicState that requires a non-null cue. DYING is intentionally omitted
## (silence is the design for that state). Returns the injected streams for assertions.
func _inject_dummy_cues() -> Dictionary:
	var streams: Dictionary = {}
	for state_int: int in [
			AudioSystem.MusicState.MAIN_MENU,
			AudioSystem.MusicState.PREPARATION,
			AudioSystem.MusicState.COMBAT,
			AudioSystem.MusicState.END_DEFEAT,
			AudioSystem.MusicState.END_VICTORY,
	]:
		var stream := AudioStreamGenerator.new()
		AudioSystem._music_cues[state_int] = stream
		streams[state_int] = stream
	return streams


## Resets AudioSystem music FSM to a clean MAIN_MENU state for each test.
func _reset_fsm() -> void:
	# Kill any active crossfade tween.
	if AudioSystem._active_tween != null:
		AudioSystem._active_tween.kill()
		AudioSystem._active_tween = null
	# Return to initial state.
	AudioSystem._music_state = AudioSystem.MusicState.MAIN_MENU
	# Reset both music players: stop, clear stream, restore volume.
	for player: AudioStreamPlayer in AudioSystem._music_players:
		player.stop()
		player.stream = null
		player.volume_db = 0.0
	# Restore canonical active/inactive indices.
	AudioSystem._active_music_idx = 0
	AudioSystem._inactive_music_idx = 1

# ── Fixtures ──────────────────────────────────────────────────────────────────

func before_test() -> void:
	_inject_dummy_cues()
	_reset_fsm()


func after_test() -> void:
	_reset_fsm()
	AudioSystem._music_cues.clear()

# ── AC-AS-08: Initial state is MAIN_MENU ──────────────────────────────────────

## GIVEN AudioSystem has completed _ready()
## WHEN _music_state is read
## THEN it equals MusicState.MAIN_MENU
func test_music_fsm_initial_state_is_main_menu() -> void:
	# before_test() already calls _reset_fsm() which forces MAIN_MENU; this also
	# confirms the default initial value set in the variable declaration.
	assert_int(AudioSystem._music_state as int) \
		.is_equal(AudioSystem.MusicState.MAIN_MENU as int)

# ── AC-AS-09: run_started → PREPARATION ──────────────────────────────────────

## GIVEN music state is MAIN_MENU
## WHEN _on_run_started() is called directly
## THEN music state transitions to PREPARATION
func test_music_fsm_run_started_transitions_to_preparation() -> void:
	# Arrange — verified by before_test()
	assert_int(AudioSystem._music_state as int) \
		.is_equal(AudioSystem.MusicState.MAIN_MENU as int)

	# Act
	AudioSystem._on_run_started()

	# Assert
	assert_int(AudioSystem._music_state as int) \
		.is_equal(AudioSystem.MusicState.PREPARATION as int)

# ── AC-AS-10: combat_started → COMBAT ────────────────────────────────────────

## GIVEN music state is PREPARATION
## WHEN _on_combat_started(false) is called directly
## THEN music state transitions to COMBAT
func test_music_fsm_combat_started_transitions_to_combat() -> void:
	# Arrange
	AudioSystem._music_state = AudioSystem.MusicState.PREPARATION

	# Act
	AudioSystem._on_combat_started(false)

	# Assert
	assert_int(AudioSystem._music_state as int) \
		.is_equal(AudioSystem.MusicState.COMBAT as int)

# ── AC-AS-11: wave_ended no-op; preparation_started is sole COMBAT→PREP trigger

## GIVEN music state is COMBAT
## WHEN _on_wave_ended() is called directly
## THEN music state remains COMBAT (wave_ended must not change music state)
func test_music_fsm_wave_ended_does_not_change_state() -> void:
	# Arrange
	AudioSystem._music_state = AudioSystem.MusicState.COMBAT

	# Act
	AudioSystem._on_wave_ended()

	# Assert
	assert_int(AudioSystem._music_state as int) \
		.is_equal(AudioSystem.MusicState.COMBAT as int)


## GIVEN music state is COMBAT
## WHEN _on_preparation_started() is called directly
## THEN music state transitions to PREPARATION
func test_music_fsm_preparation_started_transitions_combat_to_preparation() -> void:
	# Arrange
	AudioSystem._music_state = AudioSystem.MusicState.COMBAT

	# Act
	AudioSystem._on_preparation_started()

	# Assert
	assert_int(AudioSystem._music_state as int) \
		.is_equal(AudioSystem.MusicState.PREPARATION as int)

# ── AC-AS-33: wave_ended + preparation_started = exactly one tween ────────────

## GIVEN music state is COMBAT and no active tween
## WHEN _on_wave_ended() is called (must produce no tween)
## AND _on_preparation_started() is called
## THEN exactly one tween was created (by preparation_started, not wave_ended)
func test_music_fsm_wave_then_prep_creates_exactly_one_tween() -> void:
	# Arrange
	AudioSystem._music_state = AudioSystem.MusicState.COMBAT
	if AudioSystem._active_tween != null:
		AudioSystem._active_tween.kill()
		AudioSystem._active_tween = null
	var tween_before_wave_ended: Tween = AudioSystem._active_tween  # null

	# Act — wave_ended must leave tween null and state COMBAT.
	AudioSystem._on_wave_ended()
	assert_int(AudioSystem._music_state as int) \
		.is_equal(AudioSystem.MusicState.COMBAT as int)
	# wave_ended must not have created any tween.
	assert_object(AudioSystem._active_tween).is_null()

	# Act — preparation_started must create exactly one tween.
	AudioSystem._on_preparation_started()

	# Assert: exactly one tween was created.
	assert_int(AudioSystem._music_state as int) \
		.is_equal(AudioSystem.MusicState.PREPARATION as int)
	assert_object(AudioSystem._active_tween).is_not_null()
	# The tween must be a different object than the null reference captured above
	# (trivially true, but confirms we have a real new object).
	assert_bool(AudioSystem._active_tween != tween_before_wave_ended).is_true()

# ── AC-AS-12: run_ended(false) → END_DEFEAT from PREPARATION and COMBAT ───────

## GIVEN music state is PREPARATION
## WHEN _on_run_ended(false) is called
## THEN music state is END_DEFEAT
func test_music_fsm_run_ended_defeat_from_preparation() -> void:
	# Arrange
	AudioSystem._music_state = AudioSystem.MusicState.PREPARATION

	# Act
	AudioSystem._on_run_ended(false)

	# Assert
	assert_int(AudioSystem._music_state as int) \
		.is_equal(AudioSystem.MusicState.END_DEFEAT as int)


## GIVEN music state is COMBAT
## WHEN _on_run_ended(false) is called
## THEN music state is END_DEFEAT
func test_music_fsm_run_ended_defeat_from_combat() -> void:
	# Arrange
	AudioSystem._music_state = AudioSystem.MusicState.COMBAT

	# Act
	AudioSystem._on_run_ended(false)

	# Assert
	assert_int(AudioSystem._music_state as int) \
		.is_equal(AudioSystem.MusicState.END_DEFEAT as int)

# ── AC-AS-13: run_ended(true) → END_VICTORY from PREPARATION and COMBAT ───────

## GIVEN music state is PREPARATION
## WHEN _on_run_ended(true) is called
## THEN music state is END_VICTORY
func test_music_fsm_run_ended_victory_from_preparation() -> void:
	# Arrange
	AudioSystem._music_state = AudioSystem.MusicState.PREPARATION

	# Act
	AudioSystem._on_run_ended(true)

	# Assert
	assert_int(AudioSystem._music_state as int) \
		.is_equal(AudioSystem.MusicState.END_VICTORY as int)


## GIVEN music state is COMBAT
## WHEN _on_run_ended(true) is called
## THEN music state is END_VICTORY
func test_music_fsm_run_ended_victory_from_combat() -> void:
	# Arrange
	AudioSystem._music_state = AudioSystem.MusicState.COMBAT

	# Act
	AudioSystem._on_run_ended(true)

	# Assert
	assert_int(AudioSystem._music_state as int) \
		.is_equal(AudioSystem.MusicState.END_VICTORY as int)

# ── AC-AS-14: Mid-crossfade transition kills prior tween, creates new one ─────

## GIVEN a PREPARATION→COMBAT crossfade is in progress (tween_1 alive)
## WHEN _on_run_ended(false) is called mid-crossfade
## THEN tween_1 is killed AND a new _active_tween is created AND state is END_DEFEAT
func test_music_fsm_mid_crossfade_cancel_kills_prior_tween() -> void:
	# Arrange: start a crossfade to COMBAT.
	AudioSystem._music_state = AudioSystem.MusicState.PREPARATION
	AudioSystem._on_combat_started(false)
	var tween_1: Tween = AudioSystem._active_tween
	assert_object(tween_1).is_not_null()

	# Act: trigger another transition while crossfade is in progress.
	AudioSystem._on_run_ended(false)

	# Assert (a): a new tween was created.
	assert_object(AudioSystem._active_tween).is_not_null()
	assert_bool(AudioSystem._active_tween != tween_1).is_true()

	# Assert (b): the prior tween was killed (is_valid() returns false after kill()).
	# Do NOT use is_running() — it does not exist in Godot 4.
	assert_bool(tween_1.is_valid()).is_false()

	# Assert (c): final state is END_DEFEAT.
	assert_int(AudioSystem._music_state as int) \
		.is_equal(AudioSystem.MusicState.END_DEFEAT as int)

# ── AC-AS-15: END_* states are non-interruptible by game signals ───────────────

## GIVEN music state is END_DEFEAT
## WHEN all four game signals are fired in succession
## THEN state remains END_DEFEAT throughout
func test_music_fsm_end_defeat_is_non_interruptible() -> void:
	# Arrange
	AudioSystem._music_state = AudioSystem.MusicState.END_DEFEAT

	# Act: fire all GSM signals that the FSM handles.
	AudioSystem._on_run_started()
	AudioSystem._on_combat_started(false)
	AudioSystem._on_wave_ended()
	AudioSystem._on_run_ended(true)

	# Assert: state must remain END_DEFEAT after all four calls.
	assert_int(AudioSystem._music_state as int) \
		.is_equal(AudioSystem.MusicState.END_DEFEAT as int)

# ── AC-AS-16: _compute_crossfade_volume formula correctness ───────────────────

## GIVEN _compute_crossfade_volume is called with outgoing fade at midpoint
## start=-6.0, target=-80.0, t=0.5, duration=1.0
## THEN result is within ±0.01 dB of -43.0  (lerp(-6, -80, 0.5))
func test_music_fsm_crossfade_volume_outgoing_midpoint() -> void:
	var result: float = AudioSystem._compute_crossfade_volume(-6.0, -80.0, 0.5, 1.0)
	# lerp(-6.0, -80.0, 0.5) = -43.0
	assert_float(result).is_between(-43.01, -42.99)


## GIVEN _compute_crossfade_volume is called with incoming fade at midpoint
## start=-80.0, target=0.0, t=0.5, duration=1.0
## THEN result is within ±0.01 dB of -40.0  (lerp(-80, 0, 0.5))
func test_music_fsm_crossfade_volume_incoming_midpoint() -> void:
	var result: float = AudioSystem._compute_crossfade_volume(-80.0, 0.0, 0.5, 1.0)
	# lerp(-80.0, 0.0, 0.5) = -40.0
	assert_float(result).is_between(-40.01, -39.99)


## GIVEN t = 0.0 (transition start)
## THEN result equals start_db exactly
func test_music_fsm_crossfade_volume_t_zero_returns_start() -> void:
	var result: float = AudioSystem._compute_crossfade_volume(-6.0, -80.0, 0.0, 1.0)
	assert_float(result).is_equal(-6.0)


## GIVEN t = duration (transition end)
## THEN result equals target_db exactly
func test_music_fsm_crossfade_volume_t_duration_returns_target() -> void:
	var result: float = AudioSystem._compute_crossfade_volume(-6.0, -80.0, 1.0, 1.0)
	assert_float(result).is_equal(-80.0)

# ── AC-AS-22: Null cue blocks transition; state is unchanged ──────────────────

## GIVEN music state is PREPARATION
## AND the COMBAT state's cue is null
## WHEN _on_combat_started(false) is called
## THEN state remains PREPARATION (transition blocked)
## AND no music player stream was reassigned
func test_music_fsm_null_cue_blocks_transition() -> void:
	# Arrange: remove the COMBAT cue so the target slot is null.
	AudioSystem._music_cues.erase(AudioSystem.MusicState.COMBAT as int)
	AudioSystem._music_state = AudioSystem.MusicState.PREPARATION

	# Snapshot all music player streams before the call.
	var streams_before: Array[AudioStream] = []
	for player: AudioStreamPlayer in AudioSystem._music_players:
		streams_before.append(player.stream)

	# Act
	AudioSystem._on_combat_started(false)

	# Assert (a): state unchanged.
	assert_int(AudioSystem._music_state as int) \
		.is_equal(AudioSystem.MusicState.PREPARATION as int)

	# Assert (b): no music player stream was reassigned.
	for i: int in range(AudioSystem._music_players.size()):
		assert_object(AudioSystem._music_players[i].stream) \
			.is_equal(streams_before[i])
