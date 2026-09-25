## room_modifiers_test.gd — Unit tests for room variety rules (ADR-0026).
##
## Coverage:
##   assign() never modifies the entry room or non-combat rooms, and respects the cap
##   assign() is deterministic for a seeded RNG
##   apply_cursed() returns a harder copy and leaves the shared config untouched
##   picks_for / bonus_shards reward table
##   can_pay_wayshrine never lets the trade kill Fayde
##   HealthAndDamage.pay_fayde_hp spends HP, emits damage_taken, refuses lethal prices
##   SigilManager multi-pick bookkeeping, MetaProgress bonus shard payout
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const HealthAndDamageScript = preload("res://src/systems/health_and_damage.gd")
const META: MetaTuning = preload("res://assets/data/meta_tuning.tres")


## Entry combat → 4 combat → rest → boss, in a line.
func _make_graph() -> DungeonGraph:
	var g := DungeonGraph.new()
	var types: Array[int] = [0, 0, 0, 0, 0, DungeonGraph.ROOM_TYPE_REST, DungeonGraph.ROOM_TYPE_BOSS]
	for t: int in types:
		g.add_room(t)
	for i: int in types.size() - 1:
		g.add_edge(i, i + 1)
	return g


func _tuning(challenge: float, cursed: float, cap: int) -> RoomModifierTuning:
	var t := RoomModifierTuning.new()
	t.challenge_chance = challenge
	t.cursed_chance = cursed
	t.max_modified_per_floor = cap
	return t


