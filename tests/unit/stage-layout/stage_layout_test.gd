## stage_layout_test.gd — floor themes, new room shapes, pillar placement (ADR-0020).
extends GdUnitTestSuite

const ROOM_SCENE: PackedScene = preload("res://src/scenes/IsometricRoom.tscn")
const THEME_PATHS: Array[String] = [
	"res://assets/data/floor_themes/floor_theme_1.tres",
	"res://assets/data/floor_themes/floor_theme_2.tres",
	"res://assets/data/floor_themes/floor_theme_3.tres",
]


func _grid(n: int, step: float) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for x: int in range(-n, n + 1):
		for y: int in range(-n, n + 1):
			pts.append(Vector2(x, y) * step)
	return pts


func _all_templates(theme: FloorTheme) -> Array[RoomTemplate]:
	var all: Array[RoomTemplate] = []
	all.append_array(theme.combat_templates)
	all.append_array(theme.elite_templates)
	all.append_array(theme.rest_templates)
	all.append_array(theme.boss_templates)
	return all


# ── pick_spread_positions ────────────────────────────────────────────────────

func test_pick_spread_respects_every_clearance() -> void:
	var avoid: Array[Vector2] = [Vector2(100, 100)]
	var picks: Array[Vector2] = IsometricRoom.pick_spread_positions(
		_grid(10, 32.0), 6, avoid, 120.0, 150.0, 90.0, 7)
	assert_int(picks.size()).is_greater(0)
	for i: int in picks.size():
		assert_float(picks[i].length()).is_greater_equal(90.0)
		assert_float(picks[i].distance_to(avoid[0])).is_greater_equal(120.0)
		for j: int in range(i + 1, picks.size()):
			assert_float(picks[i].distance_to(picks[j])).is_greater_equal(150.0)


func test_pick_spread_is_deterministic_for_a_seed() -> void:
	var none: Array[Vector2] = []
	var a: Array[Vector2] = IsometricRoom.pick_spread_positions(_grid(8, 32.0), 4, none, 0.0, 100.0, 0.0, 42)
	var b: Array[Vector2] = IsometricRoom.pick_spread_positions(_grid(8, 32.0), 4, none, 0.0, 100.0, 0.0, 42)
	assert_array(a).is_equal(b)


func test_pick_spread_returns_fewer_when_space_runs_out() -> void:
	var none: Array[Vector2] = []
	var picks: Array[Vector2] = IsometricRoom.pick_spread_positions(_grid(1, 10.0), 5, none, 0.0, 1000.0, 0.0, 1)
	assert_int(picks.size()).is_equal(1)
	assert_int(IsometricRoom.pick_spread_positions(_grid(3, 10.0), 0, none, 0.0, 0.0, 0.0, 1).size()).is_equal(0)


# ── FloorTheme ───────────────────────────────────────────────────────────────

func test_to_pool_skips_nulls_and_defaults_weights() -> void:
	var t := RoomTemplate.new()
	var templates: Array[RoomTemplate] = [t, null, t]
	var weights: Array[float] = [2.0]
	var pool: Array[Dictionary] = FloorTheme.to_pool(templates, weights)
	assert_int(pool.size()).is_equal(2)
	assert_float(float(pool[0]["weight"])).is_equal(2.0)
	assert_float(float(pool[1]["weight"])).is_equal(1.0)


func test_apply_to_replaces_selector_pools() -> void:
	var theme := FloorTheme.new()
	var t := RoomTemplate.new()
	theme.combat_templates = [t]
	theme.combat_weights = [3.0]
	var sel := RoomSelector.new()
	theme.apply_to(sel)
	assert_int(sel.get_combat_pool().size()).is_equal(1)
	assert_object(sel.get_combat_pool()[0]["template"]).is_same(t)
	assert_int(sel.get_elite_pool().size()).is_equal(0)


func test_every_floor_theme_has_all_room_types() -> void:
	for path: String in THEME_PATHS:
		var theme: FloorTheme = load(path) as FloorTheme
		assert_object(theme).is_not_null()
		assert_int(theme.combat_templates.size()).is_greater(0)
		assert_int(theme.elite_templates.size()).is_greater(0)
		assert_int(theme.rest_templates.size()).is_greater(0)
		assert_int(theme.boss_templates.size()).is_greater(0)
		for t: RoomTemplate in _all_templates(theme):
			assert_object(t).is_not_null()


func test_floor_two_and_three_draw_rooms_floor_one_never_uses() -> void:
	var f1: FloorTheme = load(THEME_PATHS[0])
	for idx: int in [1, 2]:
		var theme: FloorTheme = load(THEME_PATHS[idx])
		var fresh: int = 0
		for t: RoomTemplate in theme.combat_templates:
			if not f1.combat_templates.has(t):
				fresh += 1
		assert_int(fresh).is_greater_equal(3)
		assert_bool(f1.boss_templates.has(theme.boss_templates[0])).is_false()


