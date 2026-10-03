## final_boss_test.gd — Unit tests for the Cipher Keeper final boss (ADR-0026).
## Since ADR-0028 the Keeper's arena data is its profile in the boss roster and
## BossDirector (was FinalBossDirector) runs it.
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
const ROSTER: BossRoster = preload("res://assets/data/bosses/boss_roster.tres")
const KEEPER_ID: int = 11
const SWEEP_PHASE: int = 1
const RING_PHASE: int = 2
const BREATHER_PHASE: int = 3


## Stand-in boss exposing the calls BossDirector uses.
class _FakeBoss extends Node2D:
	signal phase_changed(phase: int)
	var type_id: int = 0
	func get_type_id() -> int:
		return type_id


func _keeper() -> BossProfile:
	return ROSTER.profile_for(KEEPER_ID)


func test_final_boss_keeper_type_is_boss_with_three_phases() -> void:
	assert_int(KEEPER.id).is_equal(KEEPER_ID)
	assert_int(KEEPER.archetype).is_equal(GameEnums.EnemyArchetype.BOSS)
	var thresholds: Dictionary = {}
	for layer: Variant in KEEPER.pattern_layers:
		var p := layer as BulletPattern
		if p.hp_threshold < 1.0:
			thresholds[p.hp_threshold] = true
	assert_int(thresholds.size()).is_equal(BREATHER_PHASE)


func test_final_boss_floor3_pool_spawns_keeper() -> void:
	assert_array(BOSS_F3.enemy_pool).contains_exactly([KEEPER_ID])
	assert_array(BOSS_F3.guaranteed_types).contains_exactly([KEEPER_ID])


func test_final_boss_catalog_serves_keeper() -> void:
	var et: EnemyType = EnemyCatalog.get_type(KEEPER_ID)
	assert_object(et).is_not_null()
	assert_str(et.name).is_equal("ShadeKeeper")


func test_final_boss_hazards_for_phase_table() -> void:
	var p1: Array[HazardSpec] = BossDirector.hazards_for_phase(_keeper(), SWEEP_PHASE)
	assert_int(p1.size()).is_equal(1)
	assert_int(p1[0].kind).is_equal(HazardSpec.Kind.SWEEP_LASER)
	var p2: Array[HazardSpec] = BossDirector.hazards_for_phase(_keeper(), RING_PHASE)
	assert_int(p2.size()).is_equal(1)
	assert_int(p2[0].kind).is_equal(HazardSpec.Kind.CLOSING_RING)
	assert_array(BossDirector.hazards_for_phase(_keeper(), BREATHER_PHASE)).is_empty()
	assert_bool(BossDirector.clears_bullets(_keeper(), BREATHER_PHASE)).is_true()


func test_final_boss_every_phase_has_a_banner() -> void:
	for phase: int in [1, 2, 3]:
		assert_str(BossDirector.banner_for_phase(_keeper(), phase)).is_not_empty()
	assert_str(BossDirector.banner_for_phase(_keeper(), 0)).is_empty()


func test_final_boss_attach_ignores_enemies_outside_roster() -> void:
	var d := BossDirector.new()
	var boss := _FakeBoss.new()
	boss.type_id = 7  # Sniper: not a boss, not in the roster
	assert_bool(d.attach(boss, null)).is_false()
	assert_bool(boss.phase_changed.is_connected(d._on_phase_changed)).is_false()
	boss.free()
	d.free()


func test_final_boss_ring_phase_spawns_closing_ring_in_room() -> void:
	var d := BossDirector.new()
	add_child(d)
	var room := Node2D.new()
	add_child(room)
	var boss := _FakeBoss.new()
	boss.type_id = KEEPER_ID
	room.add_child(boss)
	assert_bool(d.attach(boss, room)).is_true()
	var applied: Array[int] = []
	d.phase_applied.connect(func(p: int) -> void: applied.append(p))
	boss.phase_changed.emit(RING_PHASE)
	var rings: int = 0
	for c: Node in room.get_children():
		if c is HazardClosingRing:
			rings += 1
	assert_int(rings).is_equal(1)
	assert_int(applied.back()).is_equal(RING_PHASE)
	room.free()
	d.free()


func test_final_boss_skipped_phase_is_still_applied() -> void:
	var d := BossDirector.new()
	add_child(d)
	var room := Node2D.new()
	add_child(room)
	var boss := _FakeBoss.new()
	boss.type_id = KEEPER_ID
	room.add_child(boss)
	d.attach(boss, room)
	var applied: Array[int] = []
	d.phase_applied.connect(func(p: int) -> void: applied.append(p))
	boss.phase_changed.emit(RING_PHASE)
	assert_array(applied).contains_exactly([SWEEP_PHASE, RING_PHASE])
	var sweeps: int = 0
	for c: Node in room.get_children():
		if c is HazardSweepLaser:
			sweeps += 1
	assert_int(sweeps).is_equal(1)
	room.free()
	d.free()
