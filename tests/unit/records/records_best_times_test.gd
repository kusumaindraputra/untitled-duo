## records_best_times_test.gd — Records (beta plan F3).
##
## Coverage:
##   RC-01: a faster win sets the record; a slower or zero one does not
##   RC-02: boss records are per boss and only improve
##   RC-03: records survive a save / load round trip
##   RC-04: bosses are listed in floor order (Sentinel, Warden, Keeper)
##   RC-05: the menu line shows "—" before any record and the time after one
##   RC-06: the summary shows each new-record line
##   RC-07: the menu line names only bosses the player has beaten
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const COPY: UICopy = preload("res://assets/data/ui_copy.tres")
const PATH: String = "user://test_records_progress.cfg"
const SENTINEL := 5
const WARDEN := 3
const KEEPER := 11


func after_test() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


# ── RC-01 ─────────────────────────────────────────────────────────────────────

func test_records_win_time_only_improves() -> void:
	var p := MetaProgress.new()

	assert_bool(p.record_win_time(900.0)).is_true()
	assert_bool(p.record_win_time(950.0)).is_false()
	assert_bool(p.record_win_time(0.0)).is_false()
	assert_bool(p.record_win_time(800.0)).is_true()
	assert_float(p.best_win_sec).is_equal(800.0)


# ── RC-02 ─────────────────────────────────────────────────────────────────────

func test_records_boss_times_per_boss() -> void:
	var p := MetaProgress.new()

	assert_bool(p.record_boss_time(SENTINEL, 60.0)).is_true()
	assert_bool(p.record_boss_time(WARDEN, 90.0)).is_true()
	assert_bool(p.record_boss_time(SENTINEL, 70.0)).is_false()
	assert_bool(p.record_boss_time(SENTINEL, 45.0)).is_true()
	assert_bool(p.record_boss_time(-1, 10.0)).is_false()
	assert_float(p.boss_best_sec[SENTINEL]).is_equal(45.0)
	assert_float(p.boss_best_sec[WARDEN]).is_equal(90.0)


# ── RC-03 ─────────────────────────────────────────────────────────────────────

func test_records_round_trip() -> void:
	var p := MetaProgress.new()
	p.record_win_time(1234.5)
	p.record_boss_time(KEEPER, 150.0)
	p.save_to(PATH)

	var back := MetaProgress.load_from(PATH)

	assert_float(back.best_win_sec).is_equal_approx(1234.5, 0.01)
	assert_float(back.boss_best_sec[KEEPER]).is_equal_approx(150.0, 0.01)


# ── RC-04 ─────────────────────────────────────────────────────────────────────

func test_records_bosses_in_floor_order() -> void:
	assert_array(Records.boss_ids()).contains_exactly([SENTINEL, WARDEN, KEEPER])
	assert_str(Records.boss_name(SENTINEL)).is_equal("Vault Sentinel")


# ── RC-05 ─────────────────────────────────────────────────────────────────────

func test_records_menu_line_before_and_after() -> void:
	var p := MetaProgress.new()
	assert_str(Records.menu_line(p)).contains(COPY.records_best_run_format % COPY.records_none)

	p.record_win_time(754.0)
	p.record_boss_time(SENTINEL, 48.0)
	var line: String = Records.menu_line(p)

	assert_str(line).contains(COPY.records_best_run_format % "12:34")
	assert_str(line).contains("0:48")
	assert_str(line).contains(COPY.records_runs_format % 0)


# ── RC-06 ─────────────────────────────────────────────────────────────────────

func test_records_summary_shows_new_record_lines() -> void:
	var lines: Array[String] = [Records.new_run_line(754.0), Records.new_boss_line(SENTINEL, 48.0)]
	var panel := RunSummaryPanel.new()

	panel.setup({"win": true, "records": lines})

	var texts: Array[String] = []
	for n: Node in panel.find_children("*", "Label", true, false):
		texts.append((n as Label).text)
	assert_array(texts).contains(lines)
	panel.free()


# ── RC-07 ─────────────────────────────────────────────────────────────────────

func test_records_menu_line_names_only_beaten_bosses() -> void:
	var p := MetaProgress.new()
	var fresh: String = Records.menu_line(p)

	for id in [SENTINEL, WARDEN, KEEPER]:
		assert_str(fresh).not_contains(Records.boss_name(id).replace(" ", "\u00a0"))
	assert_str(fresh).not_contains("\n")

	p.record_boss_time(SENTINEL, 48.0)
	var line: String = Records.menu_line(p)

	assert_str(line).contains(Records.boss_name(SENTINEL).replace(" ", "\u00a0"))
	assert_str(line).not_contains(Records.boss_name(WARDEN).replace(" ", "\u00a0"))
	assert_str(line).not_contains(Records.boss_name(KEEPER).replace(" ", "\u00a0"))
