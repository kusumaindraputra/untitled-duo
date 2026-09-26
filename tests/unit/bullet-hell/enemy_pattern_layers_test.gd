## enemy_pattern_layers_test.gd — EnemyInstance pattern layers, elites, boss phases (ADR-0018).
##
## Coverage:
##   init() builds one runner per EnemyType.pattern_layers entry
##   _tick_patterns fires pooled bullets into the parent
##   make_elite: HP / damage multipliers, extra layer, idempotent, never on bosses
##   phase_changed fires when HP drops below an HP-gated layer's threshold
##   death_pattern fires a ring on death
##   Real catalog: Rifter and the bosses ship with pattern layers
extends GdUnitTestSuite

const EnemyInstanceScript = preload("res://src/gameplay/enemy_instance.gd")
const EnemyCatalogScript = preload("res://src/data/enemy_catalog.gd")
const TUNING: BulletHellTuning = preload("res://assets/data/bullet_hell_tuning.tres")
const DT: float = 1.0 / 60.0


class MockCatalog:
	var types: Dictionary = {}

	func get_type(id: int) -> EnemyType:
		return types.get(id, null)


var _holder: Node2D = null
var _fayde: Node2D = null


func before_test() -> void:
	_holder = Node2D.new()
	add_child(_holder)
	_fayde = Node2D.new()
	_holder.add_child(_fayde)
	_fayde.global_position = Vector2(200.0, 0.0)


func after_test() -> void:
	if is_instance_valid(_holder):
		remove_child(_holder)
		_holder.free()
	_holder = null
	_fayde = null


func _fan() -> BulletPattern:
	var p := BulletPattern.new()
	p.shape = BulletPattern.Shape.FAN
	p.count = 3
	p.spread_deg = 30.0
	p.initial_delay = 0.0
	p.windup_sec = 0.0
	return p


func _type(archetype: GameEnums.EnemyArchetype, layers: Array[BulletPattern]) -> EnemyType:
	var et := EnemyType.new()
	et.id = 1
	et.name = "TestEnemy"
	et.archetype = archetype
	et.base_hp = 100
	et.base_damage = 10.0
	et.base_move_speed = 50.0
	et.pattern_layers = layers
	return et


func _catalog(et: EnemyType) -> MockCatalog:
	var c := MockCatalog.new()
	c.types[et.id] = et
	return c


## Enemy parented under _holder (in tree) and pointed at the fake Fayde.
func _spawn(et: EnemyType) -> EnemyInstance:
	var enemy := EnemyInstanceScript.new() as EnemyInstance
	_holder.add_child(enemy)
	enemy.init(et.id, _catalog(et))
	enemy._fayde_ref = _fayde
	enemy._dir_last_valid = Vector2.RIGHT
	return enemy


func _live_bullets() -> int:
	var pool: Node = _holder.get_node_or_null(NodePath(String(BulletPool.NODE_NAME)))
	if pool == null:
		return 0
	var n: int = 0
	for child: Node in pool.get_children():
		if child is Projectile and (child as Projectile).is_live():
			n += 1
	return n


func test_init_builds_one_runner_per_layer() -> void:
	var enemy := _spawn(_type(GameEnums.EnemyArchetype.SHOOTER, [_fan(), _fan()]))
	assert_int(enemy.get_pattern_layer_count()).is_equal(2)


func test_tick_patterns_fires_pooled_bullets() -> void:
	var enemy := _spawn(_type(GameEnums.EnemyArchetype.SHOOTER, [_fan()]))
	enemy._tick_patterns(DT)
	assert_int(_live_bullets()).is_equal(3)


