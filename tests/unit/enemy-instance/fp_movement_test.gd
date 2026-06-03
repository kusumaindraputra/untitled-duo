## fp_movement_test.gd — Unit tests for EnemyInstance FP movement (Story 002).
## Covers: AC-EAI-07 (incl. diagonal edge case), AC-EAI-08, AC-EAI-09, AC-EAI-27
## GdUnit4 v6.1.3 | Godot 4.6.2
extends GdUnitTestSuite

const MOVE_SPEED: float = 80.0
const DELTA: float = 1.0 / 60.0


func _make_enemy() -> EnemyInstance:
	var e := EnemyInstance.new()
	e._combat_active = true
	e._move_speed = MOVE_SPEED
	add_child(e)
	return e


func _make_fayde_at(pos: Vector2) -> Node2D:
	var n := Node2D.new()
	n.global_position = pos
	add_child(n)
	return n


# ── AC-EAI-07 — axis-aligned ──────────────────────────────────────────────────

## Enemy at (0,0), Fayde at (100,0) → velocity is rightward at _move_speed.
func test_ei_movement_rightward_fayde_velocity_is_positive_x() -> void:
	var enemy := _make_enemy()
	auto_free(enemy)
	enemy.global_position = Vector2.ZERO
	var fayde := _make_fayde_at(Vector2(100.0, 0.0))
	auto_free(fayde)
	enemy._fayde_ref = fayde

	enemy._physics_process(DELTA)

	assert_float(enemy.velocity.x).is_greater(0.0)
	assert_float(enemy.velocity.length()).is_equal_approx(MOVE_SPEED, 0.5)
	assert_float(enemy.velocity.y).is_equal_approx(0.0, 0.5)


# ── AC-EAI-07 edge case — diagonal ───────────────────────────────────────────

## Enemy at (0,0), Fayde at (100,100) → velocity has both components positive,
## magnitude equals _move_speed (normalized diagonal direction × speed).
func test_ei_movement_diagonal_fayde_velocity_magnitude_equals_move_speed() -> void:
	var enemy := _make_enemy()
	auto_free(enemy)
	enemy.global_position = Vector2.ZERO
	var fayde := _make_fayde_at(Vector2(100.0, 100.0))
	auto_free(fayde)
	enemy._fayde_ref = fayde

	enemy._physics_process(DELTA)

	assert_float(enemy.velocity.x).is_greater(0.0)
	assert_float(enemy.velocity.y).is_greater(0.0)
	assert_float(enemy.velocity.length()).is_equal_approx(MOVE_SPEED, 0.5)


# ── AC-EAI-08 ────────────────────────────────────────────────────────────────

## Enemy and Fayde at same position → fallback direction (Vector2.RIGHT) used;
## velocity is non-NaN and has magnitude _move_speed.
func test_ei_movement_same_position_velocity_is_not_nan() -> void:
	var enemy := _make_enemy()
	auto_free(enemy)
	enemy.global_position = Vector2(50.0, 50.0)
	var fayde := _make_fayde_at(Vector2(50.0, 50.0))
	auto_free(fayde)
	enemy._fayde_ref = fayde

	enemy._physics_process(DELTA)

	assert_bool(is_nan(enemy.velocity.x)).is_false()
	assert_bool(is_nan(enemy.velocity.y)).is_false()
	# Fallback _dir_last_valid = Vector2.RIGHT → velocity should be (MOVE_SPEED, 0).
	assert_float(enemy.velocity.length()).is_equal_approx(MOVE_SPEED, 0.5)


# ── AC-EAI-09 ────────────────────────────────────────────────────────────────

## Degenerate position uses _dir_last_valid fallback direction.
func test_ei_movement_degenerate_position_uses_last_valid_direction() -> void:
	var enemy := _make_enemy()
	auto_free(enemy)
	enemy._dir_last_valid = Vector2(0.0, 1.0)
	enemy.global_position = Vector2(50.0, 50.0)
	var fayde := _make_fayde_at(Vector2(50.0, 50.0))
	auto_free(fayde)
	enemy._fayde_ref = fayde

	enemy._physics_process(DELTA)

	assert_float(enemy.velocity.x).is_equal_approx(0.0, 0.01)
	assert_float(enemy.velocity.y).is_equal_approx(MOVE_SPEED, 0.01)


# ── AC-EAI-27 ────────────────────────────────────────────────────────────────

## Null _fayde_ref with no player in scene tree → velocity stays zero, no crash.
func test_ei_null_fayde_ref_velocity_is_zero() -> void:
	var enemy := _make_enemy()
	auto_free(enemy)
	# Verify test isolation: _ready() must not have found a player-group node.
	assert_object(get_tree().get_first_node_in_group(&"player")).is_null()
	enemy._fayde_ref = null

	enemy._physics_process(DELTA)

	assert_float(enemy.velocity.x).is_equal(0.0)
	assert_float(enemy.velocity.y).is_equal(0.0)
