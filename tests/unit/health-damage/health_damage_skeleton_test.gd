## health_damage_skeleton_test.gd — Unit tests for HealthAndDamage (Autoload #5).
##
## Coverage: AC-HD-01, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14, 15, 17,
##           17b, 18, 19, 20, 21, 22, 23, 24, 26, 27, 28, 29, 30, 31, 32, 33
##
## Signal assertions use Array[int] counters — GDScript 4 lambdas capture
## primitives by value; arrays are captured by reference.
##
## Framework: GDUnit4 v6.1.3
## Run: godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd
##      -a res://tests/unit/health-damage/health_damage_skeleton_test.gd --ignoreHeadlessMode
extends GdUnitTestSuite

const HealthAndDamageScript = preload("res://src/systems/health_and_damage.gd")
const EnemyCatalogScript = preload("res://src/data/enemy_catalog.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_hd() -> Node:
	var hd: Node = HealthAndDamageScript.new()
	hd.set_process(false)
	return hd


func _make_fayde() -> Node:
	var node: Node = Node.new()
	node.add_to_group(&"player")
	return node


func _make_enemy_node() -> Node:
	return Node.new()


func _make_catalog_with(types: Array[EnemyType]) -> Node:
	var catalog: Node = EnemyCatalogScript.new()
	for entry: EnemyType in types:
		catalog._types[entry.id] = entry
	catalog._initialized = true
	return catalog


func _make_enemy_type(id: int, base_hp: int) -> EnemyType:
	var et := EnemyType.new()
	et.id = id
	et.name = "TestEnemy_%d" % id
	et.archetype = GameEnums.EnemyArchetype.SEEKER
	et.prana_affiliation = GameEnums.DamageClass.NONE
	et.base_hp = base_hp
	et.base_damage = 5.0
	et.base_move_speed = 60.0
	et.status = GameEnums.EnemyStatus.ACTIVE
	et.wave_threat_value = 1
	return et


## Registers an enemy directly into hd._enemy_registry without going through EnemyCatalog Autoload.
func _register_enemy_direct(hd: Node, enemy_node: Node, et: EnemyType) -> void:
	var rec := EnemyHPInstance.new()
	rec.max_hp = et.base_hp
	rec.current_hp = et.base_hp
	rec.type_id = et.id
	rec.prana_affiliation = et.prana_affiliation
	hd._enemy_registry[enemy_node.get_instance_id()] = rec


## Seeds Fayde HP and zone tracker without emitting signals.
func _set_fayde_hp_and_zone(hd: Node, hp: int) -> void:
	hd._fayde_current_hp = hp
	var careful: int = roundi(float(hd.FAYDE_MAX_HP) * hd.FAYDE_HP_CRITICAL_CAREFUL)
	var desperate: int = roundi(float(hd.FAYDE_MAX_HP) * hd.FAYDE_HP_CRITICAL_DESPERATE)
	if hp <= desperate:
		hd._current_zone = GameEnums.HPZone.DESPERATE
	elif hp <= careful:
		hd._current_zone = GameEnums.HPZone.CAREFUL
	else:
		hd._current_zone = GameEnums.HPZone.FULL


# ── AC-HD-18: register_enemy current_hp == catalog base_hp ───────────────────

func test_health_damage_register_enemy_current_hp_equals_catalog_base_hp() -> void:
	var et: EnemyType = _make_enemy_type(0, 30)
	var catalog: Node = _make_catalog_with([et])
	var hd: Node = _make_hd()
	var enemy_node: Node = _make_enemy_node()
	add_child(hd)
	add_child(enemy_node)
	_register_enemy_direct(hd, enemy_node, catalog.get_type(0))
	assert_int(hd._enemy_registry[enemy_node.get_instance_id()].current_hp).is_equal(30)


func test_health_damage_register_enemy_max_hp_equals_current_hp_at_spawn() -> void:
	var et: EnemyType = _make_enemy_type(1, 45)
	var catalog: Node = _make_catalog_with([et])
	var hd: Node = _make_hd()
	var enemy_node: Node = _make_enemy_node()
	add_child(hd)
	add_child(enemy_node)
	_register_enemy_direct(hd, enemy_node, catalog.get_type(1))
	var rec = hd._enemy_registry[enemy_node.get_instance_id()]
	assert_int(rec.max_hp).is_equal(45)
	assert_int(rec.current_hp).is_equal(rec.max_hp)


func test_health_damage_register_enemy_distinct_types_get_distinct_hp() -> void:
	var cat: Node = _make_catalog_with([
		_make_enemy_type(0, 20), _make_enemy_type(1, 35), _make_enemy_type(2, 12)
	])
	var hd: Node = _make_hd()
	var e0: Node = _make_enemy_node()
	var e1: Node = _make_enemy_node()
	var e2: Node = _make_enemy_node()
	add_child(hd); add_child(e0); add_child(e1); add_child(e2)
	_register_enemy_direct(hd, e0, cat.get_type(0))
	_register_enemy_direct(hd, e1, cat.get_type(1))
	_register_enemy_direct(hd, e2, cat.get_type(2))
	assert_int(hd._enemy_registry[e0.get_instance_id()].current_hp).is_equal(20)
	assert_int(hd._enemy_registry[e1.get_instance_id()].current_hp).is_equal(35)
	assert_int(hd._enemy_registry[e2.get_instance_id()].current_hp).is_equal(12)


# ── AC-HD-17/17b: run_started resets all state ────────────────────────────────

func test_health_damage_run_started_resets_fayde_hp_to_max() -> void:
	var hd: Node = _make_hd()
	add_child(hd)
	_set_fayde_hp_and_zone(hd, 25)
	hd._fayde_dead = true
	hd._on_run_started()
	assert_int(hd._fayde_current_hp).is_equal(hd.FAYDE_MAX_HP)
	assert_bool(hd._fayde_dead).is_false()


func test_health_damage_run_started_clears_registry_iframe_and_dead_flag() -> void:
	var hd: Node = _make_hd()
	var e: Node = _make_enemy_node()
	add_child(hd); add_child(e)
	_register_enemy_direct(hd, e, _make_enemy_type(0, 10))
	hd._fayde_dead = true
	hd._iframe_active = true
	hd._on_run_started()
	assert_bool(hd._enemy_registry.is_empty()).is_true()
	assert_bool(hd._fayde_dead).is_false()
	assert_bool(hd._iframe_active).is_false()


# ── AC-HD-01: Fayde 100 HP, hit 20, HP=80, damage_taken emitted ──────────────

func test_health_damage_neutral_hit_reduces_hp_and_emits_damage_taken() -> void:
	var hd: Node = _make_hd()
	var fayde: Node = _make_fayde()
	add_child(hd); add_child(fayde)
	hd._fayde_current_hp = 100
	var cnt: Array[int] = [0]
	hd.damage_taken.connect(func(_t, _d, _h): cnt[0] += 1)
	hd.apply_damage(fayde, 20.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.CONTACT)
	assert_int(hd._fayde_current_hp).is_equal(80)
	assert_int(cnt[0]).is_equal(1)


# ── AC-HD-04: Overkill clamps to 0 ───────────────────────────────────────────

func test_health_damage_overkill_clamps_hp_to_zero() -> void:
	var hd: Node = _make_hd()
	var fayde: Node = _make_fayde()
	add_child(hd); add_child(fayde)
	_set_fayde_hp_and_zone(hd, 10)
	hd.apply_damage(fayde, 50.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.DIRECT)
	assert_int(hd._fayde_current_hp).is_equal(0)


# ── AC-HD-05: Zero damage → no HP change, no signal ─────────────────────────

func test_health_damage_zero_damage_no_hp_change_no_signal() -> void:
	var hd: Node = _make_hd()
	var fayde: Node = _make_fayde()
	add_child(hd); add_child(fayde)
	hd._fayde_current_hp = 100
	var cnt: Array[int] = [0]
	hd.damage_taken.connect(func(_t, _d, _h): cnt[0] += 1)
	hd.apply_damage(fayde, 0.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.DIRECT)
	assert_int(hd._fayde_current_hp).is_equal(100)
	assert_int(cnt[0]).is_equal(0)


# ── AC-HD-06: Second CONTACT blocked during i-frame ──────────────────────────

func test_health_damage_second_contact_blocked_during_iframe() -> void:
	var hd: Node = _make_hd()
	var fayde: Node = _make_fayde()
	add_child(hd); add_child(fayde)
	hd._fayde_current_hp = 100
	hd.apply_damage(fayde, 10.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.CONTACT)
	var hp_after_first: int = hd._fayde_current_hp
	var cnt: Array[int] = [0]
	hd.damage_taken.connect(func(_t, _d, _h): cnt[0] += 1)
	hd.apply_damage(fayde, 10.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.CONTACT)
	assert_int(hd._fayde_current_hp).is_equal(hp_after_first)
	assert_int(cnt[0]).is_equal(0)


# ── AC-HD-07: force_end_iframe_window allows next CONTACT ────────────────────

func test_health_damage_force_end_iframe_allows_next_contact() -> void:
	var hd: Node = _make_hd()
	var fayde: Node = _make_fayde()
	add_child(hd); add_child(fayde)
	hd._fayde_current_hp = 100
	hd.apply_damage(fayde, 10.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.CONTACT)
	var hp_after_first: int = hd._fayde_current_hp
	hd.force_end_iframe_window()
	hd.apply_damage(fayde, 10.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.CONTACT)
	assert_int(hd._fayde_current_hp).is_equal(hp_after_first - 10)


# ── AC-HD-08: DOT bypasses i-frame ───────────────────────────────────────────

func test_health_damage_dot_bypasses_iframe() -> void:
	var hd: Node = _make_hd()
	var fayde: Node = _make_fayde()
	add_child(hd); add_child(fayde)
	hd._fayde_current_hp = 100
	hd.apply_damage(fayde, 10.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.CONTACT)
	var hp_after_contact: int = hd._fayde_current_hp
	hd.apply_damage(fayde, 5.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.DOT)
	assert_int(hd._fayde_current_hp).is_equal(hp_after_contact - 5)


# ── AC-HD-27: DIRECT bypasses i-frame ────────────────────────────────────────

func test_health_damage_direct_bypasses_iframe() -> void:
	var hd: Node = _make_hd()
	var fayde: Node = _make_fayde()
	add_child(hd); add_child(fayde)
	hd._fayde_current_hp = 100
	hd.apply_damage(fayde, 10.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.CONTACT)
	var hp_after_contact: int = hd._fayde_current_hp
	hd.apply_damage(fayde, 15.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.DIRECT)
	assert_int(hd._fayde_current_hp).is_equal(hp_after_contact - 15)


# ── AC-HD-09: Heal bypasses i-frame ──────────────────────────────────────────

func test_health_damage_heal_bypasses_iframe() -> void:
	var hd: Node = _make_hd()
	var fayde: Node = _make_fayde()
	add_child(hd); add_child(fayde)
	hd._fayde_current_hp = 80
	hd.apply_damage(fayde, 10.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.CONTACT)
	var hp_after_hit: int = hd._fayde_current_hp
	hd.apply_heal(fayde, 10.0)
	assert_int(hd._fayde_current_hp).is_equal(hp_after_hit + 10)


# ── AC-HD-10: Heal clamp at max HP ───────────────────────────────────────────

func test_health_damage_heal_clamps_at_max_hp() -> void:
	var hd: Node = _make_hd()
	var fayde: Node = _make_fayde()
	add_child(hd); add_child(fayde)
	_set_fayde_hp_and_zone(hd, 80)
	hd.apply_heal(fayde, 30.0)
	assert_int(hd._fayde_current_hp).is_equal(hd.FAYDE_MAX_HP)


# ── AC-HD-11: Heal at max HP — no signal ─────────────────────────────────────

func test_health_damage_heal_at_max_hp_no_signal() -> void:
	var hd: Node = _make_hd()
	var fayde: Node = _make_fayde()
	add_child(hd); add_child(fayde)
	hd._fayde_current_hp = hd.FAYDE_MAX_HP
	var cnt: Array[int] = [0]
	hd.health_restored.connect(func(_t, _a, _h): cnt[0] += 1)
	hd.apply_heal(fayde, 10.0)
	assert_int(cnt[0]).is_equal(0)


# ── AC-HD-12: Partial heal emits health_restored ─────────────────────────────

func test_health_damage_partial_heal_emits_health_restored() -> void:
	var hd: Node = _make_hd()
	var fayde: Node = _make_fayde()
	add_child(hd); add_child(fayde)
	_set_fayde_hp_and_zone(hd, 10)
	var cnt: Array[int] = [0]
	var healed: Array[int] = [0]
	var hp_after: Array[int] = [0]
	hd.health_restored.connect(func(_t, amount: int, current: int): cnt[0] += 1; healed[0] = amount; hp_after[0] = current)
	hd.apply_heal(fayde, 6.0)
	assert_int(hd._fayde_current_hp).is_equal(16)
	assert_int(cnt[0]).is_equal(1)
	assert_int(healed[0]).is_equal(6)
	assert_int(hp_after[0]).is_equal(16)


# ── AC-HD-13: Enemy killed → enemy_killed emitted, registry erased ───────────

func test_health_damage_enemy_killed_signal_and_registry_erase() -> void:
	var hd: Node = _make_hd()
	var enemy_node: Node = _make_enemy_node()
	add_child(hd); add_child(enemy_node)
	_register_enemy_direct(hd, enemy_node, _make_enemy_type(0, 5))
	var cnt: Array[int] = [0]
	hd.enemy_killed.connect(func(_id, _tid, _pa): cnt[0] += 1)
	hd.apply_damage(enemy_node, 5.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.DIRECT)
	assert_int(cnt[0]).is_equal(1)
	assert_int(hd._enemy_registry.size()).is_equal(0)


# ── AC-HD-14: Fayde lethal hit → player_died emitted ─────────────────────────

func test_health_damage_fayde_lethal_hit_emits_player_died() -> void:
	var hd: Node = _make_hd()
	var fayde: Node = _make_fayde()
	add_child(hd); add_child(fayde)
	_set_fayde_hp_and_zone(hd, 10)
	var cnt: Array[int] = [0]
	hd.player_died.connect(func(): cnt[0] += 1)
	hd.apply_damage(fayde, 15.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.CONTACT)
	assert_int(hd._fayde_current_hp).is_equal(0)
	assert_int(cnt[0]).is_equal(1)


# ── AC-HD-15: Dead Fayde — player_died not re-emitted ────────────────────────

func test_health_damage_dead_fayde_no_re_emit_player_died() -> void:
	var hd: Node = _make_hd()
	var fayde: Node = _make_fayde()
	add_child(hd); add_child(fayde)
	hd._fayde_current_hp = 1
	hd.apply_damage(fayde, 5.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.DIRECT)
	var cnt: Array[int] = [0]
	hd.player_died.connect(func(): cnt[0] += 1)
	hd.apply_damage(fayde, 20.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.DIRECT)
	assert_int(hd._fayde_current_hp).is_equal(0)
	assert_int(cnt[0]).is_equal(0)


# ── AC-HD-19: HP crossing CAREFUL threshold emits zone signal ────────────────

func test_health_damage_crossing_careful_threshold_emits_zone_signal() -> void:
	var hd: Node = _make_hd()
	var fayde: Node = _make_fayde()
	add_child(hd); add_child(fayde)
	_set_fayde_hp_and_zone(hd, 45)
	var cnt: Array[int] = [0]
	hd.player_hp_zone_changed.connect(func(_z): cnt[0] += 1)
	hd.apply_damage(fayde, 6.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.DIRECT)
	assert_int(cnt[0]).is_equal(1)
	assert_int(hd._current_zone).is_equal(GameEnums.HPZone.CAREFUL)


# ── AC-HD-20: Second hit within CAREFUL — zone signal NOT re-emitted ─────────

func test_health_damage_second_hit_within_careful_no_zone_signal() -> void:
	var hd: Node = _make_hd()
	var fayde: Node = _make_fayde()
	add_child(hd); add_child(fayde)
	_set_fayde_hp_and_zone(hd, 35)
	var cnt: Array[int] = [0]
	hd.player_hp_zone_changed.connect(func(_z): cnt[0] += 1)
	hd.apply_damage(fayde, 5.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.DIRECT)
	assert_int(hd._fayde_current_hp).is_equal(30)
	assert_int(hd._current_zone).is_equal(GameEnums.HPZone.CAREFUL)
	assert_int(cnt[0]).is_equal(0)


# ── AC-HD-21: CAREFUL → DESPERATE emits DESPERATE only ───────────────────────

func test_health_damage_careful_to_desperate_emits_desperate_only() -> void:
	var hd: Node = _make_hd()
	var fayde: Node = _make_fayde()
	add_child(hd); add_child(fayde)
	_set_fayde_hp_and_zone(hd, 25)
	var zones: Array = []
	hd.player_hp_zone_changed.connect(func(z): zones.append(z))
	hd.apply_damage(fayde, 10.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.DIRECT)
	assert_int(hd._fayde_current_hp).is_equal(15)
	assert_int(hd._current_zone).is_equal(GameEnums.HPZone.DESPERATE)
	assert_int(zones.size()).is_equal(1)
	assert_int(zones[0]).is_equal(GameEnums.HPZone.DESPERATE)


# ── AC-HD-22: Large heal from DESPERATE skips CAREFUL, emits FULL only ────────

func test_health_damage_desperate_to_full_heal_emits_full_only() -> void:
	var hd: Node = _make_hd()
	var fayde: Node = _make_fayde()
	add_child(hd); add_child(fayde)
	_set_fayde_hp_and_zone(hd, 10)
	var zones: Array = []
	hd.player_hp_zone_changed.connect(func(z): zones.append(z))
	hd.apply_heal(fayde, 95.0)
	assert_int(hd._fayde_current_hp).is_equal(hd.FAYDE_MAX_HP)
	assert_int(hd._current_zone).is_equal(GameEnums.HPZone.FULL)
	assert_int(zones.size()).is_equal(1)
	assert_int(zones[0]).is_equal(GameEnums.HPZone.FULL)


# ── AC-HD-26: Partial heal DESPERATE → CAREFUL emits CAREFUL not FULL ─────────

func test_health_damage_partial_heal_desperate_to_careful_emits_careful() -> void:
	var hd: Node = _make_hd()
	var fayde: Node = _make_fayde()
	add_child(hd); add_child(fayde)
	_set_fayde_hp_and_zone(hd, 10)
	var zones: Array = []
	hd.player_hp_zone_changed.connect(func(z): zones.append(z))
	hd.apply_heal(fayde, 15.0)
	assert_int(hd._fayde_current_hp).is_equal(25)
	assert_int(hd._current_zone).is_equal(GameEnums.HPZone.CAREFUL)
	assert_int(zones.size()).is_equal(1)
	assert_int(zones[0]).is_equal(GameEnums.HPZone.CAREFUL)


# ── AC-HD-23: Dead-target guard — no signal for dead Fayde ───────────────────

func test_health_damage_dead_target_guard_no_signal_no_hp_change() -> void:
	var hd: Node = _make_hd()
	var fayde: Node = _make_fayde()
	add_child(hd); add_child(fayde)
	hd._fayde_current_hp = 0
	hd._fayde_dead = true
	var dt_cnt: Array[int] = [0]
	var pd_cnt: Array[int] = [0]
	hd.damage_taken.connect(func(_t, _d, _h): dt_cnt[0] += 1)
	hd.player_died.connect(func(): pd_cnt[0] += 1)
	hd.apply_damage(fayde, 20.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.CONTACT)
	assert_int(hd._fayde_current_hp).is_equal(0)
	assert_int(dt_cnt[0]).is_equal(0)
	assert_int(pd_cnt[0]).is_equal(0)


# ── AC-HD-24: Negative heal — no HP change, no signal ────────────────────────

func test_health_damage_negative_heal_is_no_op() -> void:
	var hd: Node = _make_hd()
	var fayde: Node = _make_fayde()
	add_child(hd); add_child(fayde)
	_set_fayde_hp_and_zone(hd, 50)
	var cnt: Array[int] = [0]
	hd.health_restored.connect(func(_t, _a, _h): cnt[0] += 1)
	hd.apply_heal(fayde, -10.0)
	assert_int(hd._fayde_current_hp).is_equal(50)
	assert_int(cnt[0]).is_equal(0)


# ── AC-HD-28: heavy_hit emitted when final_damage >= threshold ───────────────

func test_health_damage_heavy_hit_emitted_above_threshold() -> void:
	var hd: Node = _make_hd()
	var fayde: Node = _make_fayde()
	add_child(hd); add_child(fayde)
	hd._fayde_current_hp = 100
	var dt_cnt: Array[int] = [0]
	var hh_cnt: Array[int] = [0]
	hd.damage_taken.connect(func(_t, _d, _h): dt_cnt[0] += 1)
	hd.heavy_hit.connect(func(_t, _d): hh_cnt[0] += 1)
	hd.apply_damage(fayde, 20.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.DIRECT)
	assert_int(dt_cnt[0]).is_equal(1)
	assert_int(hh_cnt[0]).is_equal(1)


# ── AC-HD-29: heavy_hit NOT emitted below threshold ──────────────────────────

func test_health_damage_heavy_hit_not_emitted_below_threshold() -> void:
	var hd: Node = _make_hd()
	var fayde: Node = _make_fayde()
	add_child(hd); add_child(fayde)
	hd._fayde_current_hp = 100
	var dt_cnt: Array[int] = [0]
	var hh_cnt: Array[int] = [0]
	hd.damage_taken.connect(func(_t, _d, _h): dt_cnt[0] += 1)
	hd.heavy_hit.connect(func(_t, _d): hh_cnt[0] += 1)
	hd.apply_damage(fayde, 4.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.DIRECT)
	assert_int(dt_cnt[0]).is_greater(0)
	assert_int(hh_cnt[0]).is_equal(0)


# ── AC-HD-30: first_run_active halves CONTACT damage ─────────────────────────

func test_health_damage_first_run_active_halves_contact_damage() -> void:
	var hd: Node = _make_hd()
	var fayde: Node = _make_fayde()
	add_child(hd); add_child(fayde)
	hd._fayde_current_hp = 100
	hd.first_run_active = true
	hd.apply_damage(fayde, 20.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.CONTACT)
	assert_int(hd._fayde_current_hp).is_equal(90)


# ── AC-HD-31: first_run_active false → full damage ───────────────────────────

func test_health_damage_first_run_inactive_applies_full_damage() -> void:
	var hd: Node = _make_hd()
	var fayde: Node = _make_fayde()
	add_child(hd); add_child(fayde)
	hd._fayde_current_hp = 100
	hd.first_run_active = false
	hd.apply_damage(fayde, 20.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.CONTACT)
	assert_int(hd._fayde_current_hp).is_equal(80)


# ── AC-HD-32: run_started from DESPERATE emits FULL zone signal ──────────────

func test_health_damage_run_started_from_desperate_emits_full_zone_signal() -> void:
	var hd: Node = _make_hd()
	add_child(hd)
	_set_fayde_hp_and_zone(hd, 10)
	var cnt: Array[int] = [0]
	hd.player_hp_zone_changed.connect(func(_z): cnt[0] += 1)
	hd._on_run_started()
	assert_int(hd._fayde_current_hp).is_equal(hd.FAYDE_MAX_HP)
	assert_int(hd._current_zone).is_equal(GameEnums.HPZone.FULL)
	assert_int(cnt[0]).is_greater(0)


# ── AC-HD-33: i-frame re-arm — window2 blocks third CONTACT hit ──────────────

func test_health_damage_iframe_rearm_blocks_third_contact() -> void:
	var hd: Node = _make_hd()
	var fayde: Node = _make_fayde()
	add_child(hd); add_child(fayde)
	hd._fayde_current_hp = 100
	hd.apply_damage(fayde, 10.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.CONTACT)
	hd.force_end_iframe_window()
	hd.apply_damage(fayde, 10.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.CONTACT)
	var hp_after_hit2: int = hd._fayde_current_hp
	var cnt: Array[int] = [0]
	hd.damage_taken.connect(func(_t, _d, _h): cnt[0] += 1)
	hd.apply_damage(fayde, 10.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.CONTACT)
	assert_int(hd._fayde_current_hp).is_equal(hp_after_hit2)
	assert_int(cnt[0]).is_equal(0)
