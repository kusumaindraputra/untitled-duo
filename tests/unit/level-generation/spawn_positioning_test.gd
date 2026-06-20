## spawn_positioning_test.gd — Unit tests for IsometricRoom SW spawn + NE exit scoring.
##
## Tests the pure scoring functions _score_sw and _score_ne in isolation — no TileMapLayer
## or scene tree required. The wrapper methods (_find_sw_position, _find_ne_positions) are
## covered implicitly via integration; pure functions are the unit-test surface.
##
## Coverage:
##   - _score_sw: picks the highest -x+y tile in safe zone (norm 0.5–0.82)
##   - _score_sw: rejects tiles with norm > 0.82 (OOB) or norm < 0.5 (too central)
##   - _score_sw: returns Vector2.ZERO when no valid tile exists
##   - _score_ne: picks top-N NE tiles (highest x-y) in safe zone, spaced ≥60px
##   - _score_ne: returns empty array for empty input
##   - _score_ne: all results satisfy safe zone and spacing constraints
extends GdUnitTestSuite

const IsometricRoomScript = preload("res://src/scenes/isometric_room.gd")


func _make_room() -> IsometricRoom:
	return IsometricRoomScript.new() as IsometricRoom


# ── _score_sw ─────────────────────────────────────────────────────────────────

## GIVEN three positions spanning SW, center, NE
## WHEN _score_sw runs
## THEN the SW position wins (-x+y is highest)
func test_isometric_room_score_sw_picks_sw_tile() -> void:
	var room := _make_room()
	# norms: (-250,140)=0.756; (0,80)=0.208→rejected; (250,-140)=0.756
	var positions: Array[Vector2] = [
		Vector2(-250.0, 140.0),
		Vector2(0.0, 80.0),
		Vector2(250.0, -140.0),
	]
	var result: Vector2 = room._score_sw(positions)
	assert_vector(result).is_equal(Vector2(-250.0, 140.0))
	room.free()


## GIVEN a tile outside the safe zone (norm > 0.82) and one inside
## WHEN _score_sw runs
## THEN only the in-zone tile is returned
func test_isometric_room_score_sw_rejects_oob_tiles() -> void:
	var room := _make_room()
	# (-580,50): norm = 580/640 + 50/384 ≈ 1.036 — OOB
	# (-200,100): norm = 200/640 + 100/384 ≈ 0.573 — safe zone
	var positions: Array[Vector2] = [
		Vector2(-580.0, 50.0),
		Vector2(-200.0, 100.0),
	]
	var result: Vector2 = room._score_sw(positions)
	assert_vector(result).is_equal(Vector2(-200.0, 100.0))
	room.free()


## GIVEN a tile too close to center (norm < 0.5) and one in safe zone
## WHEN _score_sw runs
## THEN the central tile is rejected
func test_isometric_room_score_sw_rejects_center_tiles() -> void:
	var room := _make_room()
	# (-50,20): norm = 50/640 + 20/384 ≈ 0.130 — too central
	# (-200,110): norm = 200/640 + 110/384 ≈ 0.599 — safe zone
	var positions: Array[Vector2] = [
		Vector2(-50.0, 20.0),
		Vector2(-200.0, 110.0),
	]
	var result: Vector2 = room._score_sw(positions)
	assert_vector(result).is_equal(Vector2(-200.0, 110.0))
	room.free()


## GIVEN an empty position array
## WHEN _score_sw runs
## THEN returns Vector2.ZERO (safe fallback)
func test_isometric_room_score_sw_empty_input_returns_zero() -> void:
	var room := _make_room()
	var result: Vector2 = room._score_sw([])
	assert_vector(result).is_equal(Vector2.ZERO)
	room.free()


## GIVEN only OOB tiles (all outside safe zone)
## WHEN _score_sw runs
## THEN returns Vector2.ZERO (no valid candidate)
func test_isometric_room_score_sw_all_oob_returns_zero() -> void:
	var room := _make_room()
	# All tiles outside safe zone: norm > 0.82 or norm < 0.5
	var positions: Array[Vector2] = [
		Vector2(-600.0, 0.0),   # norm ≈ 0.938 — OOB
		Vector2(0.0, -350.0),   # norm ≈ 0.911 — OOB
		Vector2(-30.0, 10.0),   # norm ≈ 0.073 — too central
	]
	var result: Vector2 = room._score_sw(positions)
	assert_vector(result).is_equal(Vector2.ZERO)
	room.free()


