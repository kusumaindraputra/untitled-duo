## combat_hud_floor_map_test.gd — Floor node map in the HUD (beta plan U4).
##
## Coverage:
##   U4-01: a straight chain lays out one room per column on the same row
##   U4-02: a fork puts both branches in the same column on different rows, the merge after
##   U4-03: a room the entry cannot reach goes to column 0 without breaking the layout
##   U4-04: layout_size grows with columns and rows
##   U4-05: set_minimap with edges shows the node map and reports its bottom edge
##   U4-06: set_minimap without edges keeps the marker strip (no node map)
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const CombatHUDScript = preload("res://src/ui/combat_hud.gd")


func _make_hud() -> Node:
	var hud: Node = CombatHUDScript.new()
	add_child(hud)
	hud.set_process(false)
	return hud


func _teardown_hud(hud: Node) -> void:
	remove_child(hud)
	hud.free()


func test_floor_map_chain_is_one_row() -> void:
	var cells: Array[Vector2i] = FloorMap.compute_layout(3, [Vector2i(0, 1), Vector2i(1, 2)], 0)

	assert_int(cells[0].x).is_equal(0)
	assert_int(cells[1].x).is_equal(1)
	assert_int(cells[2].x).is_equal(2)
	assert_int(cells[0].y).is_equal(cells[2].y)


func test_floor_map_fork_shares_column_and_merge_follows() -> void:
	var edges: Array = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 4), Vector2i(3, 4)]

	var cells: Array[Vector2i] = FloorMap.compute_layout(5, edges, 0)

	assert_int(cells[2].x).is_equal(2)
	assert_int(cells[3].x).is_equal(2)
	assert_int(cells[2].y).is_not_equal(cells[3].y)
	assert_int(cells[4].x).is_equal(3)


func test_floor_map_uneven_branches_merge_after_the_longer_one() -> void:
	# 0 → 1 → 2 → 4 and 0 → 3 → 4: the merge sits after the longer branch.
	var edges: Array = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 4), Vector2i(0, 3), Vector2i(3, 4)]

	var cells: Array[Vector2i] = FloorMap.compute_layout(5, edges, 0)

	assert_int(cells[4].x).is_equal(3)


func test_floor_map_unreachable_room_goes_to_first_column() -> void:
	var cells: Array[Vector2i] = FloorMap.compute_layout(3, [Vector2i(0, 1)], 0)

	assert_int(cells.size()).is_equal(3)
	assert_int(cells[2].x).is_equal(0)


func test_floor_map_layout_size_grows_with_columns_and_rows() -> void:
	var one: Vector2 = FloorMap.layout_size(FloorMap.compute_layout(1, [], 0))
	var fork: Vector2 = FloorMap.layout_size(FloorMap.compute_layout(4,
		[Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 3), Vector2i(2, 3)], 0))

	assert_float(fork.x).is_greater(one.x)
	assert_float(fork.y).is_greater(one.y)


func test_set_minimap_with_edges_shows_node_map() -> void:
	var hud: Node = _make_hud()

	hud.set_minimap([0, 0, 1, 3], [1, 0, 0, 0], 0, [], [Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 3), Vector2i(2, 3)], 0)

	assert_object(hud._floor_map).is_not_null()
	assert_bool(hud._floor_map.visible).is_true()
	assert_int(hud._minimap_markers.size()).is_equal(0)
	assert_float(hud.get_floor_map_bottom()).is_greater(0.0)
	_teardown_hud(hud)


func test_set_minimap_without_edges_keeps_marker_strip() -> void:
	var hud: Node = _make_hud()

	hud.set_minimap([0, 0, 3], [1, 0, 0], 0)

	assert_int(hud._minimap_markers.size()).is_equal(3)
	assert_float(hud.get_floor_map_bottom()).is_equal(0.0)
	_teardown_hud(hud)
