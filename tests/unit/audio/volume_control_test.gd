## volume_control_test.gd — Story 007 acceptance criteria tests.
##
## Coverage (AC-AS-17, AC-AS-18, AC-AS-19, AC-AS-20, AC-AS-30, AC-AS-31, AC-AS-37, AC-AS-38):
##   All volume setters / getters and the _slider_to_db() pure function.
##
## AudioSystem is an Autoload — _ready() fires before tests run.
## All assertions use AudioServer.get_bus_volume_db() directly (not getters) where possible,
## plus getter round-trip tests (AC-AS-20) to verify getters read AudioServer directly.
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite


func after_test() -> void:
	# Reset all buses to safe defaults after each test to prevent state leak.
	AudioSystem.set_music_volume(-6.0)   # NOT 0.0 — Music upper bound is -3.0 dB
	AudioSystem.set_sfx_volume(0.0)
	AudioSystem.set_ui_volume(0.0)
	AudioSystem.set_amb_volume(-10.0)    # AMB upper bound is -10.0 dB
	AudioSystem.set_master_volume(0.0)


# ── AC-AS-17: In-range set_music_volume ──────────────────────────────────────

func test_set_music_volume_in_range_sets_bus() -> void:
	AudioSystem.set_music_volume(-20.0)
	var music_idx: int = AudioServer.get_bus_index(&"Music")
	var actual: float = AudioServer.get_bus_volume_db(music_idx)
	assert_float(actual).is_equal_approx(-20.0, 0.001)


# ── AC-AS-18: Lower-bound clamp (SFX) ────────────────────────────────────────

func test_set_sfx_volume_below_min_clamps_to_minus80() -> void:
	AudioSystem.set_sfx_volume(-200.0)
	var sfx_idx: int = AudioServer.get_bus_index(&"SFX")
	assert_float(AudioServer.get_bus_volume_db(sfx_idx)).is_equal_approx(-80.0, 0.001)


# ── AC-AS-19: Upper-bound clamp (Master) ─────────────────────────────────────

func test_set_master_volume_above_max_clamps_to_zero() -> void:
	AudioSystem.set_master_volume(10.0)
	var master_idx: int = AudioServer.get_bus_index(&"Master")
	assert_float(AudioServer.get_bus_volume_db(master_idx)).is_equal_approx(0.0, 0.001)


# ── AC-AS-30: Lower-bound clamp (UI + AMB) ───────────────────────────────────

func test_set_ui_volume_below_min_clamps_to_minus80() -> void:
	AudioSystem.set_ui_volume(-200.0)
	var ui_idx: int = AudioServer.get_bus_index(&"UI")
	assert_float(AudioServer.get_bus_volume_db(ui_idx)).is_equal_approx(-80.0, 0.001)


func test_set_amb_volume_below_min_clamps_to_minus80() -> void:
	AudioSystem.set_amb_volume(-200.0)
	var amb_idx: int = AudioServer.get_bus_index(&"AMB")
	assert_float(AudioServer.get_bus_volume_db(amb_idx)).is_equal_approx(-80.0, 0.001)


# ── AC-AS-37: Music upper bound at -3.0 dB ───────────────────────────────────

func test_set_music_volume_at_upper_bound_allowed() -> void:
	AudioSystem.set_music_volume(-3.0)
	var music_idx: int = AudioServer.get_bus_index(&"Music")
	assert_float(AudioServer.get_bus_volume_db(music_idx)).is_equal_approx(-3.0, 0.001)


func test_set_music_volume_above_upper_bound_clamped() -> void:
	AudioSystem.set_music_volume(-1.0)
	var music_idx: int = AudioServer.get_bus_index(&"Music")
	assert_float(AudioServer.get_bus_volume_db(music_idx)).is_equal_approx(-3.0, 0.001)


func test_set_music_volume_well_above_upper_bound_clamped_to_minus3() -> void:
	AudioSystem.set_music_volume(10.0)
	var music_idx: int = AudioServer.get_bus_index(&"Music")
	assert_float(AudioServer.get_bus_volume_db(music_idx)).is_equal_approx(-3.0, 0.001)


# ── AC-AS-38: AMB upper bound at -10.0 dB ────────────────────────────────────

func test_set_amb_volume_at_upper_bound_allowed() -> void:
	AudioSystem.set_amb_volume(-10.0)
	var amb_idx: int = AudioServer.get_bus_index(&"AMB")
	assert_float(AudioServer.get_bus_volume_db(amb_idx)).is_equal_approx(-10.0, 0.001)


func test_set_amb_volume_above_upper_bound_clamped() -> void:
	AudioSystem.set_amb_volume(-5.0)
	var amb_idx: int = AudioServer.get_bus_index(&"AMB")
	assert_float(AudioServer.get_bus_volume_db(amb_idx)).is_equal_approx(-10.0, 0.001)


func test_set_amb_volume_zero_clamped_to_minus10() -> void:
	AudioSystem.set_amb_volume(0.0)
	var amb_idx: int = AudioServer.get_bus_index(&"AMB")
	assert_float(AudioServer.get_bus_volume_db(amb_idx)).is_equal_approx(-10.0, 0.001)


# ── AC-AS-20: get_music_volume() round-trip ───────────────────────────────────

func test_get_music_volume_returns_set_value() -> void:
	AudioSystem.set_music_volume(-6.0)
	assert_float(AudioSystem.get_music_volume()).is_equal_approx(-6.0, 0.001)


func test_get_music_volume_lower_boundary() -> void:
	AudioSystem.set_music_volume(-80.0)
	assert_float(AudioSystem.get_music_volume()).is_equal_approx(-80.0, 0.001)


func test_get_music_volume_out_of_range_returns_clamped() -> void:
	AudioSystem.set_music_volume(-100.0)
	assert_float(AudioSystem.get_music_volume()).is_equal_approx(-80.0, 0.001)


# ── AC-AS-31: _slider_to_db() formula ────────────────────────────────────────

func test_slider_to_db_midpoint_is_minus40() -> void:
	assert_float(AudioSystem._slider_to_db(50)).is_between(-40.01, -39.99)


func test_slider_to_db_zero_is_minus80() -> void:
	assert_float(AudioSystem._slider_to_db(0)).is_equal_approx(-80.0, 0.001)


func test_slider_to_db_hundred_is_zero() -> void:
	assert_float(AudioSystem._slider_to_db(100)).is_equal_approx(0.0, 0.001)


func test_slider_to_db_one_is_not_zero() -> void:
	# Verifies float divisor — int/int would return 0.0 for value 1, float returns -79.2
	var result: float = AudioSystem._slider_to_db(1)
	assert_float(result).is_between(-80.0, -79.0)
