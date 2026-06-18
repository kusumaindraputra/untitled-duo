## dungeon_graph_test.gd — Unit tests for DungeonGraph (LD-16).
##
## Coverage:
##   - Empty graph state
##   - add_room() returns index and stores data
##   - connect() creates directed edge, idempotent
##   - get_outgoing() / get_incoming() direction-aware
##   - get_entry_room() / get_exit_rooms() traversal endpoints
##   - get_rooms_by_type() type filtering
##   - has_path() BFS reachability (linear, branching, DAG)
##   - is_acyclic() (DAG pass, cycle detection)
##   - set_room_state() / get_room() state transitions
##
## Roadmap: design/level-design-roadmap.md (LD-16)
## GDD:    design/room-connection-model.md, design/room-type-taxonomy.md
extends GdUnitTestSuite


# ── Empty state ─────────────────────────────────────────────────────────────────

func test_graph_initially_empty() -> void:
	var g := DungeonGraph.new()
	assert_int(g.room_count()).is_equal(0)
	assert_int(g.edge_count()).is_equal(0)
	assert_int(g.get_entry_room()).is_equal(-1)
	assert_array(g.get_exit_rooms()).is_empty()


# ── add_room ────────────────────────────────────────────────────────────────────

func test_add_room_returns_index_and_stores_data() -> void:
	var g := DungeonGraph.new()
	var idx0: int = g.add_room(DungeonGraph.ROOM_TYPE_COMBAT)
	var idx1: int = g.add_room(DungeonGraph.ROOM_TYPE_ELITE)
	assert_int(idx0).is_equal(0)
	assert_int(idx1).is_equal(1)
	# Verify stored data
	var room0: Dictionary = g.get_room(0)
	assert_int(room0["type"]).is_equal(DungeonGraph.ROOM_TYPE_COMBAT)
	assert_int(room0["state"]).is_equal(DungeonGraph.ROOM_STATE_UNVISITED)
	assert_object(room0["template"]).is_null()
	var room1: Dictionary = g.get_room(1)
	assert_int(room1["type"]).is_equal(DungeonGraph.ROOM_TYPE_ELITE)


func test_add_room_stores_template_reference() -> void:
	var g := DungeonGraph.new()
	var tmpl := RoomTemplate.new()
	tmpl.display_name = "Test Template"
	g.add_room(DungeonGraph.ROOM_TYPE_COMBAT, tmpl)
	assert_object(g.get_room(0)["template"]).is_equal(tmpl)


func test_get_room_out_of_bounds_returns_empty_dict() -> void:
	var g := DungeonGraph.new()
	g.add_room(0)
	assert_bool(g.get_room(99).is_empty()).is_true()
	assert_bool(g.get_room(-1).is_empty()).is_true()


# ── connect ─────────────────────────────────────────────────────────────────────

func test_connect_creates_directed_edge() -> void:
	var g := DungeonGraph.new()
	g.add_room(0)
	g.add_room(0)
	g.add_edge(0, 1)
	assert_int(g.edge_count()).is_equal(1)
	# Direction-aware: outgoing from 0, incoming to 1
	assert_array(g.get_outgoing(0)).contains_exactly([1])
	assert_array(g.get_incoming(1)).contains_exactly([0])
	assert_array(g.get_incoming(0)).is_empty()
	assert_array(g.get_outgoing(1)).is_empty()


func test_connect_is_idempotent() -> void:
	var g := DungeonGraph.new()
	g.add_room(0)
	g.add_room(0)
	g.add_edge(0, 1)
	g.add_edge(0, 1)
	assert_int(g.edge_count()).is_equal(1)


func test_connect_reverse_edge_is_distinct() -> void:
	var g := DungeonGraph.new()
	g.add_room(0)
	g.add_room(0)
	g.add_edge(0, 1)
	g.add_edge(1, 0)  # reverse — distinct edge
	assert_int(g.edge_count()).is_equal(2)


func test_connect_out_of_bounds_warns() -> void:
	var g := DungeonGraph.new()
	g.add_room(0)
	g.add_edge(0, 99)  # out of bounds — should push_warning, not crash
	assert_int(g.edge_count()).is_equal(0)


# ── get_rooms_by_type ───────────────────────────────────────────────────────────

func test_get_rooms_by_type_filters_correctly() -> void:
	var g := DungeonGraph.new()
	g.add_room(DungeonGraph.ROOM_TYPE_COMBAT)   # 0
	g.add_room(DungeonGraph.ROOM_TYPE_ELITE)    # 1
	g.add_room(DungeonGraph.ROOM_TYPE_COMBAT)   # 2
	g.add_room(DungeonGraph.ROOM_TYPE_REST)     # 3
	assert_array(g.get_rooms_by_type(DungeonGraph.ROOM_TYPE_COMBAT)).contains_exactly([0, 2])
	assert_array(g.get_rooms_by_type(DungeonGraph.ROOM_TYPE_ELITE)).contains_exactly([1])
	assert_array(g.get_rooms_by_type(DungeonGraph.ROOM_TYPE_REST)).contains_exactly([3])
	assert_array(g.get_rooms_by_type(DungeonGraph.ROOM_TYPE_BOSS)).is_empty()


