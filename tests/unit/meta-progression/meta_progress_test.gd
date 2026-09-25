## meta_progress_test.gd — Cipher Shards, Heirlooms, Hard Mode and save/load (ADR-0025).
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const _PATH: String = "user://test_progress_meta.cfg"


func _tuning() -> MetaTuning:
	var t := MetaTuning.new()
	t.shards_per_floor = 10
	t.shards_per_room = 3
	t.kills_per_shard = 5
	t.win_bonus = 60
	t.hard_mode_shard_mult = 1.5
	t.heirloom_ids = [&"move_speed", &"damage"]
	t.heirloom_costs = [30, 45]
	t.hard_mode_wins_required = 1
	return t


func after_test() -> void:
	if FileAccess.file_exists(_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_PATH))


# ── Payout ────────────────────────────────────────────────────────────────────

func test_meta_shards_for_run_floor_rooms_kills() -> void:
	# 2 floors × 10 + 5 rooms × 3 + 12 kills / 5 = 20 + 15 + 2
	assert_int(MetaProgress.shards_for_run(_tuning(), 2, 5, 12, false, false)).is_equal(37)


func test_meta_shards_for_run_win_adds_bonus() -> void:
	assert_int(MetaProgress.shards_for_run(_tuning(), 3, 0, 0, true, false)).is_equal(90)


func test_meta_shards_for_run_hard_mode_multiplies() -> void:
	assert_int(MetaProgress.shards_for_run(_tuning(), 2, 0, 0, false, true)).is_equal(30)


func test_meta_shards_for_run_floor_zero_still_pays_one_floor() -> void:
	assert_int(MetaProgress.shards_for_run(_tuning(), 0, 0, 0, false, false)).is_equal(10)


func test_meta_record_run_updates_stats() -> void:
	var p := MetaProgress.new()
	var earned: int = p.record_run(_tuning(),
		{"current_floor": 2, "rooms_cleared": 4, "enemies_killed": 10}, true)
	assert_int(earned).is_equal(20 + 12 + 2 + 60)
	assert_int(p.shards).is_equal(earned)
	assert_int(p.lifetime_shards).is_equal(earned)
	assert_int(p.runs).is_equal(1)
	assert_int(p.wins).is_equal(1)
	assert_int(p.best_floor).is_equal(2)


func test_meta_record_run_best_floor_never_drops() -> void:
	var p := MetaProgress.new()
	p.best_floor = 3
	p.record_run(_tuning(), {"current_floor": 1}, false)
	assert_int(p.best_floor).is_equal(3)
	assert_int(p.wins).is_equal(0)


# ── Heirlooms ─────────────────────────────────────────────────────────────────

func test_meta_unlock_spends_shards_and_equips() -> void:
	var p := MetaProgress.new()
	p.shards = 50
	assert_bool(p.unlock(_tuning(), &"move_speed")).is_true()
	assert_int(p.shards).is_equal(20)
	assert_bool(p.is_unlocked(&"move_speed")).is_true()
	assert_str(String(p.run_heirloom())).is_equal("move_speed")


func test_meta_unlock_fails_when_too_poor() -> void:
	var p := MetaProgress.new()
	p.shards = 44
	assert_bool(p.unlock(_tuning(), &"damage")).is_false()
	assert_int(p.shards).is_equal(44)


func test_meta_unlock_twice_does_not_charge_again() -> void:
	var p := MetaProgress.new()
	p.shards = 100
	p.unlock(_tuning(), &"move_speed")
	assert_bool(p.unlock(_tuning(), &"move_speed")).is_false()
	assert_int(p.shards).is_equal(70)


func test_meta_unlock_unknown_id_fails() -> void:
	var p := MetaProgress.new()
	p.shards = 999
	assert_bool(p.unlock(_tuning(), &"overcharge")).is_false()


func test_meta_toggle_equip_clears_and_restores() -> void:
	var p := MetaProgress.new()
	p.shards = 30
	p.unlock(_tuning(), &"move_speed")
	assert_bool(p.toggle_equip(&"move_speed")).is_true()
	assert_str(String(p.run_heirloom())).is_equal("")
	p.toggle_equip(&"move_speed")
	assert_str(String(p.run_heirloom())).is_equal("move_speed")


func test_meta_toggle_equip_locked_is_refused() -> void:
	var p := MetaProgress.new()
	assert_bool(p.toggle_equip(&"damage")).is_false()
	assert_str(String(p.equipped)).is_equal("")


