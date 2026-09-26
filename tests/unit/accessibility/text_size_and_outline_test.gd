## text_size_and_outline_test.gd — Text size and high-contrast bullets (ADR-0032).
##
## Coverage:
##   AX-01: text size and bullet outline default off, round-trip through settings.cfg, clamp
##   AX-02: the static helpers follow GameSettings.current
##   AX-03: apply_text_scale scales Label and RichTextLabel sizes and scales back to 1
##   AX-04: a size set by code after scaling becomes the new unscaled size
##   AX-05: a control never scaled is left alone at scale 1
##   AX-06: the Settings panel changes and saves both options
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const TEST_PATH: String = "user://test_accessibility_settings.cfg"
const Feel = preload("res://src/ui/ui_feel.gd")

var _saved_current: GameSettings = null


func before_test() -> void:
	_saved_current = GameSettings.current


func after_test() -> void:
	GameSettings.current = _saved_current
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func test_defaults_and_round_trip() -> void:
	var s := GameSettings.new()
	assert_int(s.text_scale_idx).is_equal(0)
	assert_bool(s.bullet_outline).is_false()
	assert_float(s.text_scale_value()).is_equal(1.0)

	s.text_scale_idx = 2
	s.bullet_outline = true
	s.save_to(TEST_PATH)
	var loaded: GameSettings = GameSettings.load_from(TEST_PATH)

	assert_int(loaded.text_scale_idx).is_equal(2)
	assert_bool(loaded.bullet_outline).is_true()
	assert_float(loaded.text_scale_value()).is_equal(GameSettings.TEXT_SCALES[2])


func test_bad_text_size_is_clamped() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "text_scale_idx", 99)
	cfg.save(TEST_PATH)

	assert_int(GameSettings.load_from(TEST_PATH).text_scale_idx).is_equal(GameSettings.TEXT_SCALES.size() - 1)


func test_static_helpers_follow_current() -> void:
	GameSettings.current = null
	assert_float(GameSettings.text_scale()).is_equal(1.0)
	assert_bool(GameSettings.bullet_outline_on()).is_false()

	var s := GameSettings.new()
	s.text_scale_idx = 1
	s.bullet_outline = true
	GameSettings.current = s

	assert_float(GameSettings.text_scale()).is_equal(GameSettings.TEXT_SCALES[1])
	assert_bool(GameSettings.bullet_outline_on()).is_true()


func test_apply_text_scale_scales_and_restores() -> void:
	var l := Label.new()
	l.add_theme_font_size_override(&"font_size", 20)
	var r := RichTextLabel.new()
	r.add_theme_font_size_override(&"normal_font_size", 10)

	Feel.apply_text_scale(l, 1.3)
	Feel.apply_text_scale(r, 1.3)
	assert_int(l.get_theme_font_size(&"font_size")).is_equal(26)
	assert_int(r.get_theme_font_size(&"normal_font_size")).is_equal(13)

	Feel.apply_text_scale(l, 1.0)
	Feel.apply_text_scale(r, 1.0)
	assert_int(l.get_theme_font_size(&"font_size")).is_equal(20)
	assert_int(r.get_theme_font_size(&"normal_font_size")).is_equal(10)
	l.free()
	r.free()


func test_size_set_by_code_becomes_new_base() -> void:
	var l := Label.new()
	l.add_theme_font_size_override(&"font_size", 20)
	Feel.apply_text_scale(l, 1.3)

	l.add_theme_font_size_override(&"font_size", 30)
	Feel.apply_text_scale(l, 1.3)

	assert_int(l.get_theme_font_size(&"font_size")).is_equal(39)
	l.free()


func test_unscaled_control_left_alone_at_one() -> void:
	var l := Label.new()
	l.add_theme_font_size_override(&"font_size", 20)

	Feel.apply_text_scale(l, 1.0)

	assert_bool(l.has_meta(Feel.BASE_SIZES_META)).is_false()
	var plain := Control.new()
	assert_array(Feel.font_size_names(plain)).is_empty()
	plain.free()
	l.free()


func test_apply_tree_reaches_children() -> void:
	var box := VBoxContainer.new()
	var l := Label.new()
	l.add_theme_font_size_override(&"font_size", 20)
	box.add_child(l)

	Feel.apply_text_scale_tree(box, 1.15)

	assert_int(l.get_theme_font_size(&"font_size")).is_equal(23)
	box.free()


func test_settings_panel_saves_both_options() -> void:
	var s := GameSettings.new()
	var panel := SettingsPanel.new()
	panel.settings = s
	panel.save_path = TEST_PATH
	add_child(panel)

	panel._on_text_size_selected(1)
	var outline: CheckButton = panel.find_child("BulletOutline", true, false) as CheckButton
	outline.button_pressed = true

	var loaded: GameSettings = GameSettings.load_from(TEST_PATH)
	assert_int(loaded.text_scale_idx).is_equal(1)
	assert_bool(loaded.bullet_outline).is_true()
	# Put open screens back to normal size.
	Feel.apply_text_scale_tree(get_tree().root, 1.0)
	remove_child(panel)
	panel.free()
