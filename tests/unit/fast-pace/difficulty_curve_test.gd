## difficulty_curve_test.gd — per-floor bullet speed / fire rate / telegraph (ADR-0019).
extends GdUnitTestSuite

const DT: float = 1.0 / 60.0
const EnemyScene: PackedScene = preload("res://src/gameplay/EnemyInstance.tscn")


func _pattern() -> BulletPattern:
	var p := BulletPattern.new()
	p.initial_delay = 0.0
	p.interval = 1.0
	p.windup_sec = 0.0
	return p


func _count_fires(runner: BulletPatternRunner, seconds: float) -> int:
	var n: int = 0
	for _i: int in roundi(seconds / DT):
		for ev: Dictionary in runner.tick(DT, 0.0):
			if ev["type"] == BulletPatternRunner.EVENT_FIRE:
				n += 1
	return n


func test_runner_rate_mult_fires_more_often() -> void:
	var base := BulletPatternRunner.new(_pattern())
	var fast := BulletPatternRunner.new(_pattern())
	fast.rate_mult = 2.0
	var b: int = _count_fires(base, 4.0)
	var f: int = _count_fires(fast, 4.0)
	assert_int(f).is_greater(b)
	assert_int(f).is_between(b * 2 - 1, b * 2 + 1)


func test_laser_and_mortar_telegraph_scale() -> void:
	var p := _pattern()
	p.telegraph_sec = 1.0
	var laser := EnemyLaser.new()
	laser.pattern = p
	laser.telegraph_mult = 0.8
	assert_float(laser._telegraph_sec()).is_equal_approx(0.8, 0.0001)
	var shell := MortarShell.new()
	shell.pattern = p
	shell.telegraph_mult = 0.5
	assert_float(shell._telegraph_sec()).is_equal_approx(0.5, 0.0001)
	laser.free()
	shell.free()


func test_enemy_apply_difficulty_clamps_and_scales_runners() -> void:
	var enemy: EnemyInstance = EnemyScene.instantiate() as EnemyInstance
	enemy._pattern_runners.append(BulletPatternRunner.new(_pattern()))
	enemy.apply_difficulty(1.2, 1.3, 0.8)
	assert_that(enemy.get_difficulty()).is_equal(Vector3(1.2, 1.3, 0.8))
	assert_float(enemy._pattern_runners[0].rate_mult).is_equal_approx(1.3, 0.0001)
	enemy.apply_difficulty(99.0, 0.0, -1.0)
	var d: Vector3 = enemy.get_difficulty()
	assert_float(d.x).is_equal(3.0)
	assert_float(d.y).is_equal(0.25)
	assert_float(d.z).is_equal_approx(0.1, 0.0001)
	enemy.free()


func test_floor_configs_get_harder() -> void:
	var f1: EnemyPoolConfig = load("res://assets/data/enemy_pool_configs/enemy_pool_floor1.tres")
	var f2: EnemyPoolConfig = load("res://assets/data/enemy_pool_configs/enemy_pool_floor2.tres")
	var f3: EnemyPoolConfig = load("res://assets/data/enemy_pool_configs/enemy_pool_floor3.tres")
	assert_float(f2.bullet_speed_mult).is_greater(f1.bullet_speed_mult)
	assert_float(f3.bullet_speed_mult).is_greater(f2.bullet_speed_mult)
	assert_float(f3.fire_rate_mult).is_greater(f1.fire_rate_mult)
	assert_float(f3.telegraph_mult).is_less(f1.telegraph_mult)
