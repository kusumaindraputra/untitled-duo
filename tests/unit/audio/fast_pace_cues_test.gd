## fast_pace_cues_test.gd — Audio for the fast-pace / bullet-hell mechanics.
##
## Coverage:
##   - Every new cue is registered on the SFX bus with a real stream
##   - min_interval_sec throttles repeats; 0 never throttles
##   - pitch_jitter and volume_db are applied to the pool player
##   - Sfx.play() routes through AudioSystem and is a no-op for unknown events
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const NEW_CUES: Array[StringName] = [
	&"sfx_bullet_fire", &"sfx_enemy_windup", &"sfx_laser_charge", &"sfx_laser_fire",
	&"sfx_mortar_whistle", &"sfx_mortar_blast", &"sfx_enemy_alert", &"sfx_boss_phase",
	&"sfx_perfect_dodge", &"sfx_perfect_cast", &"sfx_special_ready", &"sfx_special_fire",
	&"sfx_graze", &"sfx_orb_pickup", &"sfx_dash_ready", &"sfx_rank_up", &"sfx_room_rank",
	&"sfx_pillar_break", &"sfx_reaction", &"sfx_vent_ignite",
]

const _EVT_THROTTLED: StringName = &"_test_fp_throttled"
const _EVT_FREE: StringName = &"_test_fp_free"
const _EVT_JITTER: StringName = &"_test_fp_jitter"


class _AudioSpy extends RefCounted:
	var played: Array[StringName] = []
	var known: Array[StringName] = []

	func has_event(event_name: StringName) -> bool:
		return known.has(event_name)

	func play_event(event_name: StringName) -> void:
		played.append(event_name)


func _make(interval: float, jitter: float = 0.0, vol: float = 0.0) -> AudioEventData:
	var d := AudioEventData.new()
	d.bus = &"SFX"
	d.priority = 0
	d.min_interval_sec = interval
	d.pitch_jitter = jitter
	d.volume_db = vol
	return d


func after_test() -> void:
	for e: StringName in [_EVT_THROTTLED, _EVT_FREE, _EVT_JITTER]:
		AudioSystem._validated_events.erase(e)
		AudioSystem._last_play_ms.erase(e)
	for p: AudioStreamPlayer in AudioSystem._sfx_pool:
		p.stop()
		p.stream = null
		p.pitch_scale = 1.0
		p.volume_db = 0.0
	Sfx.audio_override = null


func test_fast_pace_cues_all_registered_with_streams() -> void:
	var registry: AudioEventRegistry = load("res://assets/data/audio_event_registry.tres")
	for e: StringName in NEW_CUES:
		assert_bool(registry.events.has(e)).override_failure_message("missing %s" % e).is_true()
		var d: AudioEventData = registry.events[e]
		assert_object(d.stream).override_failure_message("no stream for %s" % e).is_not_null()
		assert_str(String(d.bus)).is_equal("SFX")


func test_fast_pace_busy_cues_are_throttled() -> void:
	var registry: AudioEventRegistry = load("res://assets/data/audio_event_registry.tres")
	for e: StringName in [&"sfx_bullet_fire", &"sfx_graze", &"sfx_orb_pickup"]:
		var d: AudioEventData = registry.events[e]
		assert_float(d.min_interval_sec).is_greater(0.0)


func test_is_throttled_second_call_inside_window_is_dropped() -> void:
	var d := _make(10.0)
	assert_bool(AudioSystem._is_throttled(_EVT_THROTTLED, d)).is_false()
	assert_bool(AudioSystem._is_throttled(_EVT_THROTTLED, d)).is_true()


func test_is_throttled_zero_interval_never_throttles() -> void:
	var d := _make(0.0)
	for i: int in 5:
		assert_bool(AudioSystem._is_throttled(_EVT_FREE, d)).is_false()


func test_play_event_applies_jitter_and_volume_to_pool_player() -> void:
	AudioSystem.set_rng_seed(1234)
	var d := _make(0.0, 0.2, -6.0)
	d.stream = AudioStreamGenerator.new()
	AudioSystem._validated_events[_EVT_JITTER] = d
	AudioSystem.play_event(_EVT_JITTER)
	var found: AudioStreamPlayer = null
	for p: AudioStreamPlayer in AudioSystem._sfx_pool:
		if p.stream == d.stream:
			found = p
	assert_object(found).is_not_null()
	assert_float(found.pitch_scale).is_between(0.8, 1.2)
	assert_float(found.volume_db).is_equal(-6.0)


func test_play_event_without_jitter_keeps_pitch_one() -> void:
	var d := _make(0.0, 0.0, 0.0)
	d.stream = AudioStreamGenerator.new()
	AudioSystem._validated_events[_EVT_JITTER] = d
	AudioSystem._sfx_pool[0].pitch_scale = 1.7
	AudioSystem.play_event(_EVT_JITTER)
	for p: AudioStreamPlayer in AudioSystem._sfx_pool:
		if p.stream == d.stream:
			assert_float(p.pitch_scale).is_equal(1.0)


func test_sfx_play_routes_known_event_to_audio() -> void:
	var spy := _AudioSpy.new()
	spy.known = [&"sfx_graze"]
	Sfx.audio_override = spy
	Sfx.play(&"sfx_graze")
	assert_array(spy.played).contains_exactly([&"sfx_graze"])


func test_sfx_play_unknown_event_is_noop() -> void:
	var spy := _AudioSpy.new()
	Sfx.audio_override = spy
	Sfx.play(&"sfx_does_not_exist")
	assert_array(spy.played).is_empty()
