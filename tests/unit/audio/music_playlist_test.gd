## music_playlist_test.gd — per-floor combat, title and ending music (ADR-0049).
##
## Coverage:
##   MusicPlaylist.combat_cue_for_floor() — floor 1..N mapping, clamping, empty list.
##   Shipped playlist — three distinct floor loops, every cue registered, files on disk.
##   AudioSystem — set_music_floor() + reset_combat_cue() pick the floor loop, with a
##     mus_combat_floor fallback; _load_music_cues() fills MAIN_MENU and END_VICTORY;
##     play_menu_music() reaches MAIN_MENU and clears the ADR-0044 muffle;
##     END_* cues play once while loops loop.
##
## AudioSystem is an Autoload — _ready() fires before tests run. Each test swaps in its
## own playlist and dummy streams, and restores the originals afterwards.
## "playing == true" is not asserted (unreliable headless); stream assignment is the proxy.
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite

const PLAYLIST_PATH: String = "res://assets/data/music_playlist.tres"
const REGISTRY_PATH: String = "res://assets/data/audio_event_registry.tres"
const _F1: StringName = &"_test_mpl_floor1"
const _F2: StringName = &"_test_mpl_floor2"
const _F3: StringName = &"_test_mpl_floor3"
const _MENU: StringName = &"_test_mpl_menu"
const _END: StringName = &"_test_mpl_end"

var _saved_playlist: MusicPlaylist = null
var _saved_floor: int = 1
var _saved_cues: Dictionary = {}
var _saved_state: int = 0
var _streams: Dictionary = {}


func before_test() -> void:
	_saved_playlist = AudioSystem.playlist
	_saved_floor = AudioSystem.get_music_floor()
	_saved_cues = AudioSystem._music_cues.duplicate()
	_saved_state = AudioSystem._music_state
	_streams.clear()
	for key: StringName in [_F1, _F2, _F3, _MENU, _END]:
		var stream := AudioStreamGenerator.new()
		_streams[key] = stream
		var data := AudioEventData.new()
		data.stream = stream
		data.bus = &"Music"
		AudioSystem._validated_events[key] = data
	AudioSystem.playlist = _test_playlist()


func after_test() -> void:
	if AudioSystem._active_tween != null:
		AudioSystem._active_tween.kill()
		AudioSystem._active_tween = null
	for player: AudioStreamPlayer in AudioSystem._music_players:
		player.stop()
		player.stream = null
		player.volume_db = 0.0
	for key: StringName in [_F1, _F2, _F3, _MENU, _END]:
		AudioSystem._validated_events.erase(key)
	AudioSystem.playlist = _saved_playlist
	AudioSystem.set_music_floor(_saved_floor)
	AudioSystem._music_cues.clear()
	for k: int in _saved_cues:
		AudioSystem._music_cues[k] = _saved_cues[k]
	AudioSystem._music_state = _saved_state as AudioSystem.MusicState
	AudioSystem.clear_muffle()


func _test_playlist() -> MusicPlaylist:
	var p := MusicPlaylist.new()
	p.menu_cue = _MENU
	p.preparation_cue = &""
	p.floor_combat_cues = [_F1, _F2, _F3]
	p.victory_cue = _END
	p.defeat_cue = &""
	return p


# ── MusicPlaylist ────────────────────────────────────────────────────────────

func test_combat_cue_for_floor_maps_one_based_floors() -> void:
	var p: MusicPlaylist = _test_playlist()
	assert_str(String(p.combat_cue_for_floor(1))).is_equal(String(_F1))
	assert_str(String(p.combat_cue_for_floor(2))).is_equal(String(_F2))
	assert_str(String(p.combat_cue_for_floor(3))).is_equal(String(_F3))


func test_combat_cue_for_floor_clamps_out_of_range_floors() -> void:
	var p: MusicPlaylist = _test_playlist()
	assert_str(String(p.combat_cue_for_floor(0))).is_equal(String(_F1))
	assert_str(String(p.combat_cue_for_floor(-4))).is_equal(String(_F1))
	assert_str(String(p.combat_cue_for_floor(9))).is_equal(String(_F3))


func test_combat_cue_for_floor_empty_list_returns_empty_name() -> void:
	var p := MusicPlaylist.new()
	p.floor_combat_cues = []
	assert_str(String(p.combat_cue_for_floor(1))).is_empty()


# ── Shipped data ─────────────────────────────────────────────────────────────

func test_shipped_playlist_has_three_distinct_floor_loops() -> void:
	var p: MusicPlaylist = load(PLAYLIST_PATH) as MusicPlaylist
	assert_object(p).is_not_null()
	assert_int(p.floor_combat_cues.size()).is_equal(3)
	assert_bool(p.floor_combat_cues[0] != p.floor_combat_cues[1]).is_true()
	assert_bool(p.floor_combat_cues[1] != p.floor_combat_cues[2]).is_true()
	assert_bool(p.floor_combat_cues[0] != p.floor_combat_cues[2]).is_true()


func test_shipped_playlist_cues_are_all_registered_with_streams() -> void:
	var p: MusicPlaylist = load(PLAYLIST_PATH) as MusicPlaylist
	var registry: AudioEventRegistry = load(REGISTRY_PATH) as AudioEventRegistry
	var names: Array[StringName] = [p.menu_cue, p.preparation_cue, p.victory_cue, p.defeat_cue]
	names.append_array(p.floor_combat_cues)
	for event_name: StringName in names:
		assert_bool(registry.events.has(event_name)).override_failure_message(
			"playlist cue '%s' is not in the audio registry" % event_name).is_true()
		var data: AudioEventData = registry.events[event_name] as AudioEventData
		assert_object(data.stream).override_failure_message(
			"playlist cue '%s' has no stream" % event_name).is_not_null()


