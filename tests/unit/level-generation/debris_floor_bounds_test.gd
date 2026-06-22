## debris_floor_bounds_test.gd — Regression tests for on-floor obstacle placement (LD-02).
##
## Guards the out-of-bounds obstacle fix: debris is sampled from interior floor-tile
## centers (_generate_debris_on_floor) instead of free (x, y) against an approximate
## diamond/rect zone. Because every candidate is a real on-floor tile center, obstacles
## can never land outside the arena — the bug that existed for arena/corridor/split
## layouts, whose rectangular valid_zone_rects overshot the actual (shallower/narrower)
## floor.
##
## Coverage:
##   - Every placed obstacle is one of the supplied on-floor candidates (⇒ inside arena)
##   - Count never exceeds count_max
##   - min_center_dist from origin is respected
##   - min_between_dist between obstacles is respected
##   - min_spawn_dist from spawn markers is respected
##   - An extra zone_check filter is honored on top of the on-floor mask
##   - _interior_tile_centers returns empty without a tile map (graceful fallback)
##
## Setup: IsometricRoom.new() without add_child — the placement function is pure over
## its inputs and uses only the obstacle config, safe outside the scene tree.
extends GdUnitTestSuite

const IsometricRoomScript = preload("res://src/scenes/isometric_room.gd")


func _make_room() -> IsometricRoom:
	return IsometricRoomScript.new() as IsometricRoom


## A spread of on-floor candidate centers: all > 90px from origin, spaced > 75px apart,
## so the clearance constraints never reject the whole set.
func _candidates() -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for i: int in range(8):
		pts.append(Vector2(150.0 + float(i) * 100.0, 0.0))
		pts.append(Vector2(-150.0 - float(i) * 100.0, 0.0))
	return pts


func _candidate_set(candidates: Array[Vector2]) -> Dictionary:
	var s: Dictionary = {}
	for c: Vector2 in candidates:
		s[c] = true
	return s


# ── On-floor guarantee ────────────────────────────────────────────────────────

## GIVEN a set of on-floor candidate centers
## WHEN debris is generated from them
## THEN every placed position is one of those candidates (i.e. provably on the floor).
func test_debris_on_floor_all_positions_are_candidates() -> void:
	var room := _make_room()
	var candidates: Array[Vector2] = _candidates()
	var allowed: Dictionary = _candidate_set(candidates)
	var positions: Array[Vector2] = room._generate_debris_on_floor([], candidates)
	for pos: Vector2 in positions:
		assert_bool(allowed.has(pos)) \
			.override_failure_message("Obstacle at %s is not an on-floor candidate" % pos) \
			.is_true()
	room.free()


# ── Count cap ──────────────────────────────────────────────────────────────────

func test_debris_on_floor_count_within_max() -> void:
	var room := _make_room()
	var positions: Array[Vector2] = room._generate_debris_on_floor([], _candidates())
	assert_int(positions.size()).is_between(0, room._get_obstacle_config().count_max)
	room.free()


# ── Center clearance ─────────────────────────────────────────────────────────

func test_debris_on_floor_respects_center_clearance() -> void:
	var room := _make_room()
	# Inject a too-close candidate at the origin — it must never be chosen.
	var candidates: Array[Vector2] = _candidates()
	candidates.append(Vector2(20.0, 0.0))
	var min_center: float = room._get_obstacle_config().min_center_dist
	var positions: Array[Vector2] = room._generate_debris_on_floor([], candidates)
	for pos: Vector2 in positions:
		assert_float(pos.length()).is_greater_equal(min_center - 0.01)
	room.free()


# ── Inter-obstacle clearance ───────────────────────────────────────────────────

func test_debris_on_floor_obstacles_are_separated() -> void:
	var room := _make_room()
	var min_between: float = room._get_obstacle_config().min_between_dist
	var positions: Array[Vector2] = room._generate_debris_on_floor([], _candidates())
	for i: int in range(positions.size()):
		for j: int in range(i + 1, positions.size()):
			assert_float(positions[i].distance_to(positions[j])).is_greater_equal(min_between - 0.01)
	room.free()


# ── Spawn-marker clearance ─────────────────────────────────────────────────────

func test_debris_on_floor_respects_spawn_clearance() -> void:
	var room := _make_room()
	var spawns: Array[Vector2] = [Vector2(250.0, 0.0), Vector2(-350.0, 0.0)]
	var min_spawn: float = room._get_obstacle_config().min_spawn_dist
	var positions: Array[Vector2] = room._generate_debris_on_floor(spawns, _candidates())
	for pos: Vector2 in positions:
		for sp: Vector2 in spawns:
			assert_float(pos.distance_to(sp)).is_greater_equal(min_spawn - 0.01)
	room.free()


# ── Extra zone filter honored on top of the floor mask ─────────────────────────

func test_debris_on_floor_honors_extra_zone_check() -> void:
	var room := _make_room()
	# Only accept candidates on the right side — mimics a template valid_zone_rect.
	var zone_check: Callable = func(p: Vector2) -> bool: return p.x >= 300.0
	var positions: Array[Vector2] = room._generate_debris_on_floor([], _candidates(), zone_check)
	for pos: Vector2 in positions:
		assert_float(pos.x).is_greater_equal(300.0)
	room.free()


# ── Graceful fallback without a tile map ───────────────────────────────────────

func test_interior_tile_centers_empty_without_tilemap() -> void:
	var room := _make_room()   # no scene tree, no TileMapLayer
	assert_array(room._interior_tile_centers()).is_empty()
	room.free()
