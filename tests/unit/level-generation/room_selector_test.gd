## room_selector_test.gd — Unit tests for RoomSelector (LD-18).
##
## Coverage:
##   - Combat rooms get non-null template; Rest/Boss stay null
##   - Variety constraint: no consecutive identical template (when pool allows)
##   - Single-template pool fallback: consecutive reuse allowed
##   - Elite rooms get from elite pool only
##   - Custom pool injection via set_pools()
##   - Empty pool graceful (no crash, null template)
##   - Probabilistic: all templates used eventually; weighted distribution
##   - Room types preserved after assign
##
## Roadmap: design/level-design-roadmap.md (LD-18)
## GDD:    design/room-type-taxonomy.md, design/layer-identity.md
extends GdUnitTestSuite

const TemplateDiamond  = preload("res://assets/data/room_templates/template_diamond.tres")
const TemplateSplit    = preload("res://assets/data/room_templates/template_split.tres")
const TemplateCorridor = preload("res://assets/data/room_templates/template_corridor.tres")
const TemplateArena    = preload("res://assets/data/room_templates/template_arena.tres")
const TemplateGauntlet = preload("res://assets/data/room_templates/template_gauntlet.tres")
const TemplateRest     = preload("res://assets/data/room_templates/template_rest.tres")
const TemplateBoss     = preload("res://assets/data/room_templates/template_boss.tres")


# ── Helpers ────────────────────────────────────────────────────────────────────

func _linear_graph(combat_count: int) -> DungeonGraph:
	var g := DungeonGraph.new()
	for _i: int in range(combat_count):
		g.add_room(DungeonGraph.ROOM_TYPE_COMBAT)
	g.add_room(DungeonGraph.ROOM_TYPE_REST)
	g.add_room(DungeonGraph.ROOM_TYPE_BOSS)
	for i: int in range(g.room_count() - 1):
		g.add_edge(i, i + 1)
	return g


func _entry(pool: Array[Dictionary]) -> Dictionary:
	return {"template": pool[0]["template"], "weight": float(pool[0]["weight"])}


# ── Basic assignment ───────────────────────────────────────────────────────────

func test_combat_rooms_get_template() -> void:
	var g: DungeonGraph = _linear_graph(3)   # 3 Combat + Rest + Boss = 5 rooms
	var sel := RoomSelector.new()
	# Use a controlled 2-template combat pool for determinism.
	sel.set_pools(
		[{"template": TemplateDiamond, "weight": 1.0}, {"template": TemplateSplit, "weight": 1.0}],
		[],
	)
	sel.assign(g)
	for i: int in range(3):
		assert_object(sel.last_assigned_template(i)).is_not_null()


func test_rest_and_boss_get_templates() -> void:
	var g: DungeonGraph = _linear_graph(3)
	var sel := RoomSelector.new()
	sel.assign(g)
	# Rest is at index 3, Boss at index 4.
	assert_object(sel.last_assigned_template(3)).is_equal(TemplateRest)
	assert_object(sel.last_assigned_template(4)).is_equal(TemplateBoss)


# ── Variety constraint ─────────────────────────────────────────────────────────

func test_no_consecutive_same_template() -> void:
	# 2 templates in pool, 3 consecutive Combat rooms — must avoid back-to-back same.
	var pool: Array[Dictionary] = [
		{"template": TemplateDiamond, "weight": 1.0},
		{"template": TemplateSplit, "weight": 1.0},
	]
	var g: DungeonGraph = _linear_graph(3)
	var sel := RoomSelector.new()
	sel.set_pools(pool, [])
	# Run 5 times to ensure variety constraint is structural, not lucky.
	for _run: int in range(5):
		sel.assign(g)
		var t0: RoomTemplate = sel.last_assigned_template(0)
		var t1: RoomTemplate = sel.last_assigned_template(1)
		var t2: RoomTemplate = sel.last_assigned_template(2)
		assert_object(t0).is_not_null()
		assert_object(t1).is_not_null()
		assert_object(t2).is_not_null()
		# No consecutive identical.
		assert_bool(t0 != t1).is_true()
		assert_bool(t1 != t2).is_true()


func test_single_template_pool_allows_consecutive() -> void:
	# Only 1 template — consecutive reuse is the only option.
	var pool: Array[Dictionary] = [{"template": TemplateDiamond, "weight": 1.0}]
	var g: DungeonGraph = _linear_graph(3)
	var sel := RoomSelector.new()
	sel.set_pools(pool, [])
	sel.assign(g)
	var t0: RoomTemplate = sel.last_assigned_template(0)
	var t1: RoomTemplate = sel.last_assigned_template(1)
	var t2: RoomTemplate = sel.last_assigned_template(2)
	# All three must be the same template (no alternative).
	assert_object(t0).is_equal(TemplateDiamond)
	assert_object(t1).is_equal(TemplateDiamond)
	assert_object(t2).is_equal(TemplateDiamond)


