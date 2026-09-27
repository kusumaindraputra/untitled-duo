## hud_scale_timer_test.gd — HUD scale on CombatHUD and the run timer (ADR-0046).
##
## Coverage:
##   HS-01: the left card rows sit under one scaled group, in their old draw order
##   HS-02: apply_hud_prefs scales the group and sets the card opacity
##   HS-03: at 130 % HUD the left card still clears the boss bar
##   RT-01: the timer is hidden while the setting is off or no clock is set
##   RT-02: the timer shows the clock in the Records format and sits bottom-left
##   RT-04: toasts stack above the timer when it shows
##   RT-03: RunManager.get_elapsed_sec is 0 before a run and final after it ends
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const RunManagerScript = preload("res://src/systems/run_manager.gd")

var _saved_current: GameSettings = null


func before_test() -> void:
	_saved_current = GameSettings.current
	GameSettings.current = GameSettings.new()


func after_test() -> void:
	GameSettings.current = _saved_current


func _make_hud() -> CombatHUD:
	var hud := CombatHUD.new()
	add_child(hud)
	hud.set_process(false)
	return hud


func _teardown_hud(hud: CombatHUD) -> void:
	remove_child(hud)
	hud.free()


func test_left_card_rows_share_one_group() -> void:
	var hud := _make_hud()
	var group: Node = hud.hp_bar.get_parent()

	assert_str(group.name).is_equal("LeftCard")
	assert_object(hud._left_panel.get_parent()).is_same(group)
	assert_object(hud._style_bar.get_parent()).is_same(group)
	# The card background still draws beneath its rows.
	assert_int(hud._left_panel.get_index()).is_less(hud.hp_bar.get_index())
	_teardown_hud(hud)


func test_apply_hud_prefs_scales_and_fades_card() -> void:
	var hud := _make_hud()

	hud.apply_hud_prefs(1.15, 0.5)

	assert_float(hud.get_hud_scale()).is_equal_approx(1.15, 0.0001)
	assert_float(hud.get_card_alpha()).is_equal_approx(CombatHUD.LEFT_PANEL_BG.a * 0.5, 0.0001)
	_teardown_hud(hud)


func test_largest_hud_scale_clears_boss_bar() -> void:
	var hud := _make_hud()
	var biggest: float = GameSettings.HUD_SCALES[GameSettings.HUD_SCALES.size() - 1]

	hud.apply_hud_prefs(biggest, 1.0)
	hud._layout_boss_ui()

	var card_right: float = (hud._left_panel.position.x + hud._left_panel.size.x) * biggest
	assert_float(card_right).is_less(hud.get_boss_bar_rect().position.x)
	_teardown_hud(hud)


func test_timer_hidden_when_off_or_no_clock() -> void:
	var timer := RunTimerLabel.new()
	timer.clock = func() -> float: return 12.0
	add_child(timer)
	assert_bool(timer.visible).is_false()

	GameSettings.current.show_run_timer = true
	timer.clock = Callable()
	timer.refresh_hud_prefs()
	assert_bool(timer.visible).is_false()
	remove_child(timer)
	timer.free()


func test_timer_shows_records_format_bottom_left() -> void:
	GameSettings.current.show_run_timer = true
	var timer := RunTimerLabel.new()
	timer.clock = func() -> float: return 125.7
	add_child(timer)
	timer.refresh_hud_prefs()

	assert_bool(timer.visible).is_true()
	assert_str(timer.text).is_equal(RunSummaryPanel.format_time(125.7))
	var view: Vector2 = timer.get_viewport_rect().size
	assert_float(timer.position.x).is_equal(RunTimerLabel.MARGIN)
	assert_float(timer.position.y).is_greater(view.y * 0.5)
	assert_float(timer.corner_height()).is_greater(RunTimerLabel.MARGIN)
	remove_child(timer)
	timer.free()


func test_run_manager_elapsed_before_and_after_run() -> void:
	var rm: Node = RunManagerScript.new()

	assert_float(rm.get_elapsed_sec()).is_equal(0.0)
	rm._on_run_started()
	assert_float(rm.get_elapsed_sec()).is_greater_equal(0.0)
	rm._on_run_ended(false)
	var final_sec: float = rm.get_elapsed_sec()

	assert_float(rm.get_elapsed_sec()).is_equal(final_sec)
	assert_float(final_sec).is_equal(float(rm.get_run_data()["run_time_sec"]))
	rm.free()


func test_toasts_stack_above_timer() -> void:
	GameSettings.current.show_run_timer = true
	var timer := RunTimerLabel.new()
	timer.clock = func() -> float: return 5.0
	add_child(timer)
	timer.refresh_hud_prefs()
	var toaster := HudToaster.new()
	toaster.bottom_inset = timer.corner_height
	add_child(toaster)
	toaster.set_process(false)
	toaster.push("Sigil gained · Ember")
	toaster.tick(0.5)

	var card := toaster.get_child(0) as Control
	assert_float(card.position.y + card.size.y).is_less_equal(timer.position.y)
	remove_child(toaster)
	toaster.free()
	remove_child(timer)
	timer.free()
