## isometric_room_walls_test.gd — Arena boundary integration test.
##
## Verifies the programmatic arena walls (built in isometric_room.gd → _build_walls)
## match the filled floor tiles exactly, so the walkable area == the visible tiles:
## player and enemies can only move where there are tiles, nothing else is passable.
##
## Regression guard for the "walk-on-void" bug where the old smooth diamond wall
## (4 fixed SegmentShape2D at ±256/±192) enclosed area beyond the jagged tile edge.
##
## GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const ROOM_SCENE: PackedScene = preload("res://src/scenes/IsometricRoom.tscn")

## Tile half-extents (tile_size 64×32). Must match isometric_room.gd constants.
const TILE_X_STEP: int = 32
const TILE_Y_STEP: int = 16

## Tile diamond corner offsets relative to center: top, right, bottom, left.
const CORNER_OFFSETS: Array[Vector2] = [
	Vector2(0, -TILE_Y_STEP), Vector2(TILE_X_STEP, 0),
	Vector2(0, TILE_Y_STEP), Vector2(-TILE_X_STEP, 0),
]


## Order-independent edge key (mirrors the production helper, kept local so the test
## defines the expected boundary independently of the scene script internals).
func _edge_key(a: Vector2, b: Vector2) -> String:
	var pa := Vector2i(roundi(a.x), roundi(a.y))
	var pb := Vector2i(roundi(b.x), roundi(b.y))
	if pb.x < pa.x or (pb.x == pa.x and pb.y < pa.y):
		var tmp: Vector2i = pa
		pa = pb
		pb = tmp
	return "%d,%d-%d,%d" % [pa.x, pa.y, pb.x, pb.y]


func _make_room() -> IsometricRoom:
	var room: IsometricRoom = ROOM_SCENE.instantiate()
	add_child(room)
	auto_free(room)
	return room


func _wall_shape(room: IsometricRoom) -> ConcavePolygonShape2D:
	var bounds: StaticBody2D = room.get_node("ArenaBounds")
	assert_int(bounds.get_child_count()).is_equal(1)
	return (bounds.get_child(0) as CollisionShape2D).shape as ConcavePolygonShape2D


## GIVEN the arena scene, WHEN it loads, THEN the floor is filled with tiles.
func test_arena_floor_fills_diamond_tiles() -> void:
	var room := _make_room()
	var tilemap: TileMapLayer = room.get_node("TileMapLayer")
	assert_int(tilemap.get_used_cells().size()).is_greater(0)


## GIVEN the arena scene, WHEN it loads, THEN ArenaBounds carries exactly one
## ConcavePolygonShape2D collision shape with a non-empty, paired segment list.
func test_arena_walls_built_as_single_concave_shape() -> void:
	var room := _make_room()
	var shape := _wall_shape(room)
	assert_object(shape).is_not_null()
	assert_int(shape.segments.size()).is_greater(0)
	assert_int(shape.segments.size() % 2).is_equal(0)  # endpoint pairs


## GIVEN the filled tiles, WHEN walls are built, THEN the number of wall segments
## equals the number of tile-diamond edges that occur exactly once (region boundary,
## by definition) — no more, no less. Independently re-derived from the tile centers.
func test_arena_wall_segment_count_equals_tile_boundary_edges() -> void:
	var room := _make_room()
	var tilemap: TileMapLayer = room.get_node("TileMapLayer")

	var edge_count: Dictionary = {}
	for c: Vector2i in tilemap.get_used_cells():
		var center: Vector2 = tilemap.map_to_local(c)
		for i: int in range(4):
			var key: String = _edge_key(
				center + CORNER_OFFSETS[i], center + CORNER_OFFSETS[(i + 1) % 4])
			edge_count[key] = int(edge_count.get(key, 0)) + 1

	var expected_edges: int = 0
	for key: String in edge_count:
		if int(edge_count[key]) == 1:
			expected_edges += 1

	var shape := _wall_shape(room)
	assert_int(shape.segments.size() / 2).is_equal(expected_edges)


## GIVEN the wall segments, THEN each is exactly one isometric tile edge long
## (proves segments are real tile edges, not an arbitrary smooth outline).
func test_arena_each_wall_segment_is_one_tile_edge_long() -> void:
	var room := _make_room()
	var shape := _wall_shape(room)
	var edge_len: float = sqrt(float(TILE_X_STEP * TILE_X_STEP + TILE_Y_STEP * TILE_Y_STEP))
	var segs: PackedVector2Array = shape.segments
	var i: int = 0
	while i < segs.size():
		assert_float(segs[i].distance_to(segs[i + 1])).is_equal_approx(edge_len, 0.01)
		i += 2


## GIVEN the wall segments, THEN every vertex is shared by an even number of
## segments — the boundary is a watertight closed loop with no gap a body could
## slip through ("selain itu tidak bisa dilalui").
func test_arena_walls_form_watertight_closed_boundary() -> void:
	var room := _make_room()
	var shape := _wall_shape(room)
	var vertex_uses: Dictionary = {}
	for p: Vector2 in shape.segments:
		var key: String = "%d_%d" % [roundi(p.x), roundi(p.y)]
		vertex_uses[key] = int(vertex_uses.get(key, 0)) + 1
	for key: String in vertex_uses:
		assert_int(int(vertex_uses[key]) % 2).is_equal(0)
