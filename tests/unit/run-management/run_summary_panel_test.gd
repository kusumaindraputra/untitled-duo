## run_summary_panel_test.gd — End-of-run summary screen (beta plan U5).
##
## Coverage:
##   U5-01: time formats as M:SS
##   U5-02: room ranks are counted best-first; empty uses the placeholder
##   U5-03: stat rows follow the data, in order, with UICopy labels
##   U5-04: setup builds a win and a loss screen with focusable Run Again
##   U5-05: buttons emit their signals
##   U5-06: the sigil list shows titles, or the "none" text
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const COPY: UICopy = preload("res://assets/data/ui_copy.tres")


func _data(win: bool = false) -> Dictionary:
	return {
		"win": win, "floor": 2, "rooms": 9, "time_sec": 754.0, "enemies": 88, "best_combo": 7,
		"bosses": 1, "ranks": ["B", "A", "B", "S"], "shards": 42,
		"sigils": ["Swift Step", "Burning Trail"], "memories_new": 1, "memories_found": 4,
		"memories_total": 10, "hard_unlocked": false,
	}


func _all_text(node: Node) -> String:
	var out: String = ""
	if node is Label:
		out += (node as Label).text + "\n"
	elif node is Button:
		out += (node as Button).text + "\n"
	for c in node.get_children():
		out += _all_text(c)
	return out


func test_run_summary_time_formats_minutes_seconds() -> void:
	assert_str(RunSummaryPanel.format_time(754.9)).is_equal("12:34")
	assert_str(RunSummaryPanel.format_time(5.0)).is_equal("0:05")


func test_run_summary_ranks_counted_best_first() -> void:
	assert_str(RunSummaryPanel.rank_summary(["B", "A", "B", "S"], "-")).is_equal("S×1  A×1  B×2")
	assert_str(RunSummaryPanel.rank_summary([], "-")).is_equal("-")


func test_run_summary_stat_rows_follow_data() -> void:
	var rows: Array = RunSummaryPanel.stat_rows(_data(), COPY)

	assert_int(rows.size()).is_equal(6)
	assert_array(rows[0]).contains_exactly([COPY.summary_time, "12:34"])
	assert_array(rows[1]).contains_exactly([COPY.summary_enemies, "88"])
	assert_array(rows[2]).contains_exactly([COPY.summary_best_combo, "x7"])
	assert_array(rows[3]).contains_exactly([COPY.summary_bosses, "1"])
	assert_array(rows[5]).contains_exactly([COPY.shards_earned_label, "+42"])


func test_run_summary_setup_win_and_loss_titles() -> void:
	var win := RunSummaryPanel.new()
	win.setup(_data(true))
	var loss := RunSummaryPanel.new()
	loss.setup(_data(false))

	assert_str(_all_text(win)).contains(COPY.summary_win_title)
	assert_str(_all_text(loss)).contains(COPY.summary_loss_title)
	assert_object(win.run_again_button).is_not_null()
	assert_int(win.run_again_button.focus_mode).is_equal(Control.FOCUS_ALL)
	win.free()
	loss.free()


func test_run_summary_buttons_emit_signals() -> void:
	var panel := RunSummaryPanel.new()
	panel.setup(_data())
	var hits: Array[String] = []
	panel.run_again_pressed.connect(func() -> void: hits.append("again"))
	panel.main_menu_pressed.connect(func() -> void: hits.append("menu"))

	panel.run_again_button.pressed.emit()
	for c in panel.run_again_button.get_parent().get_children():
		if c != panel.run_again_button:
			(c as Button).pressed.emit()

	assert_array(hits).contains_exactly(["again", "menu"])
	panel.free()


func test_run_summary_lists_sigils_or_none() -> void:
	var with := RunSummaryPanel.new()
	with.setup(_data())
	var d: Dictionary = _data()
	d["sigils"] = []
	var without := RunSummaryPanel.new()
	without.setup(d)

	assert_str(_all_text(with)).contains("Swift Step").contains("Burning Trail")
	assert_str(_all_text(without)).contains(COPY.summary_no_sigils)
	with.free()
	without.free()
