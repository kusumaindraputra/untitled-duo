## audio_system_bus_test.gd — Unit tests for AudioSystem bus setup (ADR-0012).
##
## Coverage:
##   1. Music bus exists in AudioServer after _ready()
##   2. SFX bus exists in AudioServer after _ready()
##   3. UI bus exists in AudioServer after _ready()
##   4. AMB bus exists in AudioServer after _ready()
##   5. play_event() method exists on AudioSystem
##   6. play_ambient() and stop_ambient() stubs exist (Story 005)
##
## AudioSystem is Autoload #5 — _ready() fires before tests run.
## Buses are verified via AudioServer.get_bus_index() — returns -1 if absent.
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite


# ── Bus existence ─────────────────────────────────────────────────────────────

func test_music_bus_exists() -> void:
	assert_int(AudioServer.get_bus_index(&"Music")).is_not_equal(-1)


func test_sfx_bus_exists() -> void:
	assert_int(AudioServer.get_bus_index(&"SFX")).is_not_equal(-1)


func test_ui_bus_exists() -> void:
	assert_int(AudioServer.get_bus_index(&"UI")).is_not_equal(-1)


func test_amb_bus_exists() -> void:
	assert_int(AudioServer.get_bus_index(&"AMB")).is_not_equal(-1)


# ── Public API surface ────────────────────────────────────────────────────────

func test_play_event_method_exists() -> void:
	assert_bool(AudioSystem.has_method(&"play_event")).is_true()


func test_play_ambient_method_exists() -> void:
	assert_bool(AudioSystem.has_method(&"play_ambient")).is_true()


func test_stop_ambient_method_exists() -> void:
	assert_bool(AudioSystem.has_method(&"stop_ambient")).is_true()
