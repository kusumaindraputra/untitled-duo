## knockback_test.gd — Unit tests for EnemyInstance.apply_knockback().
##
## Coverage:
##   AC: apply_knockback moves enemy position away from origin direction.
##   AC: apply_knockback does nothing when enemy is DEAD.
##   AC: apply_knockback direction parameter is respected (not reversed).
##
## GdUnit4 v6.1.3 | Godot 4.6
extends GdUnitTestSuite


func _make_enemy() -> EnemyInstance:
	var e := EnemyInstance.new()
	add_child(e)
	auto_free(e)
	return e


# ── AC: knockback moves enemy in given direction ──────────────────────────────

## GIVEN enemy at origin, knockback direction is RIGHT
## WHEN apply_knockback(RIGHT, 60) is called
## THEN enemy tween target position is to the right of origin
func test_apply_knockback_moves_enemy_in_given_direction() -> void:
	var enemy := _make_enemy()
	enemy.global_position = Vector2.ZERO

	enemy.apply_knockback(Vector2.RIGHT, 60.0)

	## Position tween drives movement — check offset directly via the tween target.
	## Tween hasn't completed (0.10s), so we verify it was set correctly by checking
	## that position will increase (tween target > start). Poll after 1 frame.
	await get_tree().process_frame
	assert_float(enemy.global_position.x).is_greater(0.0)


## GIVEN enemy at origin, knockback direction is LEFT
## WHEN apply_knockback(LEFT, 60) is called
## THEN enemy position moves left (negative X)
func test_apply_knockback_moves_enemy_left_when_direction_is_left() -> void:
	var enemy := _make_enemy()
	enemy.global_position = Vector2.ZERO

	enemy.apply_knockback(Vector2.LEFT, 60.0)

	await get_tree().process_frame
	assert_float(enemy.global_position.x).is_less(0.0)


# ── AC: knockback no-ops on dead enemies ─────────────────────────────────────

## GIVEN enemy is in DEAD state
## WHEN apply_knockback is called
## THEN position does not change
func test_apply_knockback_does_nothing_when_enemy_is_dead() -> void:
	var enemy := _make_enemy()
	enemy.global_position = Vector2(100.0, 100.0)
	enemy._state = EnemyInstance.EnemyState.DEAD

	enemy.apply_knockback(Vector2.RIGHT, 60.0)

	await get_tree().process_frame
	assert_float(enemy.global_position.x).is_equal_approx(100.0, 0.5)
	assert_float(enemy.global_position.y).is_equal_approx(100.0, 0.5)


# ── Regression: knockback must not push enemies through arena walls ──────────

## Adds a wall (layer 1, like ArenaBounds) whose left face sits at [param face_x].
func _make_wall(face_x: float) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40.0, 400.0)
	var col := CollisionShape2D.new()
	col.shape = rect
	wall.add_child(col)
	wall.global_position = Vector2(face_x + 20.0, 0.0)
	add_child(wall)
	auto_free(wall)
	return wall


## GIVEN a wall 30 px to the right of the enemy
## WHEN a 60 px knockback pushes the enemy toward it
## THEN the enemy stops at the wall instead of passing through it
func test_apply_knockback_stops_at_arena_wall() -> void:
	_make_wall(30.0)
	var enemy := _make_enemy()
	enemy.global_position = Vector2.ZERO
	await get_tree().physics_frame

	enemy.apply_knockback(Vector2.RIGHT, 60.0)
	await get_tree().create_timer(0.25).timeout

	# Body radius is 8 px, so the centre may reach at most face_x - 8.
	assert_float(enemy.global_position.x).is_greater(0.0)
	assert_float(enemy.global_position.x).is_less_equal(30.0 - 8.0 + 0.5)


## GIVEN an enemy already touching a wall
## WHEN knockback pushes it straight into the wall
## THEN it does not move into or past the wall
func test_apply_knockback_into_touching_wall_does_not_cross() -> void:
	_make_wall(30.0)
	var enemy := _make_enemy()
	enemy.global_position = Vector2(21.0, 0.0)
	await get_tree().physics_frame

	enemy.apply_knockback(Vector2.RIGHT, 90.0)
	await get_tree().create_timer(0.25).timeout

	assert_float(enemy.global_position.x).is_less_equal(30.0 - 8.0 + 0.5)