func test_make_elite_scales_hp_damage_and_adds_layer() -> void:
	var enemy := _spawn(_type(GameEnums.EnemyArchetype.SEEKER, []))
	enemy.make_elite(TUNING)
	assert_bool(enemy.is_elite()).is_true()
	assert_int(enemy.get_max_hp()).is_equal(roundi(100.0 * TUNING.elite_hp_mult))
	assert_float(enemy._base_damage).is_equal_approx(10.0 * TUNING.elite_damage_mult, 0.001)
	assert_int(enemy.get_pattern_layer_count()).is_equal(1 if TUNING.elite_pattern != null else 0)


func test_make_elite_is_idempotent() -> void:
	var enemy := _spawn(_type(GameEnums.EnemyArchetype.SEEKER, []))
	enemy.make_elite(TUNING)
	enemy.make_elite(TUNING)
	assert_int(enemy.get_max_hp()).is_equal(roundi(100.0 * TUNING.elite_hp_mult))


func test_boss_never_becomes_elite() -> void:
	var enemy := _spawn(_type(GameEnums.EnemyArchetype.BOSS, []))
	enemy.make_elite(TUNING)
	assert_bool(enemy.is_elite()).is_false()


func test_phase_changed_fires_when_hp_crosses_threshold() -> void:
	var gated := _fan()
	gated.hp_threshold = 0.5
	var enemy := _spawn(_type(GameEnums.EnemyArchetype.BOSS, [gated]))
	var phases: Array[int] = []
	enemy.phase_changed.connect(func(phase: int) -> void: phases.append(phase))
	enemy._tick_patterns(DT)          # full HP — samples 0 active gated layers
	assert_int(phases.size()).is_equal(0)
	enemy._current_hp = 40            # below 50 %
	enemy._tick_patterns(DT)
	assert_array(phases).contains_exactly([1])


func test_layers_sharing_a_threshold_count_as_one_phase() -> void:
	var a := _fan()
	a.hp_threshold = 0.33
	var b := _fan()
	b.hp_threshold = 0.33
	var c := _fan()
	c.hp_threshold = 0.66
	var enemy := _spawn(_type(GameEnums.EnemyArchetype.BOSS, [c, a, b]))
	var phases: Array[int] = []
	enemy.phase_changed.connect(func(phase: int) -> void: phases.append(phase))
	enemy._tick_patterns(DT)
	enemy._current_hp = 20            # one big hit crosses both thresholds
	enemy._tick_patterns(DT)
	assert_array(phases).contains_exactly([2])


func test_gated_layer_silent_above_threshold() -> void:
	var gated := _fan()
	gated.hp_threshold = 0.5
	var enemy := _spawn(_type(GameEnums.EnemyArchetype.BOSS, [gated]))
	enemy._tick_patterns(DT)
	assert_int(_live_bullets()).is_equal(0)


func test_death_pattern_fires_ring_on_death() -> void:
	var ring := BulletPattern.new()
	ring.shape = BulletPattern.Shape.RING
	ring.count = 10
	var et := _type(GameEnums.EnemyArchetype.SEEKER, [])
	et.death_pattern = ring
	var enemy := _spawn(et)
	enemy._on_enemy_killed(enemy.get_instance_id(), et.id, GameEnums.DamageClass.NONE)
	assert_int(_live_bullets()).is_equal(10)


func test_real_catalog_attackers_ship_with_pattern_layers() -> void:
	var catalog: Node = EnemyCatalogScript.new()
	catalog._ready()
	for id: int in [4, 6, 7, 8, 9]:  # Rifter, Spinner, Sniper, Mortar, Weaver
		assert_int(catalog.get_type(id).pattern_layers.size()).is_greater(0)
	assert_object(catalog.get_type(10).death_pattern).is_not_null()  # Splitter
	# ADR-0028 — each floor boss has its own layers: Sentinel 3, Warden 4, Keeper 5.
	assert_int(catalog.get_type(5).pattern_layers.size()).is_equal(3)
	assert_int(catalog.get_type(3).pattern_layers.size()).is_equal(4)
	assert_int(catalog.get_type(11).pattern_layers.size()).is_equal(5)
	catalog.free()
