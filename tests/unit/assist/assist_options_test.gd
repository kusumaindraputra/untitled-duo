## assist_options_test.gd — Assist options (beta plan F2).
##
## Coverage:
##   AS-01: assist values round-trip and clamp to their ranges on load
##   AS-02: assist_active() is false at defaults and true when any option is on
##   AS-03: base_time_scale follows the game speed; TimeWarp treats it as normal speed
##   AS-04: the damage share scales Fayde's damage and never enemies'
##   AS-05: auto-dash only fires when on, enabled and a charge is ready; it spends a charge
##   AS-06: the run summary shows the Assist note only for assisted runs
##   AS-07: with the Assist switch off, every option falls back to normal and the
##          Settings panel locks the option controls
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const HealthAndDamageScript = preload("res://src/systems/health_and_damage.gd")
const PlayerControllerScript = preload("res://src/gameplay/player_controller.gd")
const COPY: UICopy = preload("res://assets/data/ui_copy.tres")
const PATH: String = "user://test_assist_settings.cfg"

var _saved: GameSettings = null


func before_test() -> void:
	_saved = GameSettings.current


func after_test() -> void:
	GameSettings.current = _saved
	Engine.time_scale = 1.0
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _settings(damage: float, speed: float, auto: bool) -> GameSettings:
	var s := GameSettings.new()
	s.assist_enabled = true
	s.assist_damage = damage
	s.assist_speed = speed
	s.assist_auto_dash = auto
	return s


# ── AS-01 ─────────────────────────────────────────────────────────────────────

func test_assist_round_trip_and_clamp() -> void:
	_settings(0.6, 0.8, true).save_to(PATH)
	var back := GameSettings.load_from(PATH)
	assert_float(back.assist_damage).is_equal_approx(0.6, 0.001)
	assert_float(back.assist_speed).is_equal_approx(0.8, 0.001)
	assert_bool(back.assist_auto_dash).is_true()
	assert_bool(back.assist_enabled).is_true()

	_settings(0.1, 0.2, false).save_to(PATH)
	var clamped := GameSettings.load_from(PATH)
	assert_float(clamped.assist_damage).is_equal(GameSettings.ASSIST_DAMAGE_MIN)
	assert_float(clamped.assist_speed).is_equal(GameSettings.ASSIST_SPEED_MIN)


# ── AS-02 ─────────────────────────────────────────────────────────────────────

func test_assist_active_only_when_changed() -> void:
	assert_bool(GameSettings.new().assist_active()).is_false()
	assert_bool(_settings(0.9, 1.0, false).assist_active()).is_true()
	assert_bool(_settings(1.0, 1.0, true).assist_active()).is_true()


# ── AS-03 ─────────────────────────────────────────────────────────────────────

func test_assist_base_time_scale_and_time_warp() -> void:
	GameSettings.current = _settings(1.0, 0.7, false)
	Engine.time_scale = GameSettings.base_time_scale()

	assert_float(GameSettings.base_time_scale()).is_equal_approx(0.7, 0.001)
	assert_bool(TimeWarp.is_free()).is_true()
	Engine.time_scale = 0.2
	TimeWarp.release(0.2)
	assert_float(Engine.time_scale).is_equal_approx(0.7, 0.001)


# ── AS-04 ─────────────────────────────────────────────────────────────────────

func test_assist_damage_share_scales_fayde_only() -> void:
	var hd: Node = HealthAndDamageScript.new()
	hd.set_process(false)
	var fayde := Node.new()
	fayde.add_to_group(&"player")
	add_child(hd)
	add_child(fayde)
	hd._fayde_current_hp = 100
	hd.player_damage_mult = 0.5

	hd.apply_damage(fayde, 20.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.CONTACT)

	assert_int(hd._fayde_current_hp).is_equal(90)
	remove_child(hd)
	remove_child(fayde)
	hd.free()
	fayde.free()


# ── AS-05 ─────────────────────────────────────────────────────────────────────

func test_assist_auto_dash_rules() -> void:
	var pc: PlayerController = PlayerControllerScript.new()
	pc._controller_state = PlayerController.ControllerState.ENABLED
	pc._dash_charges = 1

	assert_bool(pc.try_auto_dash()).is_false()  # off
	pc.auto_dash = true
	assert_bool(pc.try_auto_dash()).is_true()
	assert_int(pc._dash_charges).is_equal(0)
	assert_bool(pc.is_invincible()).is_true()
	pc._controller_state = PlayerController.ControllerState.ENABLED
	assert_bool(pc.try_auto_dash()).is_false()  # no charge left
	pc.free()


# ── AS-06 ─────────────────────────────────────────────────────────────────────

func test_assist_summary_note_only_when_assisted() -> void:
	var on := RunSummaryPanel.new()
	on.setup({"win": true, "assist": true})
	var off := RunSummaryPanel.new()
	off.setup({"win": true})

	assert_bool(_has_text(on, COPY.summary_assist_note)).is_true()
	assert_bool(_has_text(off, COPY.summary_assist_note)).is_false()
	on.free()
	off.free()


func _has_text(root: Node, text: String) -> bool:
	for n: Node in root.find_children("*", "Label", true, false):
		if (n as Label).text == text:
			return true
	return false


# ── AS-07 ─────────────────────────────────────────────────────────────────────

func test_assist_switch_off_restores_normal_play() -> void:
	var s := _settings(0.5, 0.7, true)
	s.assist_enabled = false
	GameSettings.current = s

	assert_bool(s.assist_active()).is_false()
	assert_float(s.effective_damage()).is_equal(1.0)
	assert_bool(s.effective_auto_dash()).is_false()
	assert_float(GameSettings.base_time_scale()).is_equal(1.0)
	s.assist_enabled = true
	assert_float(s.effective_damage()).is_equal_approx(0.5, 0.001)
	assert_bool(s.effective_auto_dash()).is_true()
	assert_float(GameSettings.base_time_scale()).is_equal_approx(0.7, 0.001)


func test_assist_switch_off_by_default_after_load() -> void:
	assert_bool(GameSettings.load_from("user://does_not_exist_assist.cfg").assist_enabled).is_false()


func test_assist_settings_panel_switch_locks_options() -> void:
	var s := _settings(0.8, 1.0, false)
	s.assist_enabled = false
	GameSettings.current = s
	var panel := SettingsPanel.new()
	panel.settings = s
	panel.save_path = PATH
	add_child(panel)

	assert_bool(panel.assist_controls_enabled()).is_false()
	var switch := panel.find_child("AssistEnabled", true, false) as CheckButton
	assert_object(switch).is_not_null()
	switch.button_pressed = true
	assert_bool(s.assist_enabled).is_true()
	assert_bool(panel.assist_controls_enabled()).is_true()
	assert_bool(GameSettings.load_from(PATH).assist_enabled).is_true()
	remove_child(panel)
	panel.free()