func test_shipped_music_cues_route_to_music_bus() -> void:
	var p: MusicPlaylist = load(PLAYLIST_PATH) as MusicPlaylist
	var registry: AudioEventRegistry = load(REGISTRY_PATH) as AudioEventRegistry
	var loops: Array[StringName] = [p.menu_cue, p.victory_cue]
	loops.append_array(p.floor_combat_cues)
	for event_name: StringName in loops:
		var data: AudioEventData = registry.events[event_name] as AudioEventData
		assert_str(String(data.bus)).is_equal("Music")


# ── AudioSystem wiring ───────────────────────────────────────────────────────

func test_reset_combat_cue_uses_current_floor_loop() -> void:
	for floor_number: int in [1, 2, 3]:
		AudioSystem.set_music_floor(floor_number)
		AudioSystem.reset_combat_cue()
		var expected: AudioStream = _streams[[_F1, _F2, _F3][floor_number - 1]]
		assert_object(AudioSystem._get_cue_for_state(AudioSystem.MusicState.COMBAT)).is_same(expected)


func test_reset_combat_cue_replaces_a_boss_override() -> void:
	AudioSystem.set_music_floor(2)
	AudioSystem.override_combat_cue(_END)
	AudioSystem.reset_combat_cue()
	assert_object(AudioSystem._get_cue_for_state(AudioSystem.MusicState.COMBAT)).is_same(_streams[_F2])


func test_set_music_floor_clamps_below_one() -> void:
	AudioSystem.set_music_floor(0)
	assert_int(AudioSystem.get_music_floor()).is_equal(1)


func test_reset_combat_cue_falls_back_to_mus_combat_floor() -> void:
	var p: MusicPlaylist = _test_playlist()
	p.floor_combat_cues = [&"_test_mpl_not_registered"]
	AudioSystem.playlist = p
	var fallback_stream := AudioStreamGenerator.new()
	var had_default: bool = AudioSystem._validated_events.has(&"mus_combat_floor")
	var saved_default: AudioEventData = AudioSystem._validated_events.get(&"mus_combat_floor")
	var data := AudioEventData.new()
	data.stream = fallback_stream
	data.bus = &"Music"
	AudioSystem._validated_events[&"mus_combat_floor"] = data
	AudioSystem.reset_combat_cue()
	var got: AudioStream = AudioSystem._get_cue_for_state(AudioSystem.MusicState.COMBAT)
	if had_default:
		AudioSystem._validated_events[&"mus_combat_floor"] = saved_default
	else:
		AudioSystem._validated_events.erase(&"mus_combat_floor")
	assert_object(got).is_same(fallback_stream)


func test_load_music_cues_fills_menu_floor_and_victory_from_playlist() -> void:
	AudioSystem.set_music_floor(3)
	AudioSystem._music_cues.clear()
	AudioSystem._load_music_cues()
	assert_object(AudioSystem._get_cue_for_state(AudioSystem.MusicState.MAIN_MENU)).is_same(_streams[_MENU])
	assert_object(AudioSystem._get_cue_for_state(AudioSystem.MusicState.COMBAT)).is_same(_streams[_F3])
	assert_object(AudioSystem._get_cue_for_state(AudioSystem.MusicState.END_VICTORY)).is_same(_streams[_END])
	# Empty playlist entries leave their state silent, and DYING never gets a cue.
	assert_object(AudioSystem._get_cue_for_state(AudioSystem.MusicState.PREPARATION)).is_null()
	assert_object(AudioSystem._get_cue_for_state(AudioSystem.MusicState.DYING)).is_null()


func test_play_menu_music_moves_to_main_menu_and_clears_muffle() -> void:
	AudioSystem._load_music_cues()
	AudioSystem._music_state = AudioSystem.MusicState.COMBAT
	AudioSystem.set_muffle_paused(true)
	AudioSystem.play_menu_music()
	assert_int(AudioSystem._music_state).is_equal(AudioSystem.MusicState.MAIN_MENU)
	var active: AudioStreamPlayer = AudioSystem._music_players[AudioSystem._active_music_idx]
	assert_object(active.stream).is_same(_streams[_MENU])
	assert_bool(AudioSystem._muffle_paused).is_false()


func test_play_menu_music_ends_an_ending_cue_early() -> void:
	AudioSystem._load_music_cues()
	AudioSystem._music_state = AudioSystem.MusicState.END_VICTORY
	AudioSystem.play_menu_music()
	assert_int(AudioSystem._music_state).is_equal(AudioSystem.MusicState.MAIN_MENU)


func test_end_cue_plays_once_while_loops_loop() -> void:
	var ending: AudioStreamMP3 = (load("res://assets/audio/music/mus_ending.mp3") as AudioStreamMP3)
	assert_object(ending).is_not_null()
	AudioSystem._music_cues[AudioSystem.MusicState.END_VICTORY as int] = ending
	AudioSystem._music_cues[AudioSystem.MusicState.COMBAT as int] = ending
	AudioSystem._crossfade_to(AudioSystem.MusicState.COMBAT, 0.0)
	assert_bool(ending.loop).is_true()
	AudioSystem._crossfade_to(AudioSystem.MusicState.END_VICTORY, 0.0)
	assert_bool(ending.loop).is_false()
