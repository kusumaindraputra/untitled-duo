## floor_enemies_test.gd — ADR-0053: one new enemy per floor (Pulsar, Wisp, Lancer).
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const EnemyCatalogScript = preload("res://src/data/enemy_catalog.gd")
const _COPY: UICopy = preload("res://assets/data/ui_copy.tres")
const ID_PULSAR: int = 12
const ID_WISP: int = 13
const ID_LANCER: int = 14
const NEW_IDS: Array[int] = [ID_PULSAR, ID_WISP, ID_LANCER]
## Floor each newcomer first appears on.
const FIRST_FLOOR: Dictionary = {ID_PULSAR: 1, ID_WISP: 2, ID_LANCER: 3}


func _catalog() -> Node:
	var c: Node = EnemyCatalogScript.new()
	c._ready()
	return c


func _pool(floor_num: int) -> EnemyPoolConfig:
	return load("res://assets/data/enemy_pool_configs/enemy_pool_floor%d.tres" % floor_num) as EnemyPoolConfig


func test_floor_enemies_are_spawnable_with_a_sheet_and_a_pattern() -> void:
	var c: Node = _catalog()
	for id: int in NEW_IDS:
		var et: EnemyType = c.get_type(id)
		assert_object(et).is_not_null()
		assert_int(et.status).is_equal(GameEnums.EnemyStatus.ACTIVE)
		assert_object(et.sprite_sheet).override_failure_message(et.name).is_not_null()
		assert_int(et.sprite_sheet.get_width() % PixelCharacter.FRAMES).is_equal(0)
		assert_int(et.sprite_sheet.get_height() % PixelCharacter.ROWS).is_equal(0)
		assert_int(et.pattern_layers.size()).is_greater(0)
	c.free()


func test_floor_enemies_shoot_mob_coloured_bullets() -> void:
	# ADR-0037: ordinary enemies use the mob core; boss accents stay reserved.
	var c: Node = _catalog()
	for id: int in NEW_IDS:
		for p: BulletPattern in c.get_type(id).pattern_layers:
			assert_str(String(p.accent)).is_equal(String(EnemyBulletPalette.DEFAULT_ACCENT))
	c.free()


func test_floor_enemies_join_their_floor_and_every_later_floor() -> void:
	for id: int in NEW_IDS:
		for floor_num: int in [1, 2, 3]:
			var cfg: EnemyPoolConfig = _pool(floor_num)
			var want: bool = floor_num >= int(FIRST_FLOOR[id])
			assert_bool(cfg.enemy_pool.has(id)).override_failure_message(
				"id %d on floor %d" % [id, floor_num]).is_equal(want)
			if want:
				assert_bool(cfg.threat_cost.has(id)).is_true()


func test_floor_enemies_each_have_a_distinct_pattern_shape() -> void:
	var c: Node = _catalog()
	var p1: BulletPattern = c.get_type(ID_PULSAR).pattern_layers[0]
	var p2: BulletPattern = c.get_type(ID_WISP).pattern_layers[0]
	var p3: BulletPattern = c.get_type(ID_LANCER).pattern_layers[0]
	assert_int(p1.shape).is_equal(BulletPattern.Shape.RING)
	assert_int(p2.motion).is_equal(BulletPattern.Motion.HOMING)
	assert_float(p3.speed_step).is_greater(0.0)
	c.free()


func test_floor_enemies_have_spellbook_notes() -> void:
	for id: int in NEW_IDS:
		assert_str(str(_COPY.spellbook_enemy_notes.get(id, ""))).is_not_empty()


func test_floor_enemy_threat_icons_read_as_their_role() -> void:
	var c: Node = _catalog()
	assert_int(ThreatIcon.kind_for(c.get_type(ID_WISP))).is_equal(ThreatIcon.Kind.SHOOTER)
	assert_int(ThreatIcon.kind_for(c.get_type(ID_LANCER))).is_equal(ThreatIcon.Kind.CHARGER)
	c.free()
