## audio_muffle_test.gd — low-pass muffle on pause and critical HP (ADR-0044).
##
## Coverage:
##   AudioFilterTuning.target_cutoff() — the darker source wins.
##   Filter install — Music/SFX/AMB carry one shared low-pass, UI stays dry, idempotent.
##   Engage / release — pause and DESPERATE zone move the cutoff and bypass it when open.
##   Wiring — GameStateManager pause signals and HealthAndDamage zone signal reach AudioSystem.
##
## AudioSystem is an Autoload — _ready() fires before tests run. Each test swaps in an
## instant (0 s) tuning so no assertion waits on a tween.
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite

const TUNING_PATH: String = "res://assets/data/audio_filter_tuning.tres"

var _saved_tuning: AudioFilterTuning = null


func before_test() -> void:
	_saved_tuning = AudioSystem.filter_tuning
	AudioSystem.filter_tuning = _instant_tuning()
	AudioSystem.clear_muffle()


func after_test() -> void:
	AudioSystem.filter_tuning = _instant_tuning()
	AudioSystem.clear_muffle()
	AudioSystem.filter_tuning = _saved_tuning


## Copy of the shipped tuning with zero sweep time, so cutoffs land immediately.
func _instant_tuning() -> AudioFilterTuning:
	var t: AudioFilterTuning = (load(TUNING_PATH) as AudioFilterTuning).duplicate() as AudioFilterTuning
	t.engage_sec = 0.0
	t.release_sec = 0.0
	return t


func _muffle_count(bus_name: StringName) -> int:
	var idx: int = AudioServer.get_bus_index(bus_name)
	var count: int = 0
	for slot: int in range(AudioServer.get_bus_effect_count(idx)):
		var effect: AudioEffect = AudioServer.get_bus_effect(idx, slot)
		if effect is AudioEffectLowPassFilter and effect.resource_name == AudioSystem.MUFFLE_EFFECT_NAME:
			count += 1
	return count


# ── Tuning resource ──────────────────────────────────────────────────────────

func test_tuning_resource_loads_with_sane_ordering() -> void:
	var t: AudioFilterTuning = load(TUNING_PATH) as AudioFilterTuning
	assert_object(t).is_not_null()
	assert_bool(t.enabled).is_true()
	# Pause is the heavier muffle; critical must stay readable in combat.
	assert_float(t.pause_cutoff_hz).is_less(t.critical_cutoff_hz)
	assert_float(t.critical_cutoff_hz).is_less(t.open_cutoff_hz)
	assert_bool(t.buses.has(&"UI")).is_false()


func test_target_cutoff_no_source_is_open() -> void:
	var t: AudioFilterTuning = _instant_tuning()
	assert_float(t.target_cutoff(false, false)).is_equal(t.open_cutoff_hz)


func test_target_cutoff_paused_uses_pause_cutoff() -> void:
	var t: AudioFilterTuning = _instant_tuning()
	assert_float(t.target_cutoff(true, false)).is_equal(t.pause_cutoff_hz)


func test_target_cutoff_critical_uses_critical_cutoff() -> void:
	var t: AudioFilterTuning = _instant_tuning()
	assert_float(t.target_cutoff(false, true)).is_equal(t.critical_cutoff_hz)


func test_target_cutoff_both_sources_darker_wins() -> void:
	var t: AudioFilterTuning = _instant_tuning()
	t.pause_cutoff_hz = 900.0
	t.critical_cutoff_hz = 400.0
	assert_float(t.target_cutoff(true, true)).is_equal(400.0)


# ── Filter install ───────────────────────────────────────────────────────────

func test_filter_installed_on_music_sfx_amb_not_ui() -> void:
	assert_int(_muffle_count(&"Music")).is_equal(1)
	assert_int(_muffle_count(&"SFX")).is_equal(1)
	assert_int(_muffle_count(&"AMB")).is_equal(1)
	assert_int(_muffle_count(&"UI")).is_equal(0)


