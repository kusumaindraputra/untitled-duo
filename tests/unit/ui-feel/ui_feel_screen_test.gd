## ui_feel_screen_test.gd — Screen feel: sounds, fades, typewriter, reduce motion (beta plan U9).
##
## Coverage:
##   UF-01: focus ticks stay silent while new UI settles, then play
##   UF-02: typewriter reveals at TYPE_CPS, clamps to the text, and is instant with reduce motion
##   UF-03: fade_in starts transparent; with reduce motion it shows at once and makes no tween
##   UF-04: the UI cues are registered on the UI bus
##   UF-06: reduce_motion round-trips through the settings file
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const Feel = preload("res://src/ui/ui_feel.gd")
const REGISTRY: AudioEventRegistry = preload("res://assets/data/audio_event_registry.tres")
const SETTINGS_PATH: String = "user://test_ui_feel_settings.cfg"

var _saved_settings: GameSettings = null


func before_test() -> void:
	_saved_settings = GameSettings.current


func after_test() -> void:
	GameSettings.current = _saved_settings
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _reduced(on: bool) -> void:
	var s := GameSettings.new()
	s.reduce_motion = on
	GameSettings.current = s


func _key_press() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_SPACE
	e.pressed = true
	return e


# ── UF-01 ─────────────────────────────────────────────────────────────────────

func test_ui_feel_focus_silent_while_ui_settles() -> void:
	assert_bool(Feel.should_play_focus(100, 100)).is_false()
	assert_bool(Feel.should_play_focus(100 + Feel.SETTLE_FRAMES, 100)).is_false()
	assert_bool(Feel.should_play_focus(101 + Feel.SETTLE_FRAMES, 100)).is_true()


# ── UF-02 ─────────────────────────────────────────────────────────────────────

func test_ui_feel_typewriter_reveals_at_rate_and_clamps() -> void:
	assert_int(Feel.typewriter_chars(0.0, 50)).is_equal(0)
	assert_int(Feel.typewriter_chars(0.2, 50)).is_equal(int(0.2 * Feel.TYPE_CPS))
	assert_int(Feel.typewriter_chars(100.0, 50)).is_equal(50)
	assert_int(Feel.typewriter_chars(0.0, 50, true)).is_equal(50)


# ── UF-03 ─────────────────────────────────────────────────────────────────────

func test_ui_feel_fade_in_starts_transparent() -> void:
	_reduced(false)
	var c := Control.new()
	add_child(c)

	var tw: Tween = Feel.fade_in(c)

	assert_object(tw).is_not_null()
	assert_float(c.modulate.a).is_equal(0.0)
	remove_child(c)
	c.free()


func test_ui_feel_fade_in_skipped_with_reduce_motion() -> void:
	_reduced(true)
	var c := Control.new()
	add_child(c)
	c.modulate.a = 0.3

	var tw: Tween = Feel.fade_in(c)

	assert_object(tw).is_null()
	assert_float(c.modulate.a).is_equal(1.0)
	remove_child(c)
	c.free()


# ── UF-04 ─────────────────────────────────────────────────────────────────────

func test_ui_feel_cues_registered_on_ui_bus() -> void:
	for id: StringName in [Feel.EVENT_FOCUS, Feel.EVENT_CONFIRM, Feel.EVENT_BACK]:
		assert_bool(REGISTRY.events.has(id)).override_failure_message("missing %s" % id).is_true()
		var data: Resource = REGISTRY.events[id]
		assert_str(String(data.get("bus"))).is_equal("UI")
		assert_object(data.get("stream")).is_not_null()


# ── UF-06 ─────────────────────────────────────────────────────────────────────

func test_ui_feel_reduce_motion_round_trips() -> void:
	var s := GameSettings.new()
	s.reduce_motion = true
	s.save_to(SETTINGS_PATH)

	assert_bool(GameSettings.load_from(SETTINGS_PATH).reduce_motion).is_true()
