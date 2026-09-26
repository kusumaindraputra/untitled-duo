## boss_variant_test.gd — EnemyInstance.apply_boss_variant and the HUD title (ADR-0028).
##
## Coverage:
##   a variant scales HP, move speed, bullet speed and fire rate, and adds its layers
##   the multipliers stack on the floor difficulty
##   non-bosses ignore variants; init() clears the variant
##   CombatHUD.boss_title appends the variant's title
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const EnemyInstanceScript = preload("res://src/gameplay/enemy_instance.gd")


class MockCatalog:
	var types: Dictionary = {}

	func get_type(id: int) -> EnemyType:
		return types.get(id, null)


var _holder: Node2D = null


func before_test() -> void:
	_holder = Node2D.new()
	add_child(_holder)


func after_test() -> void:
	if is_instance_valid(_holder):
		remove_child(_holder)
		_holder.free()
	_holder = null


func _layer(threshold: float) -> BulletPattern:
	var p := BulletPattern.new()
	p.hp_threshold = threshold
	return p


func _type(archetype: GameEnums.EnemyArchetype) -> EnemyType:
	var et := EnemyType.new()
	et.id = 1
	et.name = "TestBoss"
	et.archetype = archetype
	et.base_hp = 200
	et.base_damage = 10.0
	et.base_move_speed = 50.0
	var layers: Array[BulletPattern] = [_layer(1.0), _layer(0.5)]
	et.pattern_layers = layers
	return et


func _spawn(et: EnemyType) -> EnemyInstance:
	var c := MockCatalog.new()
	c.types[et.id] = et
	var enemy := EnemyInstanceScript.new() as EnemyInstance
	_holder.add_child(enemy)
	enemy.init(et.id, c)
	return enemy


func _variant() -> BossVariant:
	var v := BossVariant.new()
	v.id = &"overclocked"
	v.hp_mult = 1.5
	v.move_speed_mult = 1.2
	v.bullet_speed_mult = 1.1
	v.fire_rate_mult = 1.25
	var extra: Array[BulletPattern] = [_layer(0.5)]
	v.extra_layers = extra
	return v


func test_boss_variant_scales_stats_and_adds_layers() -> void:
	var boss := _spawn(_type(GameEnums.EnemyArchetype.BOSS))
	boss.apply_difficulty(1.2, 1.0, 1.0)
	boss.apply_boss_variant(_variant())
	assert_int(boss.get_max_hp()).is_equal(300)
	assert_int(boss._current_hp).is_equal(300)
	assert_float(boss._move_speed).is_equal_approx(60.0, 0.001)
	var diff: Vector3 = boss.get_difficulty()
	assert_float(diff.x).is_equal_approx(1.32, 0.001)
	assert_float(diff.y).is_equal_approx(1.25, 0.001)
	assert_int(boss._pattern_runners.size()).is_equal(3)
	for runner: BulletPatternRunner in boss._pattern_runners:
		assert_float(runner.rate_mult).is_equal_approx(1.25, 0.001)
	assert_str(String(boss.get_boss_variant().id)).is_equal("overclocked")


func test_boss_variant_ignored_by_non_boss() -> void:
	var enemy := _spawn(_type(GameEnums.EnemyArchetype.SHOOTER))
	enemy.apply_boss_variant(_variant())
	assert_int(enemy.get_max_hp()).is_equal(200)
	assert_int(enemy._pattern_runners.size()).is_equal(2)
	assert_object(enemy.get_boss_variant()).is_null()


func test_boss_variant_null_is_noop() -> void:
	var boss := _spawn(_type(GameEnums.EnemyArchetype.BOSS))
	boss.apply_boss_variant(null)
	assert_int(boss.get_max_hp()).is_equal(200)
	assert_object(boss.get_boss_variant()).is_null()


func test_boss_variant_cleared_by_init() -> void:
	var et := _type(GameEnums.EnemyArchetype.BOSS)
	var boss := _spawn(et)
	boss.apply_boss_variant(_variant())
	var c := MockCatalog.new()
	c.types[et.id] = et
	boss.init(et.id, c)
	assert_object(boss.get_boss_variant()).is_null()
	assert_int(boss.get_max_hp()).is_equal(200)


func test_boss_variant_title_on_hud() -> void:
	var boss := _spawn(_type(GameEnums.EnemyArchetype.BOSS))
	var hud := CombatHUD.new()
	assert_str(hud.boss_title(boss)).is_equal("TEST BOSS")
	boss.apply_boss_variant(_variant())
	assert_str(hud.boss_title(boss)).is_equal("TEST BOSS · OVERCLOCKED")
	hud.free()
