## pause_panel_map_legend_test.gd — Larger floor map and legend on pause (ADR-0032).
##
## Coverage:
##   PM-01: a FloorMap snapshot rebuilds the same floor at another scale
##   PM-02: layout size grows with map_scale
##   PM-03: pause with map data shows the large map and a legend for rooms and threat icons
##   PM-04: pause without map data shows no map column
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const COPY: UICopy = preload("res://assets/data/ui_copy.tres")
const EDGES: Array = [Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 3), Vector2i(2, 3)]


func _hud_map() -> FloorMap:
	var m := FloorMap.new()
	m.type_colors.assign([Color.GRAY, Color.RED, Color.GREEN, Color.PURPLE])
	m.type_letters.assign(["C", "E", "R", "B"])
	m.mod_letters.assign(["", "!", "X"])
	m.mod_colors.assign([Color.TRANSPARENT, Color.WHITE, Color.PURPLE])
	m.set_floor([0, 1, 2, 3], [1, 0, 0, 0], [0, 1, 0, 0], EDGES, 0, 0)
	return m


func test_snapshot_rebuilds_same_floor_at_scale() -> void:
	var hud_map: FloorMap = _hud_map()

	var big: FloorMap = FloorMap.from_snapshot(hud_map.snapshot(), 1.5)

	assert_float(big.map_scale).is_equal(1.5)
	assert_array(big.snapshot()["types"]).is_equal([0, 1, 2, 3])
	assert_int(int(big.snapshot()["current"])).is_equal(0)
	assert_float(big.size.x).is_greater(hud_map.size.x)
	assert_float(big.node_center(3).x).is_greater(hud_map.node_center(3).x)
	hud_map.free()
	big.free()


func test_layout_size_grows_with_scale() -> void:
	var cells: Array[Vector2i] = FloorMap.compute_layout(4, EDGES, 0)

	assert_float(FloorMap.layout_size(cells, 1.5).x).is_greater(FloorMap.layout_size(cells, 1.0).x)
	assert_float(FloorMap.layout_size(cells, 1.5).y).is_greater(FloorMap.layout_size(cells, 1.0).y)


func test_empty_map_has_empty_snapshot() -> void:
	var m := FloorMap.new()
	assert_bool(m.snapshot().is_empty()).is_true()
	m.free()


func test_pause_shows_map_and_legend() -> void:
	var hud_map: FloorMap = _hud_map()
	var panel := PausePanel.new()
	add_child(panel)

	panel.setup({"map": hud_map.snapshot()})

	assert_object(panel.floor_map).is_not_null()
	assert_float(panel.floor_map.map_scale).is_equal(PausePanel.MAP_SCALE)
	for name: String in COPY.map_room_names:
		assert_array(panel.legend_texts).contains([name])
	assert_array(panel.legend_texts).contains([COPY.map_mod_names[1], COPY.map_mod_names[2], COPY.map_you_are_here])
	for name: String in COPY.threat_names:
		assert_array(panel.legend_texts).contains([name])
	remove_child(panel)
	panel.free()
	hud_map.free()


func test_pause_without_map_has_no_map() -> void:
	var panel := PausePanel.new()
	add_child(panel)

	panel.setup({})

	assert_object(panel.floor_map).is_null()
	assert_array(panel.legend_texts).is_empty()
	remove_child(panel)
	panel.free()