# ── Entry / exit detection ──────────────────────────────────────────────────────

func test_entry_and_exit_on_linear_chain() -> void:
	var g := DungeonGraph.new()
	g.add_room(0)   # 0
	g.add_room(0)   # 1
	g.add_room(0)   # 2
	g.add_edge(0, 1)
	g.add_edge(1, 2)
	assert_int(g.get_entry_room()).is_equal(0)
	assert_array(g.get_exit_rooms()).contains_exactly([2])


# ── has_path — BFS reachability ─────────────────────────────────────────────────

func test_has_path_identity() -> void:
	var g := DungeonGraph.new()
	g.add_room(0)
	assert_bool(g.has_path(0, 0)).is_true()


func test_has_path_linear() -> void:
	var g := DungeonGraph.new()
	g.add_room(0)   # 0
	g.add_room(0)   # 1
	g.add_room(0)   # 2
	g.add_edge(0, 1)
	g.add_edge(1, 2)
	assert_bool(g.has_path(0, 2)).is_true()
	assert_bool(g.has_path(2, 0)).is_false()   # directed — no reverse path
	assert_bool(g.has_path(0, 1)).is_true()


func test_has_path_branching_and_regroup() -> void:
	# 0 → 1 → 3
	# 0 → 2 → 3   (Hades-like branch → regroup)
	var g := DungeonGraph.new()
	g.add_room(0)   # 0
	g.add_room(0)   # 1
	g.add_room(0)   # 2
	g.add_room(0)   # 3
	g.add_edge(0, 1)
	g.add_edge(0, 2)
	g.add_edge(1, 3)
	g.add_edge(2, 3)
	assert_bool(g.has_path(0, 3)).is_true()
	assert_bool(g.has_path(1, 3)).is_true()
	assert_bool(g.has_path(2, 3)).is_true()
	assert_bool(g.has_path(1, 2)).is_false()   # no cross-connection
	assert_bool(g.has_path(2, 1)).is_false()


func test_has_path_oob_returns_false() -> void:
	var g := DungeonGraph.new()
	g.add_room(0)
	assert_bool(g.has_path(0, 99)).is_false()
	assert_bool(g.has_path(99, 0)).is_false()


# ── is_acyclic ──────────────────────────────────────────────────────────────────

func test_is_acyclic_on_linear_dag() -> void:
	var g := DungeonGraph.new()
	g.add_room(0)   # 0
	g.add_room(0)   # 1
	g.add_room(0)   # 2
	g.add_room(0)   # 3
	g.add_edge(0, 1)
	g.add_edge(1, 2)
	g.add_edge(2, 3)
	assert_bool(g.is_acyclic()).is_true()


func test_is_acyclic_on_branching_dag() -> void:
	# 0 → 1 → 3
	# 0 → 2 → 3
	var g := DungeonGraph.new()
	g.add_room(0)
	g.add_room(0)
	g.add_room(0)
	g.add_room(0)
	g.add_edge(0, 1)
	g.add_edge(0, 2)
	g.add_edge(1, 3)
	g.add_edge(2, 3)
	assert_bool(g.is_acyclic()).is_true()


func test_is_acyclic_detects_cycle() -> void:
	var g := DungeonGraph.new()
	g.add_room(0)   # 0
	g.add_room(0)   # 1
	g.add_room(0)   # 2
	g.add_edge(0, 1)
	g.add_edge(1, 2)
	g.add_edge(2, 0)   # cycle!
	assert_bool(g.is_acyclic()).is_false()


func test_is_acyclic_on_empty_graph() -> void:
	var g := DungeonGraph.new()
	assert_bool(g.is_acyclic()).is_true()


# ── Room state transitions ──────────────────────────────────────────────────────

func test_room_state_default_and_transitions() -> void:
	var g := DungeonGraph.new()
	g.add_room(DungeonGraph.ROOM_TYPE_COMBAT)
	assert_int(g.get_room(0)["state"]).is_equal(DungeonGraph.ROOM_STATE_UNVISITED)
	g.set_room_state(0, DungeonGraph.ROOM_STATE_VISITED)
	assert_int(g.get_room(0)["state"]).is_equal(DungeonGraph.ROOM_STATE_VISITED)
	g.set_room_state(0, DungeonGraph.ROOM_STATE_CLEARED)
	assert_int(g.get_room(0)["state"]).is_equal(DungeonGraph.ROOM_STATE_CLEARED)


func test_set_room_state_oob_no_crash() -> void:
	var g := DungeonGraph.new()
	g.set_room_state(99, DungeonGraph.ROOM_STATE_VISITED)   # should push_warning, not crash
	assert_bool(true).is_true()