func _seeded(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_room_modifiers_assign_skips_entry_and_non_combat() -> void:
	var g := _make_graph()
	var count: int = RoomModifiers.assign(g, _seeded(1), _tuning(1.0, 0.0, 99))
	assert_int(RoomModifiers.of(g, g.get_entry_room())).is_equal(RoomModifiers.NONE)
	assert_int(RoomModifiers.of(g, 5)).is_equal(RoomModifiers.NONE)
	assert_int(RoomModifiers.of(g, 6)).is_equal(RoomModifiers.NONE)
	for i: int in [1, 2, 3, 4]:
		assert_int(RoomModifiers.of(g, i)).is_equal(RoomModifiers.CHALLENGE)
	assert_int(count).is_equal(4)


func test_room_modifiers_assign_respects_floor_cap() -> void:
	var g := _make_graph()
	var count: int = RoomModifiers.assign(g, _seeded(1), _tuning(0.0, 1.0, 2))
	assert_int(count).is_equal(2)
	var cursed: int = 0
	for i: int in g.room_count():
		if RoomModifiers.of(g, i) == RoomModifiers.CURSED:
			cursed += 1
	assert_int(cursed).is_equal(2)


func test_room_modifiers_assign_zero_chance_leaves_all_none() -> void:
	var g := _make_graph()
	assert_int(RoomModifiers.assign(g, _seeded(3), _tuning(0.0, 0.0, 2))).is_equal(0)
	for i: int in g.room_count():
		assert_int(RoomModifiers.of(g, i)).is_equal(RoomModifiers.NONE)


func test_room_modifiers_assign_is_deterministic_for_seed() -> void:
	var a := _make_graph()
	var b := _make_graph()
	var t := _tuning(0.3, 0.3, 3)
	RoomModifiers.assign(a, _seeded(42), t)
	RoomModifiers.assign(b, _seeded(42), t)
	for i: int in a.room_count():
		assert_int(RoomModifiers.of(a, i)).is_equal(RoomModifiers.of(b, i))


func test_room_modifiers_apply_cursed_is_harder_copy() -> void:
	var t := RoomModifiers.TUNING
	var base := EnemyPoolConfig.new()
	base.enemy_count_max = 6
	var before_min: int = base.threat_budget_min
	var cursed: EnemyPoolConfig = RoomModifiers.apply_cursed(base)
	assert_object(cursed).is_not_same(base)
	assert_int(cursed.threat_budget_min).is_equal(before_min + t.cursed_extra_enemies)
	assert_int(cursed.enemy_count_max).is_equal(6 + t.cursed_extra_enemies)
	assert_float(cursed.elite_chance).is_equal_approx(base.elite_chance + t.cursed_elite_bonus, 0.001)
	assert_float(cursed.bullet_speed_mult).is_equal_approx(t.cursed_bullet_speed_mult, 0.001)
	assert_int(base.threat_budget_min).is_equal(before_min)
	assert_object(RoomModifiers.apply_cursed(null)).is_null()


func test_room_modifiers_reward_table() -> void:
	var t := RoomModifiers.TUNING
	assert_int(RoomModifiers.picks_for(RoomModifiers.NONE, true)).is_equal(1)
	assert_int(RoomModifiers.picks_for(RoomModifiers.CHALLENGE, true)).is_equal(t.challenge_picks)
	assert_int(RoomModifiers.picks_for(RoomModifiers.CHALLENGE, false)).is_equal(1)
	assert_int(RoomModifiers.picks_for(RoomModifiers.CURSED, false)).is_equal(t.cursed_picks)
	assert_int(RoomModifiers.bonus_shards(RoomModifiers.CHALLENGE, true)).is_equal(t.challenge_shards)
	assert_int(RoomModifiers.bonus_shards(RoomModifiers.CHALLENGE, false)).is_equal(0)
	assert_int(RoomModifiers.bonus_shards(RoomModifiers.CURSED, true)).is_equal(0)


func test_room_modifiers_wayshrine_never_lethal() -> void:
	var cost: int = RoomModifiers.TUNING.wayshrine_hp_cost
	assert_bool(RoomModifiers.can_pay_wayshrine(cost + 1)).is_true()
	assert_bool(RoomModifiers.can_pay_wayshrine(cost)).is_false()
	assert_bool(RoomModifiers.can_pay_wayshrine(1)).is_false()


func test_health_damage_pay_fayde_hp_spends_and_refuses_lethal() -> void:
	var hd: Node = HealthAndDamageScript.new()
	var fayde := Node.new()
	fayde.add_to_group(&"player")
	add_child(hd)
	add_child(fayde)
	hd._fayde_current_hp = 50
	var emitted: Array[int] = []
	hd.damage_taken.connect(func(_t: Node, d: int, _h: int) -> void: emitted.append(d))
	assert_bool(hd.pay_fayde_hp(20)).is_true()
	assert_int(hd.get_fayde_hp()).is_equal(30)
	assert_array(emitted).contains_exactly([20])
	assert_bool(hd.pay_fayde_hp(30)).is_false()
	assert_bool(hd.pay_fayde_hp(0)).is_false()
	assert_int(hd.get_fayde_hp()).is_equal(30)
	hd.free()
	fayde.free()


func test_sigil_manager_offer_counts_picks() -> void:
	var sm := SigilManager.new()
	add_child(sm)
	sm.offer_sigils(2)
	assert_int(sm.picks_left()).is_equal(2)
	var finished: Array[bool] = []
	sm.offer_finished.connect(func() -> void: finished.append(true))
	sm._on_sigil_chosen(&"prana_0")
	assert_int(sm.picks_left()).is_equal(1)
	assert_bool(get_tree().paused).is_true()
	assert_array(finished).is_empty()
	sm._on_sigil_chosen(&"prana_0")
	assert_int(sm.picks_left()).is_equal(0)
	assert_bool(get_tree().paused).is_false()
	assert_array(finished).has_size(1)
	sm.free()


func test_meta_progress_record_run_adds_bonus_shards() -> void:
	var p := MetaProgress.new()
	var data := {"current_floor": 1, "rooms_cleared": 0, "enemies_killed": 0}
	var base: int = p.record_run(META, data, false)
	var q := MetaProgress.new()
	data["bonus_shards"] = 8
	assert_int(q.record_run(META, data, false)).is_equal(base + 8)
