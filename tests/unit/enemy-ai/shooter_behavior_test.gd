## shooter_behavior_test.gd — Unit tests for SHOOTER archetype behavior in EnemyInstance.
##
## Coverage:
##   S8-05: SHOOTER stops when distance >= KEEP_DISTANCE
##   S8-05: SHOOTER retreats when distance < KEEP_DISTANCE
##   S8-05: _shoot_timer increments during SHOOTER tick
##   S8-05: no shot fires before SHOOT_INTERVAL elapses
##   S8-05: _shoot_timer resets after SHOOT_INTERVAL elapses
##   S8-05: non-SHOOTER archetypes do not accumulate _shoot_timer
##   S8-05: _on_preparation_started resets _shoot_timer
##
## Framework: GdUnit4 (extends GdUnitTestSuite)
##
## Setup note: EnemyInstance._ready() connects to Autoloads — we skip _ready() by
## setting state vars directly. Tests that call _physics_process() need add_child()
## because move_and_slide() requires a physics RID.
extends GdUnitTestSuite

@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

const EnemyInstanceScript = preload("res://src/gameplay/enemy_instance.gd")

var _enemy: EnemyInstance
var _fayde: Node2D


func before_test() -> void:
	_fayde = Node2D.new()
	_enemy = EnemyInstanceScript.new() as EnemyInstance
	# Manually wire required state — skip _ready() to avoid Autoload connections.
	_enemy._combat_active = true
	_enemy._fayde_ref = _fayde
	_enemy._dir_last_valid = Vector2.RIGHT
	_enemy._move_speed = 60.0
	add_child(_fayde)
	add_child(_enemy)
	# _ready() overwrites _fayde_ref via get_first_node_in_group("player") → null
	# because _fayde is a plain Node2D with no "player" group. Re-assign here.
	_enemy._fayde_ref = _fayde


func after_test() -> void:
	# Free any Projectile nodes spawned by _fire_projectile() during the test.
	for child in get_children():
		if child is Projectile:
			remove_child(child)
			child.free()
	if is_instance_valid(_enemy):
		if _enemy.is_inside_tree():
			remove_child(_enemy)
		_enemy.free()
	if is_instance_valid(_fayde):
		if _fayde.is_inside_tree():
			remove_child(_fayde)
		_fayde.free()
	_enemy = null
	_fayde = null


# ── Distance maintenance ──────────────────────────────────────────────────────

func test_shooter_velocity_zero_when_far_enough() -> void:
	# Arrange — place fayde far from enemy (beyond KEEP_DISTANCE)
	_enemy.global_position = Vector2.ZERO
	_fayde.global_position = Vector2(EnemyInstance.KEEP_DISTANCE + 50.0, 0.0)
	_enemy._archetype = GameEnums.EnemyArchetype.SHOOTER
	_enemy._dir_last_valid = Vector2.RIGHT

	# Act
	_enemy._physics_process(0.01)

	# Assert — velocity should be zero (shooter holds position at range)
	assert_float(_enemy.velocity.length()).is_less_equal(1.0)


func test_shooter_retreats_when_player_too_close() -> void:
	# Arrange — place fayde close (inside KEEP_DISTANCE)
	_enemy.global_position = Vector2.ZERO
	_fayde.global_position = Vector2(EnemyInstance.KEEP_DISTANCE - 50.0, 0.0)
	_enemy._archetype = GameEnums.EnemyArchetype.SHOOTER
	_enemy._dir_last_valid = Vector2.RIGHT   # toward fayde

	# Act
	_enemy._physics_process(0.01)

	# Assert — velocity should point away from fayde (negative x component)
	assert_float(_enemy.velocity.x).is_less(0.0)


# ── Shoot timer ───────────────────────────────────────────────────────────────

func test_shooter_shoot_timer_increments_per_tick() -> void:
	# Arrange
	_enemy._archetype = GameEnums.EnemyArchetype.SHOOTER
	_enemy._shoot_timer = 0.0
	_enemy.global_position = Vector2.ZERO
	_fayde.global_position = Vector2(EnemyInstance.KEEP_DISTANCE + 50.0, 0.0)

	# Act
	_enemy._physics_process(0.5)

	# Assert
	assert_float(_enemy._shoot_timer).is_greater(0.0)


func test_shooter_no_fire_before_interval() -> void:
	# Arrange — tick just under SHOOT_INTERVAL
	_enemy._archetype = GameEnums.EnemyArchetype.SHOOTER
	_enemy._shoot_timer = 0.0
	_enemy.global_position = Vector2.ZERO
	_fayde.global_position = Vector2(EnemyInstance.KEEP_DISTANCE + 50.0, 0.0)
	var just_under: float = EnemyInstance.SHOOT_INTERVAL - 0.05

	# Act
	_enemy._physics_process(just_under)

	# Assert — timer should still be less than SHOOT_INTERVAL (no reset yet)
	assert_float(_enemy._shoot_timer).is_less(EnemyInstance.SHOOT_INTERVAL)


func test_shooter_timer_resets_after_interval() -> void:
	# Arrange — tick just over SHOOT_INTERVAL; _fire_projectile has null-parent guard
	_enemy._archetype = GameEnums.EnemyArchetype.SHOOTER
	_enemy._shoot_timer = 0.0
	_enemy.global_position = Vector2.ZERO
	_fayde.global_position = Vector2(EnemyInstance.KEEP_DISTANCE + 50.0, 0.0)
	var over_interval: float = EnemyInstance.SHOOT_INTERVAL + 0.1

	# Act — this will call _fire_projectile; parent exists so projectile will spawn
	_enemy._physics_process(over_interval)

	# Assert — timer reset (value should be the overshoot, ~0.1)
	assert_float(_enemy._shoot_timer).is_less(EnemyInstance.SHOOT_INTERVAL)


func test_non_shooter_shoot_timer_stays_zero() -> void:
	# Arrange — SEEKER should never accumulate _shoot_timer
	_enemy._archetype = GameEnums.EnemyArchetype.SEEKER
	_enemy._shoot_timer = 0.0
	_enemy.global_position = Vector2.ZERO
	_fayde.global_position = Vector2(100.0, 0.0)

	# Act
	_enemy._physics_process(3.0)

	# Assert
	assert_float(_enemy._shoot_timer).is_equal(0.0)


func test_preparation_started_resets_shoot_timer() -> void:
	# Arrange
	_enemy._shoot_timer = 1.5

	# Act
	_enemy._on_preparation_started()

	# Assert
	assert_float(_enemy._shoot_timer).is_equal(0.0)
