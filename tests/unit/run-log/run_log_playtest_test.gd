## run_log_playtest_test.gd — Local playtest run log (ADR-0048).
##
## Coverage:
##   RL-01: a death entry carries time, version, floor, rooms, run time, cause and spells
##   RL-02: win and abandoned entries carry no cause
##   RL-03: append writes one JSON line per run and keeps only the newest max_entries
##   RL-04: read_all skips lines that aren't JSON objects
##   RL-05: build_entry names the core spell and lists the grid, -1 for empty slots
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const PATH: String = "user://test_run_log.jsonl"
const NOW: String = "2026-09-27T12:00:00Z"
const VERSION: String = "0.10.0-alpha"


func after_test() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _run() -> Dictionary:
	return {"floor": 2, "rooms": 11, "run_sec": 612.34, "core": "glass",
		"sigils": ["damage"], "casts": 88, "assist": false, "hard": true, "resumes": 1}


func _builds() -> Array[Dictionary]:
	var b: Array[Dictionary] = [
		{"floor": 1, "room": 1, "core": "Ember", "grid": [], "reactions": []},
		{"floor": 1, "room": 2, "core": "Ember", "grid": [], "reactions": []},
		{"floor": 2, "room": 1, "core": "Frost", "grid": [], "reactions": []},
	]
	return b


# ── RL-01 ─────────────────────────────────────────────────────────────────────

func test_death_entry_has_run_facts_and_cause() -> void:
	var hit: Dictionary = DeathRecap.cause("Vault Sentinel", DeathRecap.ATTACK_LASER)
	var e: Dictionary = RunLog.entry(RunLog.OUTCOME_DEATH, _run(), hit, "Laser.", _builds(), NOW, VERSION)

	assert_str(e["time"]).is_equal(NOW)
	assert_str(e["version"]).is_equal(VERSION)
	assert_str(e["outcome"]).is_equal("death")
	assert_int(e["floor"]).is_equal(2)
	assert_int(e["rooms_cleared"]).is_equal(11)
	assert_float(e["run_sec"]).is_equal_approx(612.3, 0.001)
	assert_str((e["cause"] as Dictionary)["attacker"]).is_equal("Vault Sentinel")
	assert_str((e["cause"] as Dictionary)["attack"]).is_equal("laser")
	assert_str((e["cause"] as Dictionary)["text"]).is_equal("Laser.")
	assert_array(e["spells"] as Array).contains_exactly(["Ember", "Frost"])
	assert_int((e["builds"] as Array).size()).is_equal(3)
	assert_int(e["casts"]).is_equal(88)
	assert_int(e["resumes"]).is_equal(1)
	assert_bool(e["hard"]).is_true()


# ── RL-02 ─────────────────────────────────────────────────────────────────────

func test_win_and_abandoned_have_no_cause() -> void:
	var hit: Dictionary = DeathRecap.cause("Vault Sentinel", DeathRecap.ATTACK_LASER)
	for outcome: String in [RunLog.OUTCOME_WIN, RunLog.OUTCOME_ABANDONED]:
		var e: Dictionary = RunLog.entry(outcome, _run(), hit, "", _builds(), NOW, VERSION)
		assert_dict(e["cause"] as Dictionary).is_empty()


# ── RL-03 ─────────────────────────────────────────────────────────────────────

func test_append_writes_one_json_line_per_run() -> void:
	var e: Dictionary = RunLog.entry(RunLog.OUTCOME_WIN, _run(), {}, "", _builds(), NOW, VERSION)
	assert_int(RunLog.append(e, PATH)).is_equal(OK)
	assert_int(RunLog.append(e, PATH)).is_equal(OK)

	var lines: PackedStringArray = FileAccess.get_file_as_string(PATH).strip_edges().split("\n")
	assert_int(lines.size()).is_equal(2)
	var back: Array[Dictionary] = RunLog.read_all(PATH)
	assert_int(back.size()).is_equal(2)
	assert_str(back[1]["outcome"]).is_equal("win")
	assert_array(back[1]["spells"] as Array).contains_exactly(["Ember", "Frost"])


func test_append_keeps_newest_entries() -> void:
	for i: int in 5:
		var run: Dictionary = _run()
		run["rooms"] = i
		RunLog.append(RunLog.entry(RunLog.OUTCOME_WIN, run, {}, "", _builds(), NOW, VERSION), PATH, 3)

	var back: Array[Dictionary] = RunLog.read_all(PATH)
	assert_int(back.size()).is_equal(3)
	assert_int(int(back[0]["rooms_cleared"])).is_equal(2)
	assert_int(int(back[2]["rooms_cleared"])).is_equal(4)


# ── RL-04 ─────────────────────────────────────────────────────────────────────

func test_read_all_skips_bad_lines() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_line("{\"outcome\": \"win\"}")
	f.store_line("not json")
	f.store_line("[1, 2]")
	f.close()

	var back: Array[Dictionary] = RunLog.read_all(PATH)
	assert_int(back.size()).is_equal(1)
	assert_int(RunLog.read_all("user://no_such_log.jsonl").size()).is_equal(0)


# ── RL-05 ─────────────────────────────────────────────────────────────────────

func test_build_entry_names_core_and_lists_grid() -> void:
	var slots: Array = []
	slots.resize(9)
	slots[4] = 0
	slots[1] = 0
	var b: Dictionary = RunLog.build_entry(1, 3, slots)

	assert_int(b["floor"]).is_equal(1)
	assert_int(b["room"]).is_equal(3)
	assert_str(b["core"]).is_equal(PranaCatalog.get_type(0).name)
	assert_array(b["grid"] as Array).contains_exactly([-1, 0, -1, -1, 0, -1, -1, -1, -1])


func test_build_entry_without_core_is_blank() -> void:
	var slots: Array = []
	slots.resize(9)

	assert_str(RunLog.build_entry(1, 1, slots)["core"]).is_equal("")
