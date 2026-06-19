## music_fsm_dying_test.gd — Story 004 acceptance criteria tests.
##
## Coverage (AC-AS-26, AC-AS-27, AC-AS-28, AC-AS-29):
##   AC-AS-28:  _on_death_started() → DYING + active tween created
##   AC-AS-29:  DYING hold guard — early run_ended queues; fires after elapsed threshold
##   AC-AS-26:  END auto-transition via finished signal → MAIN_MENU
##   AC-AS-27:  After auto-transition reaches MAIN_MENU → run_started → PREPARATION
##
## AudioSystem is Autoload #5 — _ready() fires before tests run.
## Dummy AudioStreamGenerator streams are injected into _music_cues to avoid requiring
## audio asset files on disk during CI (headless GUT cannot play audio).
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite

# ── Dummy cues ────────────────────────────────────────────────────────────────

var _dummy_prep_cue: AudioStreamGenerator
var _dummy_combat_cue: AudioStreamGenerator
var _dummy_defeat_cue: AudioStreamGenerator
var _dummy_victory_cue: AudioStreamGenerator
var _dummy_menu_cue: AudioStreamGenerator

# ── Per-test setup / teardown ─────────────────────────────────────────────────

func before_test() -> void:
	_dummy_prep_cue = AudioStreamGenerator.new()
	_dummy_combat_cue = AudioStreamGenerator.new()
	_dummy_defeat_cue = AudioStreamGenerator.new()
	_dummy_victory_cue = AudioStreamGenerator.new()
	_dummy_menu_cue = AudioStreamGenerator.new()
	AudioSystem._music_cues[AudioSystem.MusicState.PREPARATION] = _dummy_prep_cue
	AudioSystem._music_cues[AudioSystem.MusicState.COMBAT] = _dummy_combat_cue
	AudioSystem._music_cues[AudioSystem.MusicState.END_DEFEAT] = _dummy_defeat_cue
	AudioSystem._music_cues[AudioSystem.MusicState.END_VICTORY] = _dummy_victory_cue
	AudioSystem._music_cues[AudioSystem.MusicState.MAIN_MENU] = _dummy_menu_cue


func after_test() -> void:
	AudioSystem._music_state = AudioSystem.MusicState.MAIN_MENU
	AudioSystem._active_music_idx = 0
	AudioSystem._inactive_music_idx = 1
	AudioSystem._dying_elapsed = 0.0
	AudioSystem._pending_defeat_transition = false
	if AudioSystem._active_tween != null:
		AudioSystem._active_tween.kill()
		AudioSystem._active_tween = null
	AudioSystem._music_cues.clear()
	for player: AudioStreamPlayer in AudioSystem._music_players:
		player.volume_db = 0.0
		player.stream = null

# ── AC-AS-28: death_started → DYING + tween ──────────────────────────────────

func test_death_started_transitions_to_dying() -> void:
	AudioSystem._music_state = AudioSystem.MusicState.COMBAT
	AudioSystem._on_death_started()
	assert_int(AudioSystem._music_state).is_equal(AudioSystem.MusicState.DYING)


func test_death_started_creates_active_tween() -> void:
	AudioSystem._music_state = AudioSystem.MusicState.COMBAT
	AudioSystem._on_death_started()
	assert_object(AudioSystem._active_tween).is_not_null()


func test_death_started_in_end_defeat_state_is_noop() -> void:
	AudioSystem._music_state = AudioSystem.MusicState.END_DEFEAT
	AudioSystem._on_death_started()
	assert_int(AudioSystem._music_state).is_equal(AudioSystem.MusicState.END_DEFEAT)


func test_death_started_in_end_victory_state_is_noop() -> void:
	AudioSystem._music_state = AudioSystem.MusicState.END_VICTORY
	AudioSystem._on_death_started()
	assert_int(AudioSystem._music_state).is_equal(AudioSystem.MusicState.END_VICTORY)

