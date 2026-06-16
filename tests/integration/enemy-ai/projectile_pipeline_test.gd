## projectile_pipeline_test.gd — Integration tests for Projectile (S8-05).
##
## Coverage:
##   S8-05: launch() normalises direction
##   S8-05: Projectile moves in launch direction after one tick
##   S8-05: _distance_traveled increments by PROJECTILE_SPEED * delta per tick
##   S8-05: Projectile calls queue_free() after reaching MAX_RANGE
##   S8-05: PROJECTILE_SPEED constant value sanity
##   S8-05: MAX_RANGE constant value sanity
##
## Framework: GdUnit4 (extends GdUnitTestSuite)
## Nodes are added to the scene tree via add_child() so _ready() runs
## and auto_free() handles cleanup.
extends GdUnitTestSuite

@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

const DELTA: float = 1.0 / 60.0


func _make_projectile() -> Projectile:
	var p := Projectile.new()
	add_child(p)
	return p


# ── Direction ─────────────────────────────────────────────────────────────────

func test_projectile_launch_sets_normalised_direction() -> void:
	# Arrange
	var p := _make_projectile()
	auto_free(p)

	# Act
	p.launch(Vector2(3.0, 4.0), 1.5)

	# Assert — (3,4) normalised → (0.6, 0.8)
	assert_float(p._direction.x).is_equal_approx(0.6, 0.001)
	assert_float(p._direction.y).is_equal_approx(0.8, 0.001)


func test_projectile_moves_in_launch_direction_after_one_tick() -> void:
	# Arrange
	var p := _make_projectile()
	auto_free(p)
	p.global_position = Vector2.ZERO
	p.launch(Vector2.RIGHT, 1.5)

	# Act
	p._physics_process(DELTA)

	# Assert — moved right, no vertical drift
	assert_float(p.position.x).is_greater(0.0)
	assert_float(p.position.y).is_equal_approx(0.0, 0.01)


# ── Distance tracking ─────────────────────────────────────────────────────────

func test_projectile_distance_traveled_increments_per_tick() -> void:
	# Arrange
	var p := _make_projectile()
	auto_free(p)
	p.launch(Vector2.RIGHT, 1.5)

	# Act
	p._physics_process(DELTA)

	# Assert
	var expected: float = Projectile.PROJECTILE_SPEED * DELTA
	assert_float(p._distance_traveled).is_equal_approx(expected, 0.01)


func test_projectile_queues_free_after_reaching_max_range() -> void:
	# Arrange — set distance just under MAX_RANGE so next tick crosses the threshold
	var p := _make_projectile()
	auto_free(p)
	p.launch(Vector2.RIGHT, 1.5)
	p._distance_traveled = Projectile.MAX_RANGE - (Projectile.PROJECTILE_SPEED * DELTA * 0.5)

	# Act
	p._physics_process(DELTA)

	# Assert — queue_free() was called; node is pending deletion
	assert_bool(p.is_queued_for_deletion()).is_true()


# ── Constants ─────────────────────────────────────────────────────────────────

func test_projectile_speed_constant_is_220() -> void:
	assert_float(Projectile.PROJECTILE_SPEED).is_equal(220.0)


func test_projectile_max_range_constant_is_400() -> void:
	assert_float(Projectile.MAX_RANGE).is_equal(400.0)
