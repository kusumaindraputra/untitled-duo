## run_save_resume_test.gd — Run save and resume (ADR-0048).
##
## Coverage:
##   RS-01: DungeonGraph.to_data / from_data keeps rooms, states, modifiers, templates, edges
##   RS-02: RunSave.write then read returns the same snapshot; clear removes it
##   RS-03: a save with another SAVE_VERSION, or a broken snapshot, reads back as {}
##   RS-04: take_resume_request returns the flag once, then false
##   RS-05: RunManager.snapshot / restore_snapshot keep counters and the run clock
##   RS-06: HealthAndDamage.restore_fayde_hp clamps to [1, max] and follows HP zones
##   RS-07: main menu shows a focused Continue above Play only when a save exists
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const PATH: String = "user://test_run_save.cfg"
const PROGRESS_PATH: String = "user://test_run_save_progress.cfg"
const COPY: UICopy = preload("res://assets/data/ui_copy.tres")
const TEMPLATE_PATH: String = "res://assets/data/room_templates/template_arena.tres"
const RunManagerScript = preload("res://src/systems/run_manager.gd")
const HealthAndDamageScript = preload("res://src/systems/health_and_damage.gd")
const MainMenuScript = preload("res://src/scenes/main_menu.gd")


func after_test() -> void:
	RunSave.resume_requested = false
	for p: String in [PATH, PROGRESS_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## Entry → combat (Challenge) → boss, with the entry visited and a template on room 1.
func _graph() -> DungeonGraph:
	var g := DungeonGraph.new()
	g.add_room(DungeonGraph.ROOM_TYPE_COMBAT)
	g.add_room(DungeonGraph.ROOM_TYPE_COMBAT, load(TEMPLATE_PATH) as RoomTemplate)
	g.add_room(DungeonGraph.ROOM_TYPE_BOSS)
	g.add_edge(0, 1)
	g.add_edge(1, 2)
	g.set_room_state(0, DungeonGraph.ROOM_STATE_CLEARED)
	g.set_room_state(1, DungeonGraph.ROOM_STATE_VISITED)
	g.get_room(1)[RoomModifiers.KEY] = RoomModifiers.CHALLENGE
	return g


func _snapshot() -> Dictionary:
	var loadout: Array = []
	loadout.resize(PranaLoadout.SLOT_COUNT)
	loadout[PranaLoadout.CORE_SLOT] = 2
	loadout[0] = 1
	return {
		"floor": 2, "total_floors": 3, "graph": _graph().to_data(), "room_idx": 1,
		"rooms_entered": 4, "loadout": loadout, "bag": [3, 3], "hp": 57,
		"sigils": ["damage", "heal"], "core": "glass", "run_seed": 12345,
		"run": {"rooms_cleared": 9, "run_time_sec": 321.5},
	}


# ── RS-01 ─────────────────────────────────────────────────────────────────────

func test_graph_round_trip_keeps_rooms_and_edges() -> void:
	var g: DungeonGraph = DungeonGraph.from_data(_graph().to_data())

	assert_int(g.room_count()).is_equal(3)
	assert_int(g.edge_count()).is_equal(2)
	assert_int(int(g.get_room(2)["type"])).is_equal(DungeonGraph.ROOM_TYPE_BOSS)
	assert_int(int(g.get_room(0)["state"])).is_equal(DungeonGraph.ROOM_STATE_CLEARED)
	assert_int(int(g.get_room(1)["state"])).is_equal(DungeonGraph.ROOM_STATE_VISITED)
	assert_int(RoomModifiers.of(g, 1)).is_equal(RoomModifiers.CHALLENGE)
	assert_int(RoomModifiers.of(g, 0)).is_equal(RoomModifiers.NONE)
	assert_str((g.get_room(1)["template"] as RoomTemplate).resource_path).is_equal(TEMPLATE_PATH)
	assert_object(g.get_room(0)["template"]).is_null()
	assert_array(g.get_outgoing(1)).contains_exactly([2])
	assert_int(g.get_entry_room()).is_equal(0)


func test_graph_missing_template_loads_as_null() -> void:
	var data: Dictionary = _graph().to_data()
	(data["rooms"][1] as Dictionary)["template"] = "res://does/not/exist.tres"

	assert_object(DungeonGraph.from_data(data).get_room(1)["template"]).is_null()


# ── RS-02 ─────────────────────────────────────────────────────────────────────

func test_write_then_read_returns_snapshot() -> void:
	assert_int(RunSave.write(_snapshot(), PATH)).is_equal(OK)

	var back: Dictionary = RunSave.read(PATH)
	assert_bool(RunSave.exists(PATH)).is_true()
	assert_int(int(back["floor"])).is_equal(2)
	assert_int(int(back["hp"])).is_equal(57)
	assert_array(back["loadout"] as Array).contains_exactly([1, null, null, null, 2, null, null, null, null])
	assert_array(back["sigils"] as Array).contains_exactly(["damage", "heal"])
	assert_int(int(back["run_seed"])).is_equal(12345)
	assert_int(DungeonGraph.from_data(back["graph"] as Dictionary).room_count()).is_equal(3)
	assert_that(RunSave.progress_of(back)).is_equal(Vector2i(2, 4))


func test_clear_removes_the_save() -> void:
	RunSave.write(_snapshot(), PATH)
	RunSave.clear(PATH)

	assert_bool(FileAccess.file_exists(PATH)).is_false()
	assert_bool(RunSave.exists(PATH)).is_false()
	RunSave.clear(PATH)  # no file: still safe


func test_missing_file_reads_empty() -> void:
	assert_dict(RunSave.read(PATH)).is_empty()


# ── RS-03 ─────────────────────────────────────────────────────────────────────

func test_other_save_version_is_dropped() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("run", "version", RunSave.SAVE_VERSION + 1)
	cfg.set_value("run", "data", _snapshot())
	cfg.save(PATH)

	assert_dict(RunSave.read(PATH)).is_empty()


func test_broken_snapshots_are_not_resumable() -> void:
	var cases: Array[Dictionary] = []
	var s: Dictionary = _snapshot()
	s.erase("graph")
	cases.append(s)
	s = _snapshot()
	s["floor"] = 4  # past total_floors
	cases.append(s)
	s = _snapshot()
	s["room_idx"] = 3  # graph has 3 rooms
	cases.append(s)
	s = _snapshot()
	s["hp"] = 0
	cases.append(s)
	s = _snapshot()
	s["loadout"] = [1, 2]
	cases.append(s)
	for c: Dictionary in cases:
		assert_bool(RunSave.is_valid(c)).is_false()
	assert_bool(RunSave.is_valid(_snapshot())).is_true()


# ── RS-04 ─────────────────────────────────────────────────────────────────────

func test_resume_request_is_taken_once() -> void:
	RunSave.resume_requested = true

	assert_bool(RunSave.take_resume_request()).is_true()
	assert_bool(RunSave.take_resume_request()).is_false()


# ── RS-05 ─────────────────────────────────────────────────────────────────────

func test_run_manager_restore_keeps_counters_and_clock() -> void:
	var rm: Node = RunManagerScript.new()
	add_child(rm)
	rm._on_run_started()
	rm.restore_snapshot({"waves_completed": 7, "rooms_cleared": 6, "current_floor": 2,
		"enemies_killed": 41, "best_combo": 5, "run_time_sec": 300.0})

	var snap: Dictionary = rm.snapshot()
	assert_int(int(snap["rooms_cleared"])).is_equal(6)
	assert_int(int(snap["current_floor"])).is_equal(2)
	assert_int(int(snap["enemies_killed"])).is_equal(41)
	assert_int(int(snap["best_combo"])).is_equal(5)
	assert_int(int(snap["waves_completed"])).is_equal(7)
	assert_float(float(snap["run_time_sec"])).is_between(300.0, 301.0)
	remove_child(rm)
	rm.free()


# ── RS-06 ─────────────────────────────────────────────────────────────────────

func test_restore_fayde_hp_clamps_and_sets_zone() -> void:
	var hd: Node = HealthAndDamageScript.new()
	var zones: Array[int] = []
	hd.player_hp_zone_changed.connect(func(z: GameEnums.HPZone) -> void: zones.append(z))

	hd.restore_fayde_hp(10)
	assert_int(hd.get_fayde_hp()).is_equal(10)
	assert_array(zones).contains_exactly([GameEnums.HPZone.DESPERATE])
	hd.restore_fayde_hp(0)
	assert_int(hd.get_fayde_hp()).is_equal(1)
	hd.restore_fayde_hp(999)
	assert_int(hd.get_fayde_hp()).is_equal(hd.FAYDE_MAX_HP)
	hd.free()


# ── RS-07 ─────────────────────────────────────────────────────────────────────

func _menu() -> Control:
	var menu: Control = MainMenuScript.new()
	menu.progress_path = PROGRESS_PATH
	menu.run_save_path = PATH
	add_child(menu)
	return menu


func test_menu_has_no_continue_without_a_save() -> void:
	var menu: Control = _menu()

	assert_object(menu._continue_button).is_null()
	remove_child(menu)
	menu.free()


func test_menu_continue_sits_above_play_and_takes_focus() -> void:
	RunSave.write(_snapshot(), PATH)
	var menu: Control = _menu()

	var b: Button = menu._continue_button
	assert_object(b).is_not_null()
	assert_str(b.text).is_equal(COPY.menu_continue_format % [2, 4])
	assert_int(b.get_index()).is_less(menu._play_button.get_index())
	assert_bool(b.has_focus()).is_true()
	remove_child(menu)
	menu.free()