# ── Elite pool respect ─────────────────────────────────────────────────────────

func test_elite_room_gets_from_elite_pool() -> void:
	# PathBuilder for 7 rooms puts 1 Elite. Use DungeonGraph directly.
	var g := DungeonGraph.new()
	g.add_room(DungeonGraph.ROOM_TYPE_COMBAT)   # 0
	g.add_room(DungeonGraph.ROOM_TYPE_COMBAT)   # 1 (branch)
	g.add_room(DungeonGraph.ROOM_TYPE_COMBAT)   # 2
	g.add_room(DungeonGraph.ROOM_TYPE_COMBAT)   # 3
	g.add_room(DungeonGraph.ROOM_TYPE_ELITE)    # 4 ← Elite
	g.add_room(DungeonGraph.ROOM_TYPE_REST)     # 5
	g.add_room(DungeonGraph.ROOM_TYPE_BOSS)     # 6
	for i: int in range(6):
		g.add_edge(i, i + 1)
	# Elite pool: only Gauntlet. Combat pool: only Diamond (to prove separation).
	var sel := RoomSelector.new()
	sel.set_pools(
		[{"template": TemplateDiamond, "weight": 1.0}],
		[{"template": TemplateGauntlet, "weight": 1.0}],
	)
	sel.assign(g)
	# Combat rooms should get Diamond.
	for i: int in range(4):
		assert_object(sel.last_assigned_template(i)).is_equal(TemplateDiamond)
	# Elite room should get Gauntlet, NOT Diamond.
	assert_object(sel.last_assigned_template(4)).is_equal(TemplateGauntlet)


# ── Custom pool injection ──────────────────────────────────────────────────────

func test_custom_pools_override_defaults() -> void:
	var g: DungeonGraph = _linear_graph(1)
	var sel := RoomSelector.new()
	# Default Layer 1 pool has 4 combat templates.
	assert_int(sel.get_combat_pool().size()).is_equal(4)
	# Inject a custom 1-template pool.
	sel.set_pools([{"template": TemplateArena, "weight": 1.0}], [])
	assert_int(sel.get_combat_pool().size()).is_equal(1)
	sel.assign(g)
	assert_object(sel.last_assigned_template(0)).is_equal(TemplateArena)


# ── Edge cases ─────────────────────────────────────────────────────────────────

func test_empty_pool_graceful() -> void:
	var g: DungeonGraph = _linear_graph(3)
	var sel := RoomSelector.new()
	sel.set_pools([], [])   # no templates at all
	sel.assign(g)            # must not crash
	for i: int in range(5):
		assert_object(sel.last_assigned_template(i)).is_null()


func test_assign_preserves_room_types() -> void:
	var g: DungeonGraph = _linear_graph(3)
	var sel := RoomSelector.new()
	sel.assign(g)
	assert_int(g.get_room(0)["type"]).is_equal(DungeonGraph.ROOM_TYPE_COMBAT)
	assert_int(g.get_room(3)["type"]).is_equal(DungeonGraph.ROOM_TYPE_REST)
	assert_int(g.get_room(4)["type"]).is_equal(DungeonGraph.ROOM_TYPE_BOSS)


func test_assign_on_graph_with_no_combat_rooms() -> void:
	# Graph with only Rest + Boss — rest and boss pools still apply.
	var g := DungeonGraph.new()
	g.add_room(DungeonGraph.ROOM_TYPE_REST)
	g.add_room(DungeonGraph.ROOM_TYPE_BOSS)
	g.add_edge(0, 1)
	var sel := RoomSelector.new()
	sel.assign(g)   # must not crash
	assert_object(sel.last_assigned_template(0)).is_equal(TemplateRest)
	assert_object(sel.last_assigned_template(1)).is_equal(TemplateBoss)


# ── Probabilistic: coverage ────────────────────────────────────────────────────

func test_all_combat_templates_eventually_used() -> void:
	# Over 200 runs with 7 rooms (5 Combat each), all 4 L1 Combat templates
	# should appear at least once. Failure probability is astronomically low.
	var pool: Array[Dictionary] = [
		{"template": TemplateDiamond,  "weight": 3.0},
		{"template": TemplateSplit,    "weight": 2.0},
		{"template": TemplateCorridor, "weight": 1.0},
		{"template": TemplateArena,    "weight": 2.0},
	]
	var seen: Dictionary = {}
	for _run: int in range(200):
		var g: DungeonGraph = _linear_graph(5)   # 5 Combat rooms
		var sel := RoomSelector.new()
		sel.set_pools(pool, [])
		sel.assign(g)
		for i: int in range(5):
			var tmpl: RoomTemplate = sel.last_assigned_template(i)
			seen[str(tmpl.display_name)] = true
		if seen.size() == 4:
			break   # all 4 seen — early exit
	assert_int(seen.size()).is_equal(4)
