## pace_director_test.gd — PaceDirector room flow: rank, reward, style events (ADR-0019).
##
## PaceDirector is .new() (not in the tree), so signal handlers are called directly.
extends GdUnitTestSuite

const T: PaceTuning = preload("res://assets/data/pace_tuning.tres")


func after_test() -> void:
	SpellCastingEffects._on_preparation_started(0, 0)


func test_room_without_kills_is_not_ranked() -> void:
	var pd := PaceDirector.new()
	var ranks: Array = []
	pd.room_ranked.connect(func(r: String, _h: float, _m: float) -> void: ranks.append(r))
	pd._on_combat_started(false)
	pd.finish_room()
	assert_int(ranks.size()).is_equal(0)
	pd.free()


func test_room_rank_pays_reward_and_banks_meter_bonus() -> void:
	var pd := PaceDirector.new()
	var got: Array = []
	pd.room_ranked.connect(func(r: String, h: float, m: float) -> void: got.append([r, h, m]))
	pd._on_combat_started(false)
	pd._room_kills = 5
	pd.style.add(T.style_max)
	pd.style.tick(0.5)
	pd.finish_room()
	assert_int(got.size()).is_equal(1)
	assert_str(got[0][0]).is_equal("S")
	assert_float(got[0][1]).is_equal(StyleMeter.pick(T.rank_heal, StyleMeter.Rank.S))
	assert_float(pd.get_pending_meter_bonus()).is_equal(StyleMeter.pick(T.rank_meter_bonus, StyleMeter.Rank.S))
	pd.free()


func test_meter_bonus_applies_on_next_combat_start() -> void:
	SpellCastingEffects._on_preparation_started(0, 0)
	var pd := PaceDirector.new()
	pd._pending_meter_bonus = 25.0
	pd._on_combat_started(false)
	assert_float(SpellCastingEffects.get_special_meter()).is_equal_approx(25.0, 0.001)
	assert_float(pd.get_pending_meter_bonus()).is_equal(0.0)
	pd.free()


func test_finish_room_twice_ranks_once() -> void:
	var pd := PaceDirector.new()
	var n: Array = [0]
	pd.room_ranked.connect(func(_r: String, _h: float, _m: float) -> void: n[0] += 1)
	pd._on_combat_started(false)
	pd._room_kills = 1
	pd.finish_room()
	pd.finish_room()
	assert_int(n[0]).is_equal(1)
	pd.free()


func test_style_events_only_count_in_combat() -> void:
	var pd := PaceDirector.new()
	pd._on_grazed(Vector2.ZERO, 1.0)
	pd._on_perfect_cast(Vector2.ZERO, 1)
	assert_float(pd.style.get_value()).is_equal(0.0)
	pd._on_combat_started(false)
	pd._on_grazed(Vector2.ZERO, 1.0)
	pd._on_perfect_cast(Vector2.ZERO, 1)
	assert_float(pd.style.get_value()).is_equal_approx(T.style_graze + T.style_perfect_cast, 0.001)
	pd.free()


func test_player_damage_costs_style() -> void:
	var pd := PaceDirector.new()
	var player := Node2D.new()
	player.add_to_group(&"player")
	pd._on_combat_started(false)
	pd.style.add(50.0)
	pd._on_damage_taken(player, 5, 90)
	assert_float(pd.style.get_value()).is_equal(maxf(50.0 - T.style_hit_penalty, 0.0))
	pd._on_damage_taken(player, 0, 90)  # blocked hit: no penalty
	assert_float(pd.style.get_value()).is_equal(maxf(50.0 - T.style_hit_penalty, 0.0))
	pd.free()
	player.free()


func test_run_start_resets_style_and_bonus() -> void:
	var pd := PaceDirector.new()
	pd.style.add(40.0)
	pd._pending_meter_bonus = 10.0
	pd._on_run_started()
	assert_float(pd.style.get_value()).is_equal(0.0)
	assert_float(pd.get_pending_meter_bonus()).is_equal(0.0)
	pd.free()
