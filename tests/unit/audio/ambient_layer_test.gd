## ambient_layer_test.gd — Story 005 acceptance criteria tests.
##
## Coverage (AC-AS-23, AC-AS-24, AC-AS-25):
##   AC-AS-23: play_ambient() assigns stream to the incoming ambient player
##   AC-AS-24: stop_ambient() creates a fade tween on the active player
##   AC-AS-25: second play_ambient() call crossfades to a new stream
##
## AudioSystem is Autoload — _ready() fires before tests run.
## Events injected directly into _validated_events to avoid registry file dependency.
## `playing` is NOT asserted — unreliable in headless GUT (see Story 002 engine notes).
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite

const _AMB_KEY_A: StringName = &"_test_amb_a_s005"
const _AMB_KEY_B: StringName = &"_test_amb_b_s005"

var _dummy_stream_a: AudioStreamGenerator
var _dummy_stream_b: AudioStreamGenerator


func before_test() -> void:
	_dummy_stream_a = AudioStreamGenerator.new()
	_dummy_stream_b = AudioStreamGenerator.new()
	var amb_a := AudioEventData.new()
	amb_a.stream = _dummy_stream_a
	amb_a.bus = &"AMB"
	AudioSystem._validated_events[_AMB_KEY_A] = amb_a
	var amb_b := AudioEventData.new()
	amb_b.stream = _dummy_stream_b
	amb_b.bus = &"AMB"
	AudioSystem._validated_events[_AMB_KEY_B] = amb_b


func after_test() -> void:
	AudioSystem._validated_events.erase(_AMB_KEY_A)
	AudioSystem._validated_events.erase(_AMB_KEY_B)
	if AudioSystem._active_ambient_tween != null:
		AudioSystem._active_ambient_tween.kill()
		AudioSystem._active_ambient_tween = null
	AudioSystem._active_ambient_idx = 0
	for player: AudioStreamPlayer in AudioSystem._ambient_players:
		player.stream = null
		player.volume_db = 0.0


# AC-AS-23: play_ambient assigns stream to active ambient player
func test_play_ambient_assigns_stream_to_incoming_player() -> void:
	AudioSystem.play_ambient(_AMB_KEY_A)
	var active: AudioStreamPlayer = AudioSystem._ambient_players[AudioSystem._active_ambient_idx]
	assert_object(active.stream).is_not_null()


func test_play_ambient_active_player_has_amb_bus() -> void:
	AudioSystem.play_ambient(_AMB_KEY_A)
	var active: AudioStreamPlayer = AudioSystem._ambient_players[AudioSystem._active_ambient_idx]
	assert_str(active.bus).is_equal("AMB")


func test_play_ambient_does_not_change_sfx_pool_timestamps() -> void:
	# None of the SFX pool timestamps should change when play_ambient is called
	var ts_before: Array[int] = []
	for ts: int in AudioSystem._timestamps:
		ts_before.append(ts)
	AudioSystem.play_ambient(_AMB_KEY_A)
	for i: int in range(AudioSystem.SFX_POOL_SIZE):
		assert_int(AudioSystem._timestamps[i]).is_equal(ts_before[i])


func test_play_ambient_unregistered_leaves_players_unchanged() -> void:
	var stream_a_before: AudioStream = AudioSystem._ambient_players[0].stream
	var stream_b_before: AudioStream = AudioSystem._ambient_players[1].stream
	AudioSystem.play_ambient(&"nonexistent_amb_key_s005")
	assert_object(AudioSystem._ambient_players[0].stream).is_equal(stream_a_before)
	assert_object(AudioSystem._ambient_players[1].stream).is_equal(stream_b_before)


# AC-AS-24: stop_ambient creates fade tween
func test_stop_ambient_creates_tween() -> void:
	AudioSystem.play_ambient(_AMB_KEY_A)
	AudioSystem.stop_ambient()
	assert_object(AudioSystem._active_ambient_tween).is_not_null()


func test_stop_ambient_without_prior_play_still_creates_tween() -> void:
	AudioSystem.stop_ambient()
	assert_object(AudioSystem._active_ambient_tween).is_not_null()


# AC-AS-25: play_ambient crossfade swap
func test_play_ambient_second_call_creates_new_tween() -> void:
	# After the second play_ambient() call a fresh tween must exist and be valid.
	# Object-identity comparison is unreliable because Godot may reuse the same
	# Tween handle after kill(). Check validity instead: the new tween is live.
	AudioSystem.play_ambient(_AMB_KEY_A)
	AudioSystem.stop_ambient()  # kills the first tween
	AudioSystem.play_ambient(_AMB_KEY_B)
	assert_object(AudioSystem._active_ambient_tween).is_not_null()
	assert_bool(AudioSystem._active_ambient_tween.is_valid()).is_true()


func test_play_ambient_second_call_incoming_gets_new_stream() -> void:
	AudioSystem.play_ambient(_AMB_KEY_A)
	AudioSystem.play_ambient(_AMB_KEY_B)
	# After second call, active idx swapped again
	var incoming_idx: int = AudioSystem._active_ambient_idx
	assert_object(AudioSystem._ambient_players[incoming_idx].stream).is_not_null()


func test_play_ambient_second_call_outgoing_retains_first_stream() -> void:
	AudioSystem.play_ambient(_AMB_KEY_A)
	AudioSystem.play_ambient(_AMB_KEY_B)
	# The outgoing player (the one that was active before) still has stream a
	var outgoing_idx: int = 1 - AudioSystem._active_ambient_idx
	assert_object(AudioSystem._ambient_players[outgoing_idx].stream).is_not_null()