func test_meta_run_heirloom_ignores_locked_equipped_id() -> void:
	var p := MetaProgress.new()
	p.equipped = &"damage"  # e.g. a hand-edited save
	assert_str(String(p.run_heirloom())).is_equal("")


func test_meta_heirloom_info_reads_sigil_catalog() -> void:
	assert_str(str(MetaProgress.heirloom_info(&"dash_charge").get("title", ""))).is_not_empty()
	assert_bool(MetaProgress.heirloom_info(&"nope").is_empty()).is_true()


func test_meta_shipped_heirlooms_are_known_sigils_with_costs() -> void:
	var t: MetaTuning = load("res://assets/data/meta_tuning.tres")
	assert_int(t.heirloom_costs.size()).is_equal(t.heirloom_ids.size())
	for id: StringName in t.heirloom_ids:
		assert_bool(MetaProgress.heirloom_info(id).is_empty()) \
			.override_failure_message("unknown heirloom %s" % id).is_false()
		assert_int(t.cost_of(id)).is_greater(0)


# ── Hard Mode ─────────────────────────────────────────────────────────────────

func test_meta_hard_mode_locked_until_first_win() -> void:
	var p := MetaProgress.new()
	p.hard_mode = true
	assert_bool(p.hard_mode_active(_tuning())).is_false()
	p.wins = 1
	assert_bool(p.hard_mode_active(_tuning())).is_true()


func test_meta_apply_hard_mode_scales_copy_not_original() -> void:
	var t := MetaTuning.new()
	var cfg := EnemyPoolConfig.new()
	cfg.bullet_speed_mult = 1.1
	cfg.fire_rate_mult = 1.0
	cfg.telegraph_mult = 0.9
	cfg.threat_budget_min = 10
	cfg.threat_budget_max = 18
	cfg.enemy_count_max = 8
	cfg.elite_chance = 0.95
	var hard: EnemyPoolConfig = MetaProgress.apply_hard_mode(cfg, t)
	assert_float(hard.bullet_speed_mult).is_equal_approx(1.1 * t.hard_bullet_speed_mult, 0.0001)
	assert_float(hard.fire_rate_mult).is_equal_approx(t.hard_fire_rate_mult, 0.0001)
	assert_float(hard.telegraph_mult).is_equal_approx(0.9 * t.hard_telegraph_mult, 0.0001)
	assert_int(hard.threat_budget_min).is_equal(10 + t.hard_extra_enemies)
	assert_int(hard.enemy_count_max).is_equal(8 + t.hard_extra_enemies)
	assert_float(hard.elite_chance).is_equal(1.0)
	# Original untouched.
	assert_float(cfg.bullet_speed_mult).is_equal(1.1)
	assert_int(cfg.enemy_count_max).is_equal(8)


func test_meta_apply_hard_mode_keeps_uncapped_pools_uncapped() -> void:
	var cfg := EnemyPoolConfig.new()
	cfg.enemy_count_max = 0
	assert_int(MetaProgress.apply_hard_mode(cfg, MetaTuning.new()).enemy_count_max).is_equal(0)


# ── Persistence ───────────────────────────────────────────────────────────────

func test_meta_save_and_load_round_trip() -> void:
	var p := MetaProgress.new()
	p.shards = 17
	p.lifetime_shards = 120
	p.runs = 4
	p.wins = 1
	p.best_floor = 3
	p.unlocked = [&"move_speed", &"damage"]
	p.equipped = &"damage"
	p.hard_mode = true
	assert_int(p.save_to(_PATH)).is_equal(OK)
	var q: MetaProgress = MetaProgress.load_from(_PATH)
	assert_int(q.shards).is_equal(17)
	assert_int(q.lifetime_shards).is_equal(120)
	assert_int(q.runs).is_equal(4)
	assert_int(q.wins).is_equal(1)
	assert_int(q.best_floor).is_equal(3)
	assert_array(q.unlocked).contains_exactly([&"move_speed", &"damage"])
	assert_str(String(q.equipped)).is_equal("damage")
	assert_bool(q.hard_mode).is_true()


func test_meta_load_missing_file_gives_fresh_progress() -> void:
	var q: MetaProgress = MetaProgress.load_from("user://does_not_exist_meta.cfg")
	assert_int(q.shards).is_equal(0)
	assert_array(q.unlocked).is_empty()
	assert_bool(q.hard_mode).is_false()


func test_meta_load_clamps_negative_values() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "shards", -50)
	cfg.set_value("progress", "runs", -2)
	cfg.save(_PATH)
	var q: MetaProgress = MetaProgress.load_from(_PATH)
	assert_int(q.shards).is_equal(0)
	assert_int(q.runs).is_equal(0)
