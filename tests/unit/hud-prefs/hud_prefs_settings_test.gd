## hud_prefs_settings_test.gd — HUD options in GameSettings and SettingsPanel (ADR-0046).
##
## Coverage:
##   HP-01: defaults are 100 % HUD, full card opacity, timer off
##   HP-02: save/load round trip keeps the three HUD options
##   HP-03: out-of-range values are clamped on load
##   HP-04: a v2 file migrates to v3 and keeps its other values, HUD options at defaults
##   HP-05: static helpers follow `current` and fall back when nothing is loaded
##   HP-06: SettingsPanel saves HUD size, opacity and timer, and refreshes the live HUD
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const TEST_PATH: String = "user://test_hud_prefs.cfg"

var _saved_current: GameSettings = null


func before_test() -> void:
	_saved_current = GameSettings.current


func after_test() -> void:
	GameSettings.current = _saved_current
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func test_hud_options_defaults() -> void:
	var s := GameSettings.new()

	assert_float(s.hud_scale_value()).is_equal(1.0)
	assert_float(s.hud_card_opacity).is_equal(1.0)
	assert_bool(s.show_run_timer).is_false()


func test_hud_options_round_trip() -> void:
	var s := GameSettings.new()
	s.hud_scale_idx = 3
	s.hud_card_opacity = 0.5
	s.show_run_timer = true
	s.save_to(TEST_PATH)

	var loaded: GameSettings = GameSettings.load_from(TEST_PATH)

	assert_int(loaded.hud_scale_idx).is_equal(3)
	assert_float(loaded.hud_card_opacity).is_equal_approx(0.5, 0.0001)
	assert_bool(loaded.show_run_timer).is_true()


func test_hud_options_bad_values_clamped() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "version", GameSettings.SETTINGS_VERSION)
	cfg.set_value("game", "hud_scale_idx", 42)
	cfg.set_value("game", "hud_card_opacity", 0.0)
	cfg.save(TEST_PATH)

	var loaded: GameSettings = GameSettings.load_from(TEST_PATH)

	assert_int(loaded.hud_scale_idx).is_equal(GameSettings.HUD_SCALES.size() - 1)
	assert_float(loaded.hud_card_opacity).is_equal(GameSettings.HUD_CARD_OPACITY_MIN)


func test_v2_file_migrates_with_hud_defaults() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "version", 2)
	cfg.set_value("game", "text_scale_idx", 2)
	cfg.set_value("game", "rumble", 0.4)
	cfg.save(TEST_PATH)

	var loaded: GameSettings = GameSettings.load_from(TEST_PATH)

	assert_int(GameSettings.migrate(cfg, 2)).is_equal(GameSettings.SETTINGS_VERSION)
	assert_int(loaded.text_scale_idx).is_equal(2)
	assert_float(loaded.rumble).is_equal_approx(0.4, 0.0001)
	assert_int(loaded.hud_scale_idx).is_equal(GameSettings.HUD_SCALE_DEFAULT_IDX)
	assert_bool(loaded.show_run_timer).is_false()


func test_static_helpers_follow_current() -> void:
	GameSettings.current = null
	assert_float(GameSettings.hud_scale()).is_equal(1.0)
	assert_float(GameSettings.hud_card_alpha()).is_equal(1.0)
	assert_bool(GameSettings.run_timer_on()).is_false()

	var s := GameSettings.new()
	s.hud_scale_idx = 0
	s.hud_card_opacity = 0.6
	s.show_run_timer = true
	GameSettings.current = s

	assert_float(GameSettings.hud_scale()).is_equal(GameSettings.HUD_SCALES[0])
	assert_float(GameSettings.hud_card_alpha()).is_equal_approx(0.6, 0.0001)
	assert_bool(GameSettings.run_timer_on()).is_true()


func test_settings_panel_saves_hud_options_and_refreshes_hud() -> void:
	var s := GameSettings.new()
	GameSettings.current = s
	var hud := CombatHUD.new()
	add_child(hud)
	hud.set_process(false)
	var panel := SettingsPanel.new()
	panel.settings = s
	panel.save_path = TEST_PATH
	add_child(panel)

	panel._on_hud_scale_selected(2)
	var timer_check: CheckButton = panel.find_child("RunTimer", true, false) as CheckButton
	timer_check.button_pressed = true

	var loaded: GameSettings = GameSettings.load_from(TEST_PATH)
	assert_int(loaded.hud_scale_idx).is_equal(2)
	assert_bool(loaded.show_run_timer).is_true()
	assert_float(hud.get_hud_scale()).is_equal_approx(GameSettings.HUD_SCALES[2], 0.0001)
	remove_child(panel)
	panel.free()
	remove_child(hud)
	hud.free()
