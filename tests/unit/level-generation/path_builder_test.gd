## path_builder_test.gd — Unit tests for PathBuilder (LD-17).
##
## Coverage:
##   - Linear generation (5 rooms): no branch, Rest→Boss at end
##   - Branch generation (6–8 rooms): branch at index 1, two paths, rejoin at Rest
##   - Elite placement: present when remaining >= 5, on longer path
##   - AC-CM-06: max exits ≤ 3
##   - AC-CM-07: path length diff ≤ 1
##   - Boss reachability: all rooms can reach Boss
##   - Acyclicity: generated graph always a DAG
##   - Input validation: rejects room_count < 5
##
## Roadmap: design/level-design-roadmap.md (LD-17)
## GDD:    design/room-connection-model.md, design/room-type-taxonomy.md
extends GdUnitTestSuite


# ── Input validation ───────────────────────────────────────────────────────────

func test_rejects_room_count_below_5() -> void:
	var pb := PathBuilder.new()
	for n: int in [0, 1, 2, 3, 4]:
		var g: DungeonGraph = pb.generate(n)
		assert_object(g).is_null()


# ── Linear (5 rooms) ───────────────────────────────────────────────────────────

func test_generate_5_rooms_linear_no_branch() -> void:
	var g: DungeonGraph = PathBuilder.new().generate(5)
	assert_int(g.room_count()).is_equal(5)
	# No branch point — every room has ≤ 1 exit (except Boss which has 0).
	assert_int(PathBuilder.max_exits(g)).is_equal(1)
	# Rest second-to-last, Boss last.
	assert_int(_type(g, 3)).is_equal(DungeonGraph.ROOM_TYPE_REST)
	assert_int(_type(g, 4)).is_equal(DungeonGraph.ROOM_TYPE_BOSS)
	# All rooms reach Boss.
	for i: int in range(5):
		assert_bool(g.has_path(i, 4)).is_true()


func test_generate_5_rooms_no_elite() -> void:
	# remaining = 3 < 5 → no Elite.
	var g: DungeonGraph = PathBuilder.new().generate(5)
	assert_array(g.get_rooms_by_type(DungeonGraph.ROOM_TYPE_ELITE)).is_empty()


func test_generate_5_rooms_all_combat_before_rest() -> void:
	var g: DungeonGraph = PathBuilder.new().generate(5)
	for i: int in range(3):
		assert_int(_type(g, i)).is_equal(DungeonGraph.ROOM_TYPE_COMBAT)


# ── Branch (6 rooms) ───────────────────────────────────────────────────────────

func test_generate_6_rooms_has_branch() -> void:
	var g: DungeonGraph = PathBuilder.new().generate(6)
	assert_int(g.room_count()).is_equal(6)
	# Branch at index 1 should have 2 outgoing edges.
	assert_int(g.get_outgoing(1).size()).is_equal(2)


func test_generate_6_rooms_rest_and_boss_last() -> void:
	var g: DungeonGraph = PathBuilder.new().generate(6)
	assert_int(_type(g, 4)).is_equal(DungeonGraph.ROOM_TYPE_REST)
	assert_int(_type(g, 5)).is_equal(DungeonGraph.ROOM_TYPE_BOSS)


func test_generate_6_rooms_no_elite() -> void:
	# remaining = 4 < 5 → no Elite.
	var g: DungeonGraph = PathBuilder.new().generate(6)
	assert_array(g.get_rooms_by_type(DungeonGraph.ROOM_TYPE_ELITE)).is_empty()


func test_generate_6_rooms_all_paths_reach_boss() -> void:
	var g: DungeonGraph = PathBuilder.new().generate(6)
	for i: int in range(6):
		assert_bool(g.has_path(i, 5)).is_true()


# ── Branch (7 rooms) — has Elite ───────────────────────────────────────────────

func test_generate_7_rooms_has_elite() -> void:
	# remaining = 5 >= 5 → 1 Elite.
	var g: DungeonGraph = PathBuilder.new().generate(7)
	var elites: Array[int] = g.get_rooms_by_type(DungeonGraph.ROOM_TYPE_ELITE)
	assert_int(elites.size()).is_equal(1)


