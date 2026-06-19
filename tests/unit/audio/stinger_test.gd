## stinger_test.gd — Story 006 acceptance criteria tests.
##
## Coverage (AC-AS-35, AC-AS-36):
##   AC-AS-35: play_stinger() routes to _stinger_player, does not use SFX pool,
##             and immediately ducks the Music bus by duck_depth_db.
##   AC-AS-36: stop_stinger() creates a restore tween and resets priority state.
##
## AudioSystem is Autoload — _ready() fires before tests run.
## Events injected directly into _validated_events to avoid registry file dependency.
## `playing` is NOT asserted — unreliable in headless GUT (see Story 002 engine notes).
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite

const _STINGER_KEY: StringName = &"dummy_stinger"

var _dummy_stream: AudioStreamWAV = null


func before_test() -> void:
	_dummy_stream = AudioStreamWAV.new()
	var stinger_event := AudioEventData.new()
	stinger_event.stream = _dummy_stream
	stinger_event.bus = AudioSystem.BUS_SFX
	stinger_event.duck_depth_db = -6.0
	stinger_event.restore_duration_sec = 0.5
	stinger_event.stinger_priority = 0
	AudioSystem._validated_events[_STINGER_KEY] = stinger_event


func after_test() -> void:
	# Disconnect finished signal if still connected.
	if AudioSystem._stinger_player.finished.is_connected(AudioSystem._on_stinger_finished):
		AudioSystem._stinger_player.finished.disconnect(AudioSystem._on_stinger_finished)
	AudioSystem._stinger_player.stop()
	AudioSystem._stinger_player.stream = null
	AudioSystem._current_stinger_priority = -1
	AudioSystem._last_stinger_event = null
	if AudioSystem._active_stinger_tween != null:
		AudioSystem._active_stinger_tween.kill()
		AudioSystem._active_stinger_tween = null
	# Restore Music bus volume to 0 dB.
	var music_bus_idx: int = AudioServer.get_bus_index(&"Music")
	AudioServer.set_bus_volume_db(music_bus_idx, 0.0)
	AudioSystem._validated_events.erase(_STINGER_KEY)
	_dummy_stream = null


# ── AC-AS-35: play_stinger routes to stinger player ──────────────────────────

func test_play_stinger_assigns_stream_to_stinger_player() -> void:
	# Arrange / Act
	AudioSystem.play_stinger(_STINGER_KEY)
	# Assert
	assert_object(AudioSystem._stinger_player.stream).is_equal(_dummy_stream)


func test_play_stinger_does_not_use_sfx_pool() -> void:
	# Arrange — capture pool streams before call.
	var before: Array = []
	for p: AudioStreamPlayer in AudioSystem._sfx_pool:
		before.append(p.stream)
	# Act
	AudioSystem.play_stinger(_STINGER_KEY)
	# Assert — all 24 pool slots unchanged.
	for i: int in range(AudioSystem._sfx_pool.size()):
		assert_object(AudioSystem._sfx_pool[i].stream).is_equal(before[i])


func test_play_stinger_ducks_music_bus() -> void:
	# Arrange — record Music bus volume before call.
	var music_bus_idx: int = AudioServer.get_bus_index(&"Music")
	var prior_db: float = AudioServer.get_bus_volume_db(music_bus_idx)
	# Act
	AudioSystem.play_stinger(_STINGER_KEY)
	# Assert — bus must be within ±0.01 dB of (prior + duck_depth_db).
	var after_db: float = AudioServer.get_bus_volume_db(music_bus_idx)
	var expected_db: float = prior_db - 6.0  # duck_depth_db = -6.0
	assert_float(after_db).is_between(expected_db - 0.01, expected_db + 0.01)


func test_play_stinger_unregistered_event_logs_error() -> void:
	# Should push_error() and not crash or assign a stream.
	AudioSystem.play_stinger(&"nonexistent_stinger")
	assert_object(AudioSystem._stinger_player.stream).is_null()


# ── AC-AS-36: stop_stinger creates restore tween ─────────────────────────────

func test_stop_stinger_creates_restore_tween() -> void:
	# Arrange
	AudioSystem.play_stinger(_STINGER_KEY)
	# Act
	AudioSystem.stop_stinger()
	# Assert — restore tween must be non-null.
	assert_object(AudioSystem._active_stinger_tween).is_not_null()


func test_stop_stinger_resets_priority() -> void:
	# Arrange
	AudioSystem.play_stinger(_STINGER_KEY)
	# Act
	AudioSystem.stop_stinger()
	# Assert — priority sentinel reset to -1 (no stinger active).
	assert_int(AudioSystem._current_stinger_priority).is_equal(-1)


func test_stop_stinger_clears_stream() -> void:
	# Arrange
	AudioSystem.play_stinger(_STINGER_KEY)
	# Act
	AudioSystem.stop_stinger()
	# Assert
	assert_object(AudioSystem._stinger_player.stream).is_null()


# ── Edge case: wrong bus guard ────────────────────────────────────────────────

func test_play_stinger_amb_bus_logs_error_and_no_stream() -> void:
	# Arrange — inject a stinger event with the wrong bus.
	var amb_event := AudioEventData.new()
	amb_event.bus = &"AMB"
	amb_event.stinger_priority = 0
	AudioSystem._validated_events[&"dummy_amb_stinger"] = amb_event
	# Act
	AudioSystem.play_stinger(&"dummy_amb_stinger")
	# Assert — stinger player must be untouched.
	assert_object(AudioSystem._stinger_player.stream).is_null()
	# Cleanup
	AudioSystem._validated_events.erase(&"dummy_amb_stinger")
	amb_event = null