func test_install_twice_does_not_stack_filters() -> void:
	AudioSystem._install_lowpass()
	assert_int(_muffle_count(&"Music")).is_equal(1)
	assert_int(_muffle_count(&"SFX")).is_equal(1)


func test_filter_bypassed_when_clear() -> void:
	assert_float(AudioSystem.get_muffle_cutoff()).is_equal(AudioSystem.filter_tuning.open_cutoff_hz)
	assert_bool(AudioSystem.is_muffle_engaged()).is_false()


# ── Engage / release ─────────────────────────────────────────────────────────

func test_pause_engages_pause_cutoff() -> void:
	AudioSystem.set_muffle_paused(true)
	assert_float(AudioSystem.get_muffle_cutoff()).is_equal(AudioSystem.filter_tuning.pause_cutoff_hz)
	assert_bool(AudioSystem.is_muffle_engaged()).is_true()


func test_resume_releases_and_bypasses() -> void:
	AudioSystem.set_muffle_paused(true)
	AudioSystem.set_muffle_paused(false)
	assert_float(AudioSystem.get_muffle_cutoff()).is_equal(AudioSystem.filter_tuning.open_cutoff_hz)
	assert_bool(AudioSystem.is_muffle_engaged()).is_false()


func test_desperate_zone_engages_critical_cutoff() -> void:
	AudioSystem._on_hp_zone_changed(GameEnums.HPZone.DESPERATE)
	assert_float(AudioSystem.get_muffle_cutoff()).is_equal(AudioSystem.filter_tuning.critical_cutoff_hz)
	assert_bool(AudioSystem.is_muffle_engaged()).is_true()


func test_recovery_to_careful_releases_critical() -> void:
	AudioSystem._on_hp_zone_changed(GameEnums.HPZone.DESPERATE)
	AudioSystem._on_hp_zone_changed(GameEnums.HPZone.CAREFUL)
	assert_bool(AudioSystem.is_muffle_engaged()).is_false()


func test_pause_while_critical_goes_darker_then_back_to_critical() -> void:
	AudioSystem.set_muffle_critical(true)
	AudioSystem.set_muffle_paused(true)
	assert_float(AudioSystem.get_muffle_cutoff()).is_equal(AudioSystem.filter_tuning.pause_cutoff_hz)
	AudioSystem.set_muffle_paused(false)
	assert_float(AudioSystem.get_muffle_cutoff()).is_equal(AudioSystem.filter_tuning.critical_cutoff_hz)


func test_clear_muffle_drops_both_sources() -> void:
	AudioSystem.set_muffle_critical(true)
	AudioSystem.set_muffle_paused(true)
	AudioSystem.clear_muffle()
	assert_bool(AudioSystem.is_muffle_engaged()).is_false()


func test_disabled_tuning_never_engages() -> void:
	AudioSystem.filter_tuning.enabled = false
	AudioSystem.set_muffle_paused(true)
	AudioSystem.set_muffle_critical(true)
	assert_bool(AudioSystem.is_muffle_engaged()).is_false()


func test_timed_sweep_heads_to_target_without_snapping() -> void:
	AudioSystem.filter_tuning.engage_sec = 0.5
	AudioSystem.set_muffle_paused(true)
	# The tween has not advanced a frame yet: target is set, cutoff has not jumped.
	assert_float(AudioSystem.get_muffle_target()).is_equal(AudioSystem.filter_tuning.pause_cutoff_hz)
	assert_float(AudioSystem.get_muffle_cutoff()).is_greater(AudioSystem.filter_tuning.pause_cutoff_hz)


# ── Wiring ───────────────────────────────────────────────────────────────────

func test_game_paused_and_resumed_signals_drive_muffle() -> void:
	GameStateManager.game_paused.emit()
	assert_bool(AudioSystem.is_muffle_engaged()).is_true()
	GameStateManager.game_resumed.emit()
	assert_bool(AudioSystem.is_muffle_engaged()).is_false()


func test_hp_zone_signal_connected() -> void:
	assert_bool(HealthAndDamage.player_hp_zone_changed.is_connected(AudioSystem._on_hp_zone_changed)).is_true()
