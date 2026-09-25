## final_boss_test.gd — Unit tests for the Cipher Keeper final boss (ADR-0026).
##
## Coverage:
##   the Keeper's EnemyType is a BOSS with three distinct HP phases
##   the Floor 3 boss pool spawns the Keeper
##   phase → hazard table and banners
##   attach() ignores other bosses; a phase change spawns its hazard in the room
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const KEEPER: EnemyType = preload("res://assets/data/enemy_types/enemy_cipher_keeper.tres")
const BOSS_F3: EnemyPoolConfig = preload("res://assets/data/enemy_pool_configs/enemy_pool_boss_f3.tres")
const CFG: FinalBossConfig = preload("res://assets/data/final_boss/final_boss_config.tres")


## Stand-in boss exposing the calls FinalBossDirector uses.
class _FakeBoss extends Node2D:
	signal phase_changed(phase: int)
	var type_id: int = 0
	func get_type_id() -> int:
		return type_id


func test_final_boss_keeper_type_is_boss_with_three_phases() -> void:
	assert_int(KEEPER.id).is_equal(CFG.boss_type_id)
	assert_int(KEEPER.archetype).is_equal(GameEnums.EnemyArchetype.BOSS)
	var thresholds: Dictionary = {}
	for layer: Variant in KEEPER.pattern_layers:
		var p := layer as BulletPattern
		if p.hp_threshold < 1.0:
			thresholds[p.hp_threshold] = true
	assert_int(thresholds.size()).is_equal(CFG.breather_phase)


func test_final_boss_floor3_pool_spawns_keeper() -> void:
	assert_array(BOSS_F3.enemy_pool).contains_exactly([CFG.boss_type_id])
	assert_array(BOSS_F3.guaranteed_types).contains_exactly([CFG.boss_type_id])


func test_final_boss_catalog_serves_keeper() -> void:
	var et: EnemyType = EnemyCatalog.get_type(CFG.boss_type_id)
	assert_object(et).is_not_null()
	assert_str(et.name).is_equal("CipherKeeper")


func test_final_boss_hazards_for_phase_table() -> void:
	var p1: Array[HazardSpec] = FinalBossDirector.hazards_for_phase(CFG.sweep_phase)
	assert_int(p1.size()).is_equal(1)
	assert_int(p1[0].kind).is_equal(HazardSpec.Kind.SWEEP_LASER)
	var p2: Array[HazardSpec] = FinalBossDirector.hazards_for_phase(CFG.ring_phase)
	assert_int(p2.size()).is_equal(1)
	assert_int(p2[0].kind).is_equal(HazardSpec.Kind.CLOSING_RING)
	assert_array(FinalBossDirector.hazards_for_phase(CFG.breather_phase)).is_empty()


func test_final_boss_every_phase_has_a_banner() -> void:
	for phase: int in [1, 2, 3]:
		assert_str(FinalBossDirector.banner_for_phase(phase)).is_not_empty()
	assert_str(FinalBossDirector.banner_for_phase(0)).is_empty()


func test_final_boss_attach_ignores_other_bosses() -> void:
	var d := FinalBossDirector.new()
	var boss := _FakeBoss.new()
	boss.type_id = 5
	assert_bool(d.attach(boss, null)).is_false()
	assert_bool(boss.phase_changed.is_connected(d._on_phase_changed)).is_false()
	boss.free()
	d.free()


func test_final_boss_ring_phase_spawns_closing_ring_in_room() -> void:
	var d := FinalBossDirector.new()
	add_child(d)
	var room := Node2D.new()
	add_child(room)
	var boss := _FakeBoss.new()
	boss.type_id = CFG.boss_type_id
	room.add_child(boss)
	assert_bool(d.attach(boss, room)).is_true()
	var applied: Array[int] = []
	d.phase_applied.connect(func(p: int) -> void: applied.append(p))
	boss.phase_changed.emit(CFG.ring_phase)
	var rings: int = 0
	for c: Node in room.get_children():
		if c is HazardClosingRing:
			rings += 1
	assert_int(rings).is_equal(1)
	assert_int(applied.back()).is_equal(CFG.ring_phase)
	room.free()
	d.free()


func test_final_boss_skipped_phase_is_still_applied() -> void:
	var d := FinalBossDirector.new()
	add_child(d)
	var room := Node2D.new()
	add_child(room)
	var boss := _FakeBoss.new()
	boss.type_id = CFG.boss_type_id
	room.add_child(boss)
	d.attach(boss, room)
	var applied: Array[int] = []
	d.phase_applied.connect(func(p: int) -> void: applied.append(p))
	boss.phase_changed.emit(CFG.ring_phase)
	assert_array(applied).contains_exactly([CFG.sweep_phase, CFG.ring_phase])
	var sweeps: int = 0
	for c: Node in room.get_children():
		if c is HazardSweepLaser:
			sweeps += 1
	assert_int(sweeps).is_equal(1)
	room.free()
	d.free()
