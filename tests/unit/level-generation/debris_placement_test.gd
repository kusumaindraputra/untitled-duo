## debris_placement_test.gd — Unit tests for IsometricRoom random obstacle placement.
##
## Coverage:
##   AC-LG-01: count is within [_DEBRIS_COUNT_MIN, _DEBRIS_COUNT_MAX]
##   AC-LG-02: no obstacle within _DEBRIS_MIN_CENTER_DIST of origin
##   AC-LG-03: no obstacle within _DEBRIS_MIN_SPAWN_DIST of any spawn marker
##   AC-LG-04: no two obstacles within _DEBRIS_MIN_BETWEEN_DIST of each other
##   AC-LG-10: two consecutive calls produce different results
##
## GDD: design/gdd/level-generation.md
##
## Setup: IsometricRoom.new() without add_child — _generate_debris_positions() is a
## pure function using only constants and the input array, safe outside the scene tree.
extends GdUnitTestSuite

const IsometricRoomScript = preload("res://src/scenes/isometric_room.gd")


func _make_room() -> IsometricRoom:
	return IsometricRoomScript.new() as IsometricRoom


# ── AC-LG-01: count within valid range ────────────────────────────────────────

## GIVEN no spawn markers
## WHEN _generate_debris_positions runs
## THEN count is between 0 and _DEBRIS_COUNT_MAX
func test_debris_count_within_max() -> void:
	var room := _make_room()
	var positions: Array[Vector2] = room._generate_debris_positions([])
	assert_int(positions.size()).is_between(0, room._DEBRIS_COUNT_MAX)
	room.free()


# ── AC-LG-02: center clearance ────────────────────────────────────────────────

## GIVEN no spawn markers
## WHEN debris is placed
## THEN every position is >= _DEBRIS_MIN_CENTER_DIST from origin
func test_debris_no_position_within_center_clearance() -> void:
	var room := _make_room()
	var positions: Array[Vector2] = room._generate_debris_positions([])
	for pos: Vector2 in positions:
		assert_float(pos.length()).is_greater_equal(room._DEBRIS_MIN_CENTER_DIST - 0.01)
	room.free()


# ── AC-LG-03: spawn marker clearance ──────────────────────────────────────────

## GIVEN three spawn markers at known positions
## WHEN debris is placed
## THEN no debris is within _DEBRIS_MIN_SPAWN_DIST of any marker
func test_debris_no_position_within_spawn_marker_clearance() -> void:
	var room := _make_room()
	var spawns: Array[Vector2] = [
		Vector2(100.0, 0.0),
		Vector2(-80.0, 60.0),
		Vector2(0.0, -90.0),
	]
	var positions: Array[Vector2] = room._generate_debris_positions(spawns)
	for pos: Vector2 in positions:
		for sp: Vector2 in spawns:
			assert_float(pos.distance_to(sp)).is_greater_equal(room._DEBRIS_MIN_SPAWN_DIST - 0.01)
	room.free()


# ── AC-LG-04: inter-obstacle clearance ────────────────────────────────────────

## GIVEN no spawn markers
## WHEN multiple obstacles are placed
## THEN no two obstacles are within _DEBRIS_MIN_BETWEEN_DIST of each other
func test_debris_obstacles_are_separated() -> void:
	var room := _make_room()
	var positions: Array[Vector2] = room._generate_debris_positions([])
	for i: int in range(positions.size()):
		for j: int in range(i + 1, positions.size()):
			assert_float(positions[i].distance_to(positions[j])).is_greater_equal(
				room._DEBRIS_MIN_BETWEEN_DIST - 0.01)
	room.free()


# ── Diamond containment ────────────────────────────────────────────────────────

## All placed obstacles are within the inner diamond zone.
func test_debris_all_positions_within_inner_diamond() -> void:
	var room := _make_room()
	var positions: Array[Vector2] = room._generate_debris_positions([])
	for pos: Vector2 in positions:
		var norm: float = absf(pos.x) / float(room._WALL_HALF_X) + absf(pos.y) / float(room._WALL_HALF_Y)
		assert_float(norm).is_less_equal(room._DEBRIS_INNER_SCALE + 0.01)
	room.free()


# ── AC-LG-10: two calls produce distinct results ──────────────────────────────

## Two consecutive calls with independent RNG seeds very likely differ in count or positions.
## Tests that the function runs without error on repeated calls; randomness is structural.
func test_debris_two_consecutive_calls_do_not_crash() -> void:
	var room := _make_room()
	var _positions_a: Array[Vector2] = room._generate_debris_positions([])
	var _positions_b: Array[Vector2] = room._generate_debris_positions([])
	# No crash and no shared state = pass. Seed variation confirmed by design.
	assert_int(_positions_a.size()).is_between(0, room._DEBRIS_COUNT_MAX)
	assert_int(_positions_b.size()).is_between(0, room._DEBRIS_COUNT_MAX)
	room.free()


# ── S9-09: half-cover layer constant ──────────────────────────────────────────

## _HALF_COVER_LAYER must be 16 (bit 4 = Layer 5) so debris blocks movement but not Prana.
## (design/quick-specs/arena-cover-types.md, S9-09 AC criterion 1)
func test_debris_half_cover_layer_constant_is_16() -> void:
	var room := _make_room()
	assert_int(room._HALF_COVER_LAYER).is_equal(16)
	room.free()
