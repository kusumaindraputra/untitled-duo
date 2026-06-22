## room_selector_variety_test.gd — Unit tests for RoomSelector's variety window (LD-18).
##
## The variety window strengthens the original "no back-to-back repeat" rule into a
## rolling window: with the default variety_window of 2, any three consecutive rooms
## drawn from a pool of 3+ templates are all distinct shapes — the core diversity
## guarantee for a generated floor.
##
## Coverage:
##   - Default variety_window is 2
##   - With window 2 and a 3-template pool, no template repeats within any 3-room run
##   - window 1 reduces to the legacy no-consecutive-repeat behavior
##   - Single-template pool still reuses (window clamped to pool.size()-1 = 0)
##   - All templates still appear over many runs (window does not starve any template)
##
## Roadmap: design/level-design-roadmap.md (LD-18)
extends GdUnitTestSuite

const TemplateDiamond  = preload("res://assets/data/room_templates/template_diamond.tres")
const TemplateSplit    = preload("res://assets/data/room_templates/template_split.tres")
const TemplateCorridor = preload("res://assets/data/room_templates/template_corridor.tres")


func _combat_graph(combat_count: int) -> DungeonGraph:
	var g := DungeonGraph.new()
	for _i: int in range(combat_count):
		g.add_room(DungeonGraph.ROOM_TYPE_COMBAT)
	for i: int in range(g.room_count() - 1):
		g.add_edge(i, i + 1)
	return g


func _three_template_pool() -> Array[Dictionary]:
	return [
		{"template": TemplateDiamond,  "weight": 1.0},
		{"template": TemplateSplit,    "weight": 1.0},
		{"template": TemplateCorridor, "weight": 1.0},
	]


# ── Default window ───────────────────────────────────────────────────────────

func test_room_selector_default_variety_window_is_2() -> void:
	# Arrange / Act
	var sel := RoomSelector.new()
	# Assert
	assert_int(sel.variety_window).is_equal(2)


# ── Window 2: no repeat within any 3-room run ─────────────────────────────────

func test_room_selector_window_2_no_repeat_within_three_rooms() -> void:
	# Arrange
	var sel := RoomSelector.new()
	sel.variety_window = 2
	sel.set_pools(_three_template_pool(), [])
	# Act / Assert — structural over many runs, not a single lucky draw.
	for _run: int in range(40):
		var g: DungeonGraph = _combat_graph(6)
		sel.assign(g)
		for i: int in range(2, 6):
			var a: RoomTemplate = sel.last_assigned_template(i - 2)
			var b: RoomTemplate = sel.last_assigned_template(i - 1)
			var c: RoomTemplate = sel.last_assigned_template(i)
			assert_bool(a != b and b != c and a != c) \
				.override_failure_message(
					"Templates repeated within 3-room window at rooms %d-%d" % [i - 2, i]) \
				.is_true()


# ── Window 1: legacy behavior (only avoid immediate previous) ─────────────────

func test_room_selector_window_1_allows_repeat_two_apart() -> void:
	# Arrange — window 1 means only back-to-back repeats are forbidden.
	var sel := RoomSelector.new()
	sel.variety_window = 1
	sel.set_pools(_three_template_pool(), [])
	# Act / Assert — no two ADJACENT rooms share a template, ever.
	for _run: int in range(20):
		var g: DungeonGraph = _combat_graph(6)
		sel.assign(g)
		for i: int in range(1, 6):
			assert_bool(sel.last_assigned_template(i - 1) != sel.last_assigned_template(i)) \
				.is_true()


# ── Single-template pool: window clamps to 0, reuse allowed ───────────────────

func test_room_selector_single_template_pool_reuses_under_window_2() -> void:
	# Arrange
	var sel := RoomSelector.new()
	sel.variety_window = 2
	sel.set_pools([{"template": TemplateDiamond, "weight": 1.0}], [])
	var g: DungeonGraph = _combat_graph(3)
	# Act
	sel.assign(g)
	# Assert — only one option, so every room is Diamond (no crash, no starvation).
	for i: int in range(3):
		assert_object(sel.last_assigned_template(i)).is_equal(TemplateDiamond)


# ── No starvation: all templates still appear ─────────────────────────────────

func test_room_selector_window_2_all_templates_eventually_used() -> void:
	# Arrange
	var sel := RoomSelector.new()
	sel.variety_window = 2
	sel.set_pools(_three_template_pool(), [])
	var seen: Dictionary = {}
	# Act
	for _run: int in range(50):
		var g: DungeonGraph = _combat_graph(6)
		sel.assign(g)
		for i: int in range(6):
			seen[str(sel.last_assigned_template(i).display_name)] = true
		if seen.size() == 3:
			break
	# Assert
	assert_int(seen.size()).is_equal(3)
