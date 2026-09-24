## wave_reinforcement_test.gd — WaveManager reinforcements, elites, fire clearing (ADR-0018).
##
## Coverage:
##   _build_wave_composition tags entries with a reinforcement group and elite flag
##   _spawn_wave spawns group 0 only and queues the rest
##   A kill that drops the field to the trigger count spawns the next group
##   The wave completes only when every group has spawned and died
##   elite entries spawn as elites
extends GdUnitTestSuite

const WaveManagerScript = preload("res://src/systems/wave_manager.gd")
const _TEST_SCENE: PackedScene = preload(
	"res://tests/integration/wave-encounter-system/fixtures/EnemyTestScene.tscn"
)


func _make_wm() -> WaveManager:
	var wm: WaveManager = WaveManagerScript.new() as WaveManager
	add_child(wm)
	return wm


func _teardown(wm: WaveManager, container: Node) -> void:
	if container != null:
		remove_child(container)
		container.free()
	remove_child(wm)
	wm.free()


func _markers(count: int) -> Node:
	var container := Node.new()
	add_child(container)
	for i: int in count:
		var m := Node2D.new()
		m.position = Vector2(float(i) * 64.0, 0.0)
		container.add_child(m)
	return container


func _config(groups: int, trigger: int, elite: float = 0.0) -> EnemyPoolConfig:
	var cfg := EnemyPoolConfig.new()
	cfg.threat_budget_min = 6
	cfg.threat_budget_max = 6
	cfg.threat_cost = { 0: 1 }
	cfg.enemy_pool = [0]
	cfg.guaranteed_types = []
	cfg.reinforcement_groups = groups
	cfg.reinforcement_trigger_alive = trigger
	cfg.elite_chance = elite
	return cfg


func _composition(groups: Array[int], elite: bool = false) -> Array[Dictionary]:
	var comp: Array[Dictionary] = []
	for g: int in groups:
		comp.append({ "type_id": 0, "scene": _TEST_SCENE, "group": g, "elite": elite })
	return comp


func _enemy_children(wm: WaveManager) -> int:
	var n: int = 0
	for child: Node in wm.get_children():
		if child is EnemyInstance:
			n += 1
	return n


func test_composition_splits_into_groups() -> void:
	var wm := _make_wm()
	wm.enemy_pool_config = _config(2, 1)
	wm._build_wave_composition(7)
	var groups: Dictionary = {}
	for entry: Dictionary in wm._wave_composition:
		groups[int(entry["group"])] = true
	assert_int(wm._wave_composition.size()).is_equal(6)
	assert_array(groups.keys()).contains_exactly_in_any_order([0, 1])
	_teardown(wm, null)


func test_composition_elite_chance_one_marks_all_elite() -> void:
	var wm := _make_wm()
	wm.enemy_pool_config = _config(1, 0, 1.0)
	wm._build_wave_composition(3)
	for entry: Dictionary in wm._wave_composition:
		assert_bool(bool(entry["elite"])).is_true()
	_teardown(wm, null)


func test_composition_elite_chance_zero_marks_none() -> void:
	var wm := _make_wm()
	wm.enemy_pool_config = _config(1, 0, 0.0)
	wm._build_wave_composition(3)
	for entry: Dictionary in wm._wave_composition:
		assert_bool(bool(entry["elite"])).is_false()
	_teardown(wm, null)


func test_spawn_wave_spawns_first_group_only() -> void:
	var wm := _make_wm()
	var c := _markers(6)
	wm.spawn_points_container = c
	wm.enemy_pool_config = _config(2, 1)
	wm._wave_composition = _composition([0, 0, 0, 1, 1])
	wm._spawn_wave()
	assert_int(_enemy_children(wm)).is_equal(3)
	assert_int(wm._enemies_alive).is_equal(3)
	assert_int(wm._pending_groups.size()).is_equal(1)
	_teardown(wm, c)


func test_kill_to_trigger_spawns_next_group() -> void:
	var wm := _make_wm()
	var c := _markers(6)
	wm.spawn_points_container = c
	wm.enemy_pool_config = _config(2, 1)
	wm._wave_composition = _composition([0, 0, 0, 1, 1])
	wm._spawn_wave()
	wm._on_enemy_killed(0, 0, GameEnums.DamageClass.NONE)   # 2 alive — above trigger
	assert_int(wm._pending_groups.size()).is_equal(1)
	wm._on_enemy_killed(0, 0, GameEnums.DamageClass.NONE)   # 1 alive — trigger
	assert_int(wm._pending_groups.size()).is_equal(0)
	assert_int(wm._enemies_alive).is_equal(3)
	assert_int(wm._enemies_total).is_equal(5)
	assert_int(wm._wave_state).is_equal(WaveManager.WaveState.WAVE_ACTIVE)
	_teardown(wm, c)


func test_wave_completes_only_after_all_groups() -> void:
	var wm := _make_wm()
	var c := _markers(6)
	wm.spawn_points_container = c
	wm.enemy_pool_config = _config(2, 0)
	wm._wave_composition = _composition([0, 1])
	wm._spawn_wave()
	wm._on_enemy_killed(0, 0, GameEnums.DamageClass.NONE)   # group 0 dead → group 1 arrives
	assert_int(wm._wave_state).is_equal(WaveManager.WaveState.WAVE_ACTIVE)
	wm._on_enemy_killed(0, 0, GameEnums.DamageClass.NONE)
	assert_int(wm._wave_state).is_equal(WaveManager.WaveState.WAVE_COMPLETE)
	_teardown(wm, c)


func test_elite_entry_spawns_elite_enemy() -> void:
	var wm := _make_wm()
	var c := _markers(2)
	wm.spawn_points_container = c
	wm._wave_composition = _composition([0], true)
	wm._spawn_wave()
	for child: Node in wm.get_children():
		if child is EnemyInstance:
			assert_bool((child as EnemyInstance).is_elite()).is_true()
	_teardown(wm, c)
