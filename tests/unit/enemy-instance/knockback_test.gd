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