# ── AC-AS-29 Test A: early run_ended queues pending transition ────────────────

func test_run_ended_false_in_dying_before_hold_queues_transition() -> void:
	AudioSystem._music_state = AudioSystem.MusicState.COMBAT
	AudioSystem._on_death_started()
	AudioSystem._on_run_ended(false)
	assert_int(AudioSystem._music_state).is_equal(AudioSystem.MusicState.DYING)
	assert_bool(AudioSystem._pending_defeat_transition).is_true()

# ── AC-AS-29 Test B: queued transition fires after hold elapsed ───────────────

func test_run_ended_false_in_dying_after_hold_fires_end_defeat() -> void:
	AudioSystem._music_state = AudioSystem.MusicState.COMBAT
	AudioSystem._on_death_started()
	AudioSystem._on_run_ended(false)
	# state still DYING, transition pending
	assert_int(AudioSystem._music_state).is_equal(AudioSystem.MusicState.DYING)
	# advance elapsed past threshold via test seam
	AudioSystem._set_dying_elapsed(AudioSystem.DYING_MIN_HOLD_SEC + 0.1)
	# trigger _process() directly to fire the queued transition
	AudioSystem._process(0.0)
	assert_int(AudioSystem._music_state).is_equal(AudioSystem.MusicState.END_DEFEAT)
	assert_bool(AudioSystem._pending_defeat_transition).is_false()


func test_run_ended_false_in_dying_before_hold_threshold_stays_dying() -> void:
	AudioSystem._music_state = AudioSystem.MusicState.COMBAT
	AudioSystem._on_death_started()
	AudioSystem._on_run_ended(false)
	AudioSystem._set_dying_elapsed(AudioSystem.DYING_MIN_HOLD_SEC - 0.01)
	AudioSystem._process(0.0)
	assert_int(AudioSystem._music_state).is_equal(AudioSystem.MusicState.DYING)

# ── AC-AS-26: END auto-transition via finished signal ────────────────────────

func test_end_defeat_autotransitions_to_main_menu_on_finished() -> void:
	AudioSystem._music_state = AudioSystem.MusicState.PREPARATION
	AudioSystem._on_run_ended(false)
	assert_int(AudioSystem._music_state).is_equal(AudioSystem.MusicState.END_DEFEAT)
	# Emit finished on the active (incoming) player — triggers _on_end_cue_finished
	var incoming: AudioStreamPlayer = AudioSystem._music_players[AudioSystem._active_music_idx]
	incoming.finished.emit()
	assert_int(AudioSystem._music_state).is_equal(AudioSystem.MusicState.MAIN_MENU)


func test_end_victory_autotransitions_to_main_menu_on_finished() -> void:
	AudioSystem._music_state = AudioSystem.MusicState.PREPARATION
	AudioSystem._on_run_ended(true)
	assert_int(AudioSystem._music_state).is_equal(AudioSystem.MusicState.END_VICTORY)
	var incoming: AudioStreamPlayer = AudioSystem._music_players[AudioSystem._active_music_idx]
	incoming.finished.emit()
	assert_int(AudioSystem._music_state).is_equal(AudioSystem.MusicState.MAIN_MENU)

# ── AC-AS-27: MAIN_MENU → PREPARATION after auto-transition ──────────────────

func test_after_autotransition_run_started_goes_to_preparation() -> void:
	AudioSystem._music_state = AudioSystem.MusicState.PREPARATION
	AudioSystem._on_run_ended(false)
	var incoming: AudioStreamPlayer = AudioSystem._music_players[AudioSystem._active_music_idx]
	incoming.finished.emit()
	assert_int(AudioSystem._music_state).is_equal(AudioSystem.MusicState.MAIN_MENU)
	AudioSystem._on_run_started()
	assert_int(AudioSystem._music_state).is_equal(AudioSystem.MusicState.PREPARATION)
