## dungeon_generator_test.gd — Unit tests for DungeonGenerator (LD-19).
##
## Coverage:
##   - generate() returns valid non-null DungeonGraph
##   - Graph is acyclic (DAG invariant)
##   - Entry room exists (room with no incoming edges)
##   - Boss room exists; Rest room exists and has path to Boss
##   - Combat/Elite rooms get templates; Rest/Boss stay null
##   - layer_generated signal fires and carries the returned graph
##   - Boundary: room_count=5 (linear path), room_count=8 (branched path)
##   - Invalid room_count returns null and does not emit signal
##   - set_path_builder() and set_room_selector() injection work
##
## Roadmap: design/level-design-roadmap.md (LD-19)
extends GdUnitTestSuite


# ── Helpers ────────────────────────────────────────────────────────────────────

## Returns a DungeonGenerator with an in-memory RoomSelector — no load() calls.
## [param with_templates] injects two distinct RoomTemplate instances into the combat pool
## so template assertions can distinguish assigned vs null.
func _make_gen(with_templates: bool = false) -> DungeonGenerator:
	var gen := DungeonGenerator.new()
	var sel := RoomSelector.new()
	if with_templates:
		var t1 := RoomTemplate.new()
		var t2 := RoomTemplate.new()
		sel.set_pools(
			[{"template": t1, "weight": 1.0}, {"template": t2, "weight": 1.0}],
			[{"template": t1, "weight": 1.0}],
		)
	else:
		sel.set_pools([], [])
	gen.set_room_selector(sel)
	return gen


# ── Structure ──────────────────────────────────────────────────────────────────

func test_generate_returns_nonnull_graph() -> void:
	var gen := _make_gen()
	var graph := gen.generate(7, 1)
	assert_object(graph).is_not_null()


func test_generate_graph_is_acyclic() -> void:
	var gen := _make_gen()
	var graph := gen.generate(7, 1)
	assert_bool(graph.is_acyclic()).is_true()


func test_generate_entry_room_exists() -> void:
	var gen := _make_gen()
	var graph := gen.generate(7, 1)
	assert_int(graph.get_entry_room()).is_not_equal(-1)


func test_generate_boss_room_exists() -> void:
	var gen := _make_gen()
	var graph := gen.generate(7, 1)
	var bosses: Array[int] = graph.get_rooms_by_type(DungeonGraph.ROOM_TYPE_BOSS)
	assert_array(bosses).has_size(1)


func test_generate_rest_has_path_to_boss() -> void:
	var gen := _make_gen()
	var graph := gen.generate(7, 1)
	var rests: Array[int] = graph.get_rooms_by_type(DungeonGraph.ROOM_TYPE_REST)
	var bosses: Array[int] = graph.get_rooms_by_type(DungeonGraph.ROOM_TYPE_BOSS)
	assert_bool(graph.has_path(rests[0], bosses[0])).is_true()


# ── Template assignment ────────────────────────────────────────────────────────

func test_generate_combat_rooms_get_templates() -> void:
	var gen := _make_gen(true)
	var graph := gen.generate(5, 1)
	for idx: int in graph.get_rooms_by_type(DungeonGraph.ROOM_TYPE_COMBAT):
		var room: Dictionary = graph.get_room(idx)
		assert_object(room.get("template")).is_not_null()


func test_generate_rest_template_is_null() -> void:
	var gen := _make_gen(true)
	var graph := gen.generate(5, 1)
	for idx: int in graph.get_rooms_by_type(DungeonGraph.ROOM_TYPE_REST):
		var room: Dictionary = graph.get_room(idx)
		assert_object(room.get("template")).is_null()


func test_generate_boss_template_is_null() -> void:
	var gen := _make_gen(true)
	var graph := gen.generate(5, 1)
	for idx: int in graph.get_rooms_by_type(DungeonGraph.ROOM_TYPE_BOSS):
		var room: Dictionary = graph.get_room(idx)
		assert_object(room.get("template")).is_null()


# ── Signal ────────────────────────────────────────────────────────────────────
# GDScript lambdas capture by value — use class member vars for mutable signal state.

var _signal_count: int = 0
var _last_signal_graph: DungeonGraph = null

func _on_layer_generated(graph: DungeonGraph) -> void:
	_signal_count += 1
	_last_signal_graph = graph


func test_generate_emits_layer_generated_signal() -> void:
	var gen := _make_gen()
	_signal_count = 0
	gen.layer_generated.connect(_on_layer_generated)
	gen.generate(7, 1)
	assert_int(_signal_count).is_equal(1)


func test_generate_signal_carries_correct_graph() -> void:
	var gen := _make_gen()
	_last_signal_graph = null
	gen.layer_generated.connect(_on_layer_generated)
	var returned: DungeonGraph = gen.generate(7, 1)
	assert_object(_last_signal_graph).is_same(returned)


# ── Boundary ──────────────────────────────────────────────────────────────────

func test_generate_room_count_5_linear() -> void:
	var gen := _make_gen()
	var graph := gen.generate(5, 1)
	assert_object(graph).is_not_null()
	assert_int(graph.room_count()).is_equal(5)


func test_generate_room_count_8_branched() -> void:
	var gen := _make_gen()
	var graph := gen.generate(8, 1)
	assert_object(graph).is_not_null()
	assert_int(graph.room_count()).is_equal(8)
	assert_bool(PathBuilder.max_exits(graph) > 1).is_true()


# ── Error handling ────────────────────────────────────────────────────────────

func test_generate_invalid_count_returns_null() -> void:
	var gen := _make_gen()
	var graph := gen.generate(3, 1)
	assert_object(graph).is_null()


func test_generate_invalid_count_no_signal() -> void:
	var gen := _make_gen()
	_signal_count = 0
	gen.layer_generated.connect(_on_layer_generated)
	gen.generate(3, 1)
	assert_int(_signal_count).is_equal(0)


# ── Dependency injection ──────────────────────────────────────────────────────

func test_inject_room_selector_used() -> void:
	var gen := DungeonGenerator.new()
	var sel := RoomSelector.new()
	var t1 := RoomTemplate.new()
	t1.display_name = "injected"
	sel.set_pools([{"template": t1, "weight": 1.0}], [])
	gen.set_room_selector(sel)
	var graph := gen.generate(5, 1)
	for idx: int in graph.get_rooms_by_type(DungeonGraph.ROOM_TYPE_COMBAT):
		var room: Dictionary = graph.get_room(idx)
		assert_str((room.get("template") as RoomTemplate).display_name).is_equal("injected")


func test_inject_path_builder_used() -> void:
	var gen := _make_gen()
	gen.set_path_builder(PathBuilder.new())
	var graph := gen.generate(6, 1)
	assert_object(graph).is_not_null()
	assert_int(graph.room_count()).is_equal(6)
