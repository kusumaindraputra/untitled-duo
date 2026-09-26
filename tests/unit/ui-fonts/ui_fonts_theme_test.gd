## ui_fonts_theme_test.gd — pixel font and body font in the project theme (ADR-0035).
##
## Coverage:
##   F2-01: the theme's default font is the pixel font, also used as the fallback font
##   F2-02: BodyLabel and RichTextLabel use the body font; BodyLabel is a Label variation
##   F2-03: the pixel font falls back to the body font for glyphs it lacks
##   F2-04: long-prose labels opt into the body font through UIFeel.BODY_TEXT
##   F7-03: Settings key and pad buttons share one column each at 130 % text size
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const THEME_PATH: String = "res://assets/ui/game_theme.tres"
const PIXEL_FONT_PATH: String = "res://assets/ui/fonts/pixel_font.tres"
const BODY_FONT_PATH: String = "res://assets/ui/fonts/AtkinsonHyperlegible-Regular.ttf"
const TEST_PATH: String = "user://test_ui_fonts_settings.cfg"


func _theme() -> Theme:
	return load(THEME_PATH) as Theme


# ── F2-01 ─────────────────────────────────────────────────────────────────────

func test_theme_default_font_is_pixel_font() -> void:
	var theme: Theme = _theme()

	assert_str(theme.default_font.resource_path).is_equal(PIXEL_FONT_PATH)
	assert_str(str(ProjectSettings.get_setting("gui/theme/custom_font"))).is_equal(PIXEL_FONT_PATH)


# ── F2-02 ─────────────────────────────────────────────────────────────────────

func test_body_label_and_rich_text_use_body_font() -> void:
	var theme: Theme = _theme()

	assert_str(String(theme.get_type_variation_base(UIFeel.BODY_TEXT))).is_equal("Label")
	assert_str(theme.get_font(&"font", UIFeel.BODY_TEXT).resource_path).is_equal(BODY_FONT_PATH)
	assert_str(theme.get_font(&"normal_font", &"RichTextLabel").resource_path).is_equal(BODY_FONT_PATH)


# ── F2-03 ─────────────────────────────────────────────────────────────────────

func test_pixel_font_falls_back_to_body_font() -> void:
	var pixel := load(PIXEL_FONT_PATH) as FontVariation

	assert_int(pixel.fallbacks.size()).is_equal(1)
	assert_str(pixel.fallbacks[0].resource_path).is_equal(BODY_FONT_PATH)


# ── F2-04 ─────────────────────────────────────────────────────────────────────

func test_memory_modal_body_uses_body_text_variation() -> void:
	var modal := MemoryFragmentModal.new()
	modal.setup(&"")
	add_child(modal)
	modal.set_process(false)

	assert_str(String(modal._body_label.theme_type_variation)).is_equal(String(UIFeel.BODY_TEXT))
	remove_child(modal)
	modal.free()
	get_tree().paused = false


# ── F7-03 ─────────────────────────────────────────────────────────────────────

func test_settings_control_columns_line_up_at_largest_text_size() -> void:
	var panel := SettingsPanel.new()
	panel.settings = GameSettings.new()
	panel.save_path = TEST_PATH
	add_child(panel)
	var big: float = GameSettings.TEXT_SCALES[GameSettings.TEXT_SCALES.size() - 1]
	UIFeel.apply_text_scale_tree(panel, big)
	await await_idle_frame()
	await await_idle_frame()

	var key_x: Array[float] = []
	for b: Button in panel._key_buttons.values():
		key_x.append(b.global_position.x)
	var pad_x: Array[float] = []
	for b: Button in panel._pad_buttons.values():
		pad_x.append(b.global_position.x)
	assert_int(key_x.size()).is_greater(1)
	for x: float in key_x:
		assert_float(x).is_equal_approx(key_x[0], 0.5)
	for x: float in pad_x:
		assert_float(x).is_equal_approx(pad_x[0], 0.5)
	remove_child(panel)
	panel.free()
