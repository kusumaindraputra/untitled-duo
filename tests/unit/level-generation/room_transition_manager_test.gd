## room_transition_manager_test.gd — Unit tests for RoomTransitionManager (LD-20).
##
## Coverage (pure state methods only — async transition requires full scene tree):
##   - setup() stores graph and derives current_idx from entry room
##   - get_graph() / get_current_room_idx() / is_transitioning() initial state
##   - wire_exit_doors() assigns destination_idx to doors in scene order
##   - wire_exit_doors() hides excess doors when scene has more doors than edges
##   - wire_exit_doors() is safe with null scene
##
## Node teardown: use .free() (not .queue_free()) — nodes not added to scene tree.
## RTM._ready() is NOT called (no scene tree); fade overlay not needed for state tests.
##
## Roadmap: design/level-design-roadmap.md (LD-20)
extends GdUnitTestSuite


# ── Helpers ────────────────────────────────────────────────────────────────────

## Builds a 5-room linear DungeonGraph: Combat×3 → Rest → Boss.
func _linear_graph() -> DungeonGraph:
	var g := DungeonGraph.new()
	for _i: int in range(3):
		g.add_room(DungeonGraph.ROOM_TYPE_COMBAT)
	g.add_room(DungeonGraph.ROOM_TYPE_REST)
	g.add_room(DungeonGraph.ROOM_TYPE_BOSS)
	for i: int in range(g.room_count() - 1):
		g.add_edge(i, i + 1)
	return g


## Creates a mock room Node with [param door_count] RoomExitDoor children.
func _mock_room(door_count: int) -> Node:
	var room := Node.new()
	for _i: int in range(door_count):
		room.add_child(RoomExitDoor.new())
	return room


# ── setup() ────────────────────────────────────────────────────────────────────

func test_setup_stores_graph() -> void:
	var rtm := RoomTransitionManager.new()
	var g := _linear_graph()
	rtm.setup(g)
	assert_object(rtm.get_graph()).is_same(g)
	rtm.free()


func test_setup_current_idx_is_entry_room() -> void:
	var rtm := RoomTransitionManager.new()
	var g := _linear_graph()
	rtm.setup(g)
	assert_int(rtm.get_current_room_idx()).is_equal(g.get_entry_room())
	rtm.free()


func test_setup_entry_room_is_zero_for_linear() -> void:
	var rtm := RoomTransitionManager.new()
	var g := _linear_graph()
	rtm.setup(g)
	assert_int(rtm.get_current_room_idx()).is_equal(0)
	rtm.free()


func test_initial_is_transitioning_is_false() -> void:
	var rtm := RoomTransitionManager.new()
	assert_bool(rtm.is_transitioning()).is_false()
	rtm.free()


func test_get_graph_null_before_setup() -> void:
	var rtm := RoomTransitionManager.new()
	assert_object(rtm.get_graph()).is_null()
	rtm.free()


func test_get_current_idx_minus_one_before_setup() -> void:
	var rtm := RoomTransitionManager.new()
	assert_int(rtm.get_current_room_idx()).is_equal(-1)
	rtm.free()


# ── wire_exit_doors() ──────────────────────────────────────────────────────────

func test_wire_exit_doors_assigns_destination_idx() -> void:
	var rtm := RoomTransitionManager.new()
	var g := _linear_graph()
	rtm.setup(g)
	# Entry room (idx 0) has 1 outgoing edge → room 1.
	var room: Node = _mock_room(1)
	rtm.wire_exit_doors(room)
	var door: RoomExitDoor = room.get_child(0) as RoomExitDoor
	assert_int(door.destination_idx).is_equal(1)
	room.free()
	rtm.free()


func test_wire_exit_doors_two_doors_at_branch_point() -> void:
	# 3-node graph: 0→1, 0→2 — entry room has 2 exits.
	var g := DungeonGraph.new()
	g.add_room(DungeonGraph.ROOM_TYPE_COMBAT)
	g.add_room(DungeonGraph.ROOM_TYPE_REST)
	g.add_room(DungeonGraph.ROOM_TYPE_BOSS)
	g.add_edge(0, 1)
	g.add_edge(0, 2)
	var rtm := RoomTransitionManager.new()
	rtm.setup(g)
	var room: Node = _mock_room(2)
	rtm.wire_exit_doors(room)
	assert_int((room.get_child(0) as RoomExitDoor).destination_idx).is_equal(1)
	assert_int((room.get_child(1) as RoomExitDoor).destination_idx).is_equal(2)
	room.free()
	rtm.free()


func test_wire_exit_doors_hides_excess_doors() -> void:
	var rtm := RoomTransitionManager.new()
	var g := _linear_graph()   # entry room has 1 outgoing edge
	rtm.setup(g)
	var room: Node = _mock_room(3)   # 3 doors, only 1 needed
	rtm.wire_exit_doors(room)
	assert_bool((room.get_child(1) as RoomExitDoor).visible).is_false()
	assert_bool((room.get_child(2) as RoomExitDoor).visible).is_false()
	room.free()
	rtm.free()


func test_wire_exit_doors_null_scene_no_crash() -> void:
	var rtm := RoomTransitionManager.new()
	var g := _linear_graph()
	rtm.setup(g)
	rtm.wire_exit_doors(null)
	assert_bool(true).is_true()
	rtm.free()


## GIVEN RTM set up with a linear graph, room has 1 door
## WHEN wire_exit_doors() wires the door to outgoing[0]
## THEN door.player_entered is connected to rtm.request_transition
func test_wire_exit_doors_connects_player_entered_to_request_transition() -> void:
	var rtm := RoomTransitionManager.new()
	var g := _linear_graph()
	rtm.setup(g)
	var room: Node = _mock_room(1)
	rtm.wire_exit_doors(room)
	var door: RoomExitDoor = room.get_child(0) as RoomExitDoor
	assert_bool(door.player_entered.is_connected(rtm.request_transition)).is_true()
	room.free()
	rtm.free()


## GIVEN RTM wires exit doors twice (idempotent call)
## WHEN wire_exit_doors() is called a second time on the same door
## THEN player_entered has exactly 1 connection to request_transition (no duplicate)
func test_wire_exit_doors_idempotent_no_duplicate_connections() -> void:
	var rtm := RoomTransitionManager.new()
	var g := _linear_graph()
	rtm.setup(g)
	var room: Node = _mock_room(1)
	rtm.wire_exit_doors(room)
	rtm.wire_exit_doors(room)
	var door: RoomExitDoor = room.get_child(0) as RoomExitDoor
	assert_bool(door.player_entered.is_connected(rtm.request_transition)).is_true()
	# Count connections to request_transition via untyped array to avoid Array[Dictionary] cast issues.
	var connections: Array = door.player_entered.get_connections()
	var rtm_conn_count: int = 0
	for conn in connections:
		var callable: Callable = (conn as Dictionary).get("callable", Callable())
		if callable == Callable(rtm, "request_transition"):
			rtm_conn_count += 1
	assert_int(rtm_conn_count).is_equal(1)
	room.free()
	rtm.free()
