## game_settings_test.gd — Unit tests for GameSettings and SettingsPanel (ADR-0026).
##
## Coverage:
##   defaults, save/load round trip, other sections (audio) preserved, bad values clamped
##   shake_multiplier / flash_multiplier follow `current`
##   rebind replaces the keyboard key and keeps gamepad events; reset restores defaults
##   SettingsPanel swaps keys so no key is bound to two actions
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const TEST_PATH: String = "user://test_game_settings.cfg"
const ACTION_A: StringName = &"dash"
const ACTION_B: StringName = &"cast"

var _saved_current: GameSettings = null
var _saved_events: Dictionary = {}


func before_test() -> void:
	_saved_current = GameSettings.current
	for action: StringName in [ACTION_A, ACTION_B]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		_saved_events[action] = InputMap.action_get_events(action)
	_set_events(ACTION_A, KEY_SHIFT, true)
	_set_events(ACTION_B, KEY_SPACE, false)
	GameSettings._default_keys.clear()


func after_test() -> void:
	GameSettings.current = _saved_current
	GameSettings._default_keys.clear()
	for action: StringName in _saved_events:
		InputMap.action_erase_events(action)
		for ev: InputEvent in _saved_events[action]:
			InputMap.action_add_event(action, ev)
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func _set_events(action: StringName, key: Key, with_pad: bool) -> void:
	InputMap.action_erase_events(action)
	var k := InputEventKey.new()
	k.keycode = key
	InputMap.action_add_event(action, k)
	if with_pad:
		var j := InputEventJoypadButton.new()
		j.button_index = JOY_BUTTON_X
		InputMap.action_add_event(action, j)


func _key_of(action: StringName) -> Key:
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return (ev as InputEventKey).keycode
	return KEY_NONE


func test_game_settings_defaults() -> void:
	var s := GameSettings.new()
	assert_bool(s.fullscreen).is_false()
	assert_float(s.screen_shake).is_equal(1.0)
	assert_bool(s.reduce_flashes).is_false()
	assert_bool(s.reduce_motion).is_false()
	assert_that(s.window_size()).is_equal(GameSettings.RESOLUTIONS[0])


func test_game_settings_round_trip_keeps_audio_section() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_db", -6.0)
	cfg.save(TEST_PATH)
	var s := GameSettings.new()
	s.fullscreen = true
	s.resolution_idx = 2
	s.vsync = false
	s.screen_shake = 0.4
	s.reduce_flashes = true
	s.reduce_motion = true
	s.key_overrides[ACTION_A] = KEY_J
	assert_int(s.save_to(TEST_PATH)).is_equal(OK)
	var back := GameSettings.load_from(TEST_PATH)
	assert_bool(back.fullscreen).is_true()
	assert_int(back.resolution_idx).is_equal(2)
	assert_bool(back.vsync).is_false()
	assert_float(back.screen_shake).is_equal_approx(0.4, 0.001)
	assert_bool(back.reduce_flashes).is_true()
	assert_bool(back.reduce_motion).is_true()
	assert_int(back.key_overrides[ACTION_A]).is_equal(KEY_J)
	var again := ConfigFile.new()
	again.load(TEST_PATH)
	assert_float(float(again.get_value("audio", "master_db"))).is_equal(-6.0)


func test_game_settings_load_clamps_bad_values() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "resolution_idx", 99)
	cfg.set_value("game", "screen_shake", 7.0)
	cfg.set_value("keys", "not_an_action", KEY_K)
	cfg.save(TEST_PATH)
	var s := GameSettings.load_from(TEST_PATH)
	assert_int(s.resolution_idx).is_equal(GameSettings.RESOLUTIONS.size() - 1)
	assert_float(s.screen_shake).is_equal(1.0)
	assert_bool(s.key_overrides.is_empty()).is_true()


func test_game_settings_missing_file_gives_defaults() -> void:
	var s := GameSettings.load_from("user://does_not_exist_settings.cfg")
	assert_float(s.screen_shake).is_equal(1.0)


func test_game_settings_multipliers_follow_current() -> void:
	GameSettings.current = null
	assert_float(GameSettings.shake_multiplier()).is_equal(1.0)
	assert_float(GameSettings.flash_multiplier()).is_equal(1.0)
	var s := GameSettings.new()
	s.screen_shake = 0.0
	s.reduce_flashes = true
	GameSettings.current = s
	assert_float(GameSettings.shake_multiplier()).is_equal(0.0)
	assert_float(GameSettings.flash_multiplier()).is_equal(GameSettings.REDUCED_FLASH_SCALE)


func test_game_settings_rebind_keeps_gamepad_and_reset_restores() -> void:
	var s := GameSettings.new()
	assert_bool(s.rebind(ACTION_A, KEY_J)).is_true()
	assert_int(_key_of(ACTION_A)).is_equal(KEY_J)
	var pads: int = 0
	for ev: InputEvent in InputMap.action_get_events(ACTION_A):
		if ev is InputEventJoypadButton:
			pads += 1
	assert_int(pads).is_equal(1)
	s.reset_keys()
	assert_int(_key_of(ACTION_A)).is_equal(KEY_SHIFT)
	assert_bool(s.key_overrides.is_empty()).is_true()


func test_game_settings_rebind_rejects_unknown_action() -> void:
	var s := GameSettings.new()
	assert_bool(s.rebind(&"prana_place", KEY_J)).is_false()
	assert_bool(s.rebind(ACTION_A, KEY_NONE)).is_false()


func test_settings_panel_rebind_swaps_conflicting_key() -> void:
	var panel := SettingsPanel.new()
	panel.settings = GameSettings.new()
	panel.save_path = TEST_PATH
	panel.rebind_with_swap(ACTION_A, KEY_SPACE)
	assert_int(_key_of(ACTION_A)).is_equal(KEY_SPACE)
	assert_int(_key_of(ACTION_B)).is_equal(KEY_SHIFT)
	assert_str(GameSettings.action_using_key(KEY_SPACE)).is_equal(String(ACTION_A))
	panel.free()