func test_generate_7_rooms_structure() -> void:
	var g: DungeonGraph = PathBuilder.new().generate(7)
	assert_int(g.room_count()).is_equal(7)
	assert_int(_type(g, 5)).is_equal(DungeonGraph.ROOM_TYPE_REST)
	assert_int(_type(g, 6)).is_equal(DungeonGraph.ROOM_TYPE_BOSS)
	# Entry room is Combat.
	assert_int(_type(g, 0)).is_equal(DungeonGraph.ROOM_TYPE_COMBAT)


# ── Branch (8 rooms) ───────────────────────────────────────────────────────────

func test_generate_8_rooms_has_elite() -> void:
	# remaining = 6 >= 5 → 1 Elite.
	var g: DungeonGraph = PathBuilder.new().generate(8)
	assert_int(g.room_count()).is_equal(8)
	var elites: Array[int] = g.get_rooms_by_type(DungeonGraph.ROOM_TYPE_ELITE)
	assert_int(elites.size()).is_equal(1)


# ── AC-CM-06: Max exits never exceeds 3 ────────────────────────────────────────

func test_max_exits_at_most_3() -> void:
	for n: int in range(5, 9):
		var g: DungeonGraph = PathBuilder.new().generate(n)
		assert_int(PathBuilder.max_exits(g)).is_less_equal(3) \
			.override_failure_message("room_count=%d: max_exits=%d" % [n, PathBuilder.max_exits(g)])


# ── AC-CM-07: Path length diff ≤ 1 ────────────────────────────────────────────

func test_path_length_diff_at_most_1() -> void:
	for n: int in range(5, 9):
		var g: DungeonGraph = PathBuilder.new().generate(n)
		var diff: int = PathBuilder.path_length_diff(g)
		assert_int(diff).is_less_equal(1) \
			.override_failure_message("room_count=%d: path_length_diff=%d" % [n, diff])


# ── Acyclicity ─────────────────────────────────────────────────────────────────

func test_generated_graph_is_acyclic() -> void:
	for n: int in range(5, 9):
		var g: DungeonGraph = PathBuilder.new().generate(n)
		assert_bool(g.is_acyclic()).is_true() \
			.override_failure_message("room_count=%d: graph has cycle" % n)


# ── Entry room ─────────────────────────────────────────────────────────────────

func test_entry_room_is_always_combat() -> void:
	for n: int in range(5, 9):
		var g: DungeonGraph = PathBuilder.new().generate(n)
		assert_int(_type(g, g.get_entry_room())) \
			.is_equal(DungeonGraph.ROOM_TYPE_COMBAT) \
			.override_failure_message("room_count=%d: entry is not Combat" % n)


# ── Boss reachability ──────────────────────────────────────────────────────────

func test_all_rooms_reach_boss() -> void:
	for n: int in range(5, 9):
		var g: DungeonGraph = PathBuilder.new().generate(n)
		var boss_idx: int = n - 1
		for i: int in range(n):
			assert_bool(g.has_path(i, boss_idx)).is_true() \
				.override_failure_message("room_count=%d: room %d cannot reach Boss" % [n, i])


# ── Rest → Boss edge ───────────────────────────────────────────────────────────

func test_rest_connected_to_boss() -> void:
	for n: int in range(5, 9):
		var g: DungeonGraph = PathBuilder.new().generate(n)
		var rests: Array[int] = g.get_rooms_by_type(DungeonGraph.ROOM_TYPE_REST)
		var boss: int = n - 1
		for rest_idx: int in rests:
			assert_array(g.get_outgoing(rest_idx)).contains_exactly([boss]) \
				.override_failure_message("room_count=%d: Rest at %d does not point to Boss %d" % [n, rest_idx, boss])


# ── Helpers ────────────────────────────────────────────────────────────────────

func _type(graph: DungeonGraph, idx: int) -> int:
	return int(graph.get_room(idx)["type"])