# ── _score_ne ─────────────────────────────────────────────────────────────────

## GIVEN positions in multiple quadrants
## WHEN _score_ne(3) runs
## THEN returns at most 3 positions
func test_isometric_room_score_ne_returns_at_most_n() -> void:
	var room := _make_room()
	var positions: Array[Vector2] = [
		Vector2(250.0, -140.0),
		Vector2(200.0, -100.0),
		Vector2(180.0, -150.0),
		Vector2(-200.0, 100.0),
	]
	var result: Array[Vector2] = room._score_ne(positions, 3)
	assert_int(result.size()).is_less_equal(3)
	room.free()


## GIVEN an empty array
## WHEN _score_ne runs
## THEN returns empty array
func test_isometric_room_score_ne_empty_input_returns_empty() -> void:
	var room := _make_room()
	var result: Array[Vector2] = room._score_ne([], 3)
	assert_array(result).is_empty()
	room.free()


## GIVEN positions in the NE safe zone, spread far enough apart
## WHEN _score_ne(3) runs
## THEN all returned positions are spaced >= 60px from each other
func test_isometric_room_score_ne_positions_spaced_60px() -> void:
	var room := _make_room()
	# Three NE positions well inside safe zone and far enough apart (all dist > 60px).
	# norms: (280,-50)=0.568; (350,30)=0.625; (200,-100)=0.573
	# distances: (280,-50)↔(350,30)≈106px; (280,-50)↔(200,-100)≈94px; (350,30)↔(200,-100)≈198px
	var positions: Array[Vector2] = [
		Vector2(280.0, -50.0),
		Vector2(350.0, 30.0),
		Vector2(200.0, -100.0),
	]
	var result: Array[Vector2] = room._score_ne(positions, 3)
	for i: int in range(result.size()):
		for j: int in range(i + 1, result.size()):
			assert_float(result[i].distance_to(result[j])).is_greater_equal(60.0 - 0.01)
	room.free()


## GIVEN positions where one is outside safe zone
## WHEN _score_ne runs
## THEN all returned positions satisfy norm 0.5–0.82
func test_isometric_room_score_ne_results_within_safe_zone() -> void:
	var room := _make_room()
	# (250,-140): norm=0.756 ✓; (550,-50): norm≈0.989 — OOB; (200,-100): norm=0.573 ✓
	var positions: Array[Vector2] = [
		Vector2(250.0, -140.0),
		Vector2(550.0, -50.0),
		Vector2(200.0, -100.0),
	]
	var result: Array[Vector2] = room._score_ne(positions, 3)
	for pos: Vector2 in result:
		var norm: float = absf(pos.x) / 640.0 + absf(pos.y) / 384.0
		assert_float(norm).is_greater_equal(0.5 - 0.01)
		assert_float(norm).is_less_equal(0.82 + 0.01)
	room.free()


## GIVEN two NE candidates too close to each other (< 60px) and a third far away
## WHEN _score_ne(2) runs
## THEN only one of the close pair is selected; the far one is also selected
func test_isometric_room_score_ne_rejects_too_close_candidates() -> void:
	var room := _make_room()
	# (300,-100) and (320,-90): dist ≈ sqrt(400+100) ≈ 22px — too close
	# (150,-140): dist to both > 60px
	# norms: (300,-100)=0.728; (320,-90)=0.734; (150,-140)=0.598
	var positions: Array[Vector2] = [
		Vector2(300.0, -100.0),
		Vector2(320.0, -90.0),
		Vector2(150.0, -140.0),
	]
	var result: Array[Vector2] = room._score_ne(positions, 2)
	assert_int(result.size()).is_equal(2)
	# The two results must be >= 60px apart
	if result.size() == 2:
		assert_float(result[0].distance_to(result[1])).is_greater_equal(60.0 - 0.01)
	room.free()