func test_later_floors_have_hazards_in_most_combat_rooms() -> void:
	for idx: int in [1, 2]:
		var theme: FloorTheme = load(THEME_PATHS[idx])
		var with_hazards: int = 0
		for t: RoomTemplate in theme.combat_templates:
			if not t.hazards.is_empty():
				with_hazards += 1
		assert_int(with_hazards).is_greater_equal(theme.combat_templates.size() - 1)


func test_turret_hazards_all_have_a_pattern() -> void:
	for path: String in THEME_PATHS:
		for t: RoomTemplate in _all_templates(load(path) as FloorTheme):
			for h: HazardSpec in t.hazards:
				if h.kind == HazardSpec.Kind.TURRET:
					assert_object(h.pattern).is_not_null()


func test_generator_uses_theme_pools() -> void:
	var gen := DungeonGenerator.new()
	var theme: FloorTheme = load(THEME_PATHS[2])
	gen.apply_floor_theme(theme)
	var graph: DungeonGraph = gen.generate(7, 3)
	var allowed: Array[RoomTemplate] = _all_templates(theme)
	for i: int in graph.room_count():
		var tmpl: RoomTemplate = graph.get_room(i).get("template") as RoomTemplate
		assert_bool(allowed.has(tmpl)).is_true()


# ── Rooms built in the tree ──────────────────────────────────────────────────

func _build(tmpl: RoomTemplate, theme: FloorTheme = null) -> IsometricRoom:
	var room: IsometricRoom = ROOM_SCENE.instantiate()
	room.room_template = tmpl
	room.floor_theme = theme
	add_child(room)
	return room


func _destroy(room: IsometricRoom) -> void:
	remove_child(room)
	room.free()


func _layout_template(style: int) -> RoomTemplate:
	var t := RoomTemplate.new()
	t.layout_style = style
	return t


func test_ring_layout_has_walled_core() -> void:
	var room := _build(_layout_template(5))
	var tm: TileMapLayer = room.get_node("TileMapLayer")
	assert_int(tm.get_cell_source_id(tm.local_to_map(Vector2.ZERO))).is_equal(-1)
	assert_int(tm.get_used_cells().size()).is_greater(300)
	_destroy(room)


func test_cross_layout_cuts_corners_and_keeps_hub() -> void:
	var room := _build(_layout_template(6))
	var tm: TileMapLayer = room.get_node("TileMapLayer")
	assert_int(tm.get_cell_source_id(tm.local_to_map(Vector2.ZERO))).is_not_equal(-1)
	# A point in the diagonal corner of the diamond, outside both arms.
	assert_int(tm.get_cell_source_id(tm.local_to_map(Vector2(300, 150)))).is_equal(-1)
	_destroy(room)


func test_every_theme_room_places_pillars_on_floor_clear_of_spawns() -> void:
	for path: String in THEME_PATHS:
		var theme: FloorTheme = load(path)
		for t: RoomTemplate in _all_templates(theme):
			var room := _build(t, theme)
			var tm: TileMapLayer = room.get_node("TileMapLayer")
			var cfg: ObstacleConfig = t.obstacle_config
			var pillars: Array[CoverPillar] = []
			for ch: Node in room.get_children():
				if ch is CoverPillar:
					pillars.append(ch as CoverPillar)
			assert_int(pillars.size()).is_less_equal(cfg.pillar_count_max)
			for p: CoverPillar in pillars:
				assert_int(tm.get_cell_source_id(tm.local_to_map(p.position))).is_not_equal(-1)
				for m: Vector2 in room.get_spawn_markers():
					assert_float(p.position.distance_to(m)).is_greater_equal(120.0)
			var holder: Node = room.get_node_or_null("Hazards")
			var built: int = holder.get_child_count() if holder != null else 0
			assert_int(built).is_equal(t.hazards.size())
			_destroy(room)


func test_rest_room_has_no_pillars() -> void:
	var t: RoomTemplate = load("res://assets/data/room_templates/template_rest.tres")
	var room := _build(t)
	for ch: Node in room.get_children():
		assert_bool(ch is CoverPillar).is_false()
	_destroy(room)


func test_floor_theme_tints_tiles() -> void:
	var theme: FloorTheme = load(THEME_PATHS[1])
	var room := _build(_layout_template(0), theme)
	assert_object(room.get_node("TileMapLayer").modulate).is_equal(theme.floor_tint)
	_destroy(room)


func test_hud_floor_label_uses_floor_names() -> void:
	assert_str(CombatHUD.floor_label_text(2)).contains("2")
	assert_str(CombatHUD.floor_label_text(2)).contains(CombatHUD.floor_name(2))
	assert_str(CombatHUD.floor_name(99)).is_equal("")
	assert_str(CombatHUD.floor_label_text(99)).is_equal("Floor 99")
