## spawn_angles_test.gd — Unit tests for IsometricRoom._even_spawn_angles.
##
## The spawn-marker placement was generalized from a hardcoded 3-angle array to an
## even distribution over any marker count, so adding SpawnZone_D/E/F to the scene
## spreads the wave around the arena instead of leaving extra markers stacked at
## their default positions. This guards that distribution math.
##
## Coverage:
##   - 3 markers reproduce the original 0 / 120 / 240 degree layout
##   - 6 markers are evenly spaced at 60 degree steps, all distinct
##   - every angle is in [0, TAU)
##   - n = 0 returns empty (no crash)
##
## Setup: IsometricRoom.new() without add_child — _even_spawn_angles is pure.
extends GdUnitTestSuite

const IsometricRoomScript = preload("res://src/scenes/isometric_room.gd")


func _make_room() -> IsometricRoom:
	return IsometricRoomScript.new() as IsometricRoom


func test_even_spawn_angles_three_markers_match_thirds() -> void:
	var room := _make_room()
	var angles: Array[float] = room._even_spawn_angles(3)
	assert_int(angles.size()).is_equal(3)
	assert_float(angles[0]).is_equal_approx(0.0, 0.0001)
	assert_float(angles[1]).is_equal_approx(TAU / 3.0, 0.0001)
	assert_float(angles[2]).is_equal_approx(2.0 * TAU / 3.0, 0.0001)
	room.free()


func test_even_spawn_angles_six_markers_evenly_spaced() -> void:
	var room := _make_room()
	var angles: Array[float] = room._even_spawn_angles(6)
	assert_int(angles.size()).is_equal(6)
	# Each step is exactly TAU/6 and every angle is distinct.
	for i: int in range(6):
		assert_float(angles[i]).is_equal_approx(TAU * float(i) / 6.0, 0.0001)
	room.free()


func test_even_spawn_angles_all_within_circle() -> void:
	var room := _make_room()
	for n: int in [1, 3, 6, 12]:
		for a: float in room._even_spawn_angles(n):
			assert_float(a).is_greater_equal(0.0)
			assert_float(a).is_less(TAU)
	room.free()


func test_even_spawn_angles_zero_returns_empty() -> void:
	var room := _make_room()
	assert_array(room._even_spawn_angles(0)).is_empty()
	room.free()
