## health_damage_debug_kill_test.gd — debug_kill_all_enemies() must not strand
## reinforcements that register while it is killing (the F2 QA key and balance bot).
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const HealthAndDamageScript = preload("res://src/systems/health_and_damage.gd")


func _make_hd() -> Node:
	var hd: Node = HealthAndDamageScript.new()
	hd.set_process(false)
	return hd


func _register(hd: Node, enemy: Node) -> void:
	var rec := EnemyHPInstance.new()
	rec.max_hp = 10
	rec.current_hp = 10
	hd._enemy_registry[enemy.get_instance_id()] = rec


func test_health_damage_debug_kill_empties_registry_and_emits_per_enemy() -> void:
	var hd: Node = _make_hd()
	var a := Node.new()
	var b := Node.new()
	_register(hd, a)
	_register(hd, b)
	var kills: Array[int] = [0]
	hd.enemy_killed.connect(func(_id: int, _t: int, _p: int) -> void: kills[0] += 1)

	hd.debug_kill_all_enemies()

	assert_int(kills[0]).is_equal(2)
	assert_int(hd._enemy_registry.size()).is_equal(0)
	a.free()
	b.free()
	hd.free()


## Regression: a kill that spawns a reinforcement (WaveManager, ADR-0018) registered it
## mid-loop, then registry.clear() dropped it, leaving an enemy no spell could damage.
func test_health_damage_debug_kill_also_kills_reinforcements_spawned_by_a_kill() -> void:
	var hd: Node = _make_hd()
	var first := Node.new()
	var reinforcement := Node.new()
	_register(hd, first)
	var spawned: Array[bool] = [false]
	var killed_ids: Array[int] = []
	hd.enemy_killed.connect(func(id: int, _t: int, _p: int) -> void:
		killed_ids.append(id)
		if not spawned[0]:
			spawned[0] = true
			_register(hd, reinforcement))

	hd.debug_kill_all_enemies()

	assert_array(killed_ids).contains_exactly([first.get_instance_id(), reinforcement.get_instance_id()])
	assert_bool(hd._enemy_registry.has(reinforcement.get_instance_id())).is_false()
	first.free()
	reinforcement.free()
	hd.free()


func test_health_damage_debug_kill_on_empty_registry_is_a_no_op() -> void:
	var hd: Node = _make_hd()
	var kills: Array[int] = [0]
	hd.enemy_killed.connect(func(_id: int, _t: int, _p: int) -> void: kills[0] += 1)

	hd.debug_kill_all_enemies()

	assert_int(kills[0]).is_equal(0)
	hd.free()