## GIVEN no wall in the way
## WHEN knockback is applied
## THEN the enemy travels the full distance
func test_apply_knockback_travels_full_distance_when_clear() -> void:
	_make_wall(500.0)
	var enemy := _make_enemy()
	enemy.global_position = Vector2.ZERO
	await get_tree().physics_frame

	enemy.apply_knockback(Vector2.RIGHT, 60.0)
	await get_tree().create_timer(0.25).timeout

	assert_float(enemy.global_position.x).is_equal_approx(60.0, 0.5)


## Builds a square "segment soup" boundary like IsometricRoom._build_walls():
## one ConcavePolygonShape2D on layer 1 with its edges at ±[param half].
func _make_segment_arena(half: float) -> StaticBody2D:
	var bounds := StaticBody2D.new()
	bounds.collision_layer = 1
	bounds.collision_mask = 0
	var shape := ConcavePolygonShape2D.new()
	shape.segments = PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, -half), Vector2(half, half),
		Vector2(half, half), Vector2(-half, half),
		Vector2(-half, half), Vector2(-half, -half),
	])
	var col := CollisionShape2D.new()
	col.shape = shape
	bounds.add_child(col)
	add_child(bounds)
	auto_free(bounds)
	return bounds


## GIVEN an enemy 20 px inside a segment-soup arena edge (the real ArenaBounds shape)
## WHEN the maximum knockback pushes it at the edge
## THEN it stays inside the arena
func test_apply_knockback_stays_inside_segment_arena_bounds() -> void:
	_make_segment_arena(100.0)
	var enemy := _make_enemy()
	enemy.global_position = Vector2(80.0, 0.0)
	await get_tree().physics_frame

	enemy.apply_knockback(Vector2.RIGHT, SpellCastingEffects.KNOCKBACK_MAX)
	await get_tree().create_timer(0.25).timeout

	assert_float(enemy.global_position.x).is_less(100.0)


## GIVEN a diagonal push toward an arena corner
## WHEN knockback is applied
## THEN the enemy stays inside on both axes
func test_apply_knockback_diagonal_stays_inside_segment_arena_bounds() -> void:
	_make_segment_arena(100.0)
	var enemy := _make_enemy()
	enemy.global_position = Vector2(85.0, -85.0)
	await get_tree().physics_frame

	enemy.apply_knockback(Vector2(1.0, -1.0), SpellCastingEffects.KNOCKBACK_MAX)
	await get_tree().create_timer(0.25).timeout

	assert_float(enemy.global_position.x).is_less(100.0)
	assert_float(enemy.global_position.y).is_greater(-100.0)


## GIVEN two hits in quick succession toward a wall
## WHEN the second lands before the first slide finishes
## THEN the enemy still ends inside the wall
func test_back_to_back_knockbacks_stay_inside_wall() -> void:
	_make_wall(50.0)
	var enemy := _make_enemy()
	enemy.global_position = Vector2.ZERO
	await get_tree().physics_frame

	enemy.apply_knockback(Vector2.RIGHT, 40.0)
	await get_tree().physics_frame
	enemy.apply_knockback(Vector2.RIGHT, 40.0)
	await get_tree().create_timer(0.25).timeout

	assert_float(enemy.global_position.x).is_less_equal(50.0 - 8.0 + 0.5)


# ── KnockbackMotion helper ────────────────────────────────────────────────────

## A body outside the tree has no space to sweep in — the offset is returned as-is.
func test_clamp_offset_outside_tree_returns_offset() -> void:
	var e := EnemyInstance.new()
	var out: Vector2 = KnockbackMotion.clamp_offset(e, Vector2(60.0, 0.0))
	assert_vector(out).is_equal(Vector2(60.0, 0.0))
	e.free()


## The training dummy (StaticBody2D, mask 0) is swept against the same walls.
func test_dummy_knockback_stops_at_wall() -> void:
	_make_wall(30.0)
	var dummy := DummyEnemy.new()
	add_child(dummy)
	auto_free(dummy)
	dummy.global_position = Vector2.ZERO
	await get_tree().physics_frame

	dummy.apply_knockback(Vector2.RIGHT, 60.0)
	await get_tree().create_timer(0.25).timeout

	# Dummy radius is 14 px.
	assert_float(dummy.global_position.x).is_less_equal(30.0 - 14.0 + 0.5)
