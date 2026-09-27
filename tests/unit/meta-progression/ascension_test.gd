## ascension_test.gd — Ascension ladder above Hard Mode (ADR-0052).
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const _PATH: String = "user://test_progress_ascension.cfg"
const _SHIPPED: AscensionConfig = preload("res://assets/data/ascension/ascension_config.tres")
const _COPY: UICopy = preload("res://assets/data/ui_copy.tres")
const _META: MetaTuning = preload("res://assets/data/meta_tuning.tres")


func _level(hp: float, boss_hp: float, heal: float, extra: int, bonus: float) -> AscensionLevel:
	var l := AscensionLevel.new()
	l.enemy_hp_mult = hp
	l.boss_hp_mult = boss_hp
	l.heal_mult = heal
	l.extra_enemies = extra
	l.shard_bonus = bonus
	return l


## Two-level ladder: +10 % enemy HP, then +20 % boss HP, half healing and one enemy.
func _tuning() -> MetaTuning:
	var t := MetaTuning.new()
	t.hard_mode_wins_required = 1
	t.hard_mode_shard_mult = 1.5
	t.ascension = AscensionConfig.new()
	t.ascension.levels = [_level(1.1, 1.0, 1.0, 0, 0.1), _level(1.0, 1.2, 0.5, 1, 0.1)]
	return t


func _hard_progress() -> MetaProgress:
	var p := MetaProgress.new()
	p.wins = 1
	p.hard_mode = true
	return p


func after_test() -> void:
	if FileAccess.file_exists(_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_PATH))


# ── Stacking ──────────────────────────────────────────────────────────────────

func test_ascension_stacked_level_zero_is_neutral() -> void:
	var s: AscensionLevel = _tuning().ascension.stacked(0)
	assert_float(s.enemy_hp_mult).is_equal(1.0)
	assert_float(s.heal_mult).is_equal(1.0)
	assert_int(s.extra_enemies).is_equal(0)
	assert_float(s.shard_bonus).is_equal(0.0)


func test_ascension_stacked_multiplies_and_adds_levels() -> void:
	var s: AscensionLevel = _tuning().ascension.stacked(2)
	assert_float(s.enemy_hp_mult).is_equal_approx(1.1, 0.0001)
	assert_float(s.boss_hp_mult).is_equal_approx(1.2, 0.0001)
	assert_float(s.heal_mult).is_equal_approx(0.5, 0.0001)
	assert_int(s.extra_enemies).is_equal(1)
	assert_float(s.shard_bonus).is_equal_approx(0.2, 0.0001)


func test_ascension_stacked_clamps_past_the_top() -> void:
	var t := _tuning()
	assert_float(t.ascension.stacked(99).shard_bonus).is_equal_approx(0.2, 0.0001)


func test_ascension_apply_scales_copy_not_original() -> void:
	var cfg := EnemyPoolConfig.new()
	cfg.threat_budget_min = 10
	cfg.threat_budget_max = 18
	cfg.enemy_count_max = 8
	var out: EnemyPoolConfig = _tuning().ascension.apply(cfg, 2)
	assert_float(out.enemy_hp_mult).is_equal_approx(1.1, 0.0001)
	assert_float(out.boss_hp_mult).is_equal_approx(1.2, 0.0001)
	assert_int(out.threat_budget_min).is_equal(11)
	assert_int(out.enemy_count_max).is_equal(9)
	assert_float(cfg.enemy_hp_mult).is_equal(1.0)
	assert_int(cfg.enemy_count_max).is_equal(8)


func test_ascension_apply_level_zero_returns_same_config() -> void:
	var cfg := EnemyPoolConfig.new()
	assert_object(_tuning().ascension.apply(cfg, 0)).is_same(cfg)


# ── Unlocking and picking ─────────────────────────────────────────────────────

func test_ascension_inactive_without_hard_mode() -> void:
	var p := _hard_progress()
	p.ascension_unlocked = 2
	p.ascension = 2
	p.hard_mode = false
	assert_int(p.active_ascension(_tuning())).is_equal(0)


func test_ascension_active_is_capped_by_unlocked() -> void:
	var p := _hard_progress()
	p.ascension_unlocked = 1
	p.ascension = 2
	assert_int(p.active_ascension(_tuning())).is_equal(1)


func test_ascension_hard_win_unlocks_next_level() -> void:
	var p := _hard_progress()
	p.record_run(_tuning(), {"current_floor": 3}, true)
	assert_int(p.ascension_unlocked).is_equal(1)


func test_ascension_win_below_top_level_unlocks_nothing() -> void:
	var p := _hard_progress()
	p.ascension_unlocked = 2
	p.ascension = 0
	var t := _tuning()
	t.ascension.levels.append(_level(1.0, 1.0, 1.0, 0, 0.0))
	p.record_run(t, {"current_floor": 3}, true)
	assert_int(p.ascension_unlocked).is_equal(2)


func test_ascension_loss_unlocks_nothing() -> void:
	var p := _hard_progress()
	p.record_run(_tuning(), {"current_floor": 2}, false)
	assert_int(p.ascension_unlocked).is_equal(0)


func test_ascension_normal_win_unlocks_nothing() -> void:
	var p := _hard_progress()
	p.hard_mode = false
	p.record_run(_tuning(), {"current_floor": 3}, true)
	assert_int(p.ascension_unlocked).is_equal(0)


func test_ascension_never_unlocks_past_the_top() -> void:
	var p := _hard_progress()
	p.ascension_unlocked = 2
	p.ascension = 2
	p.record_run(_tuning(), {"current_floor": 3}, true)
	assert_int(p.ascension_unlocked).is_equal(2)


func test_ascension_cycle_wraps_through_unlocked_levels() -> void:
	var p := _hard_progress()
	p.ascension_unlocked = 2
	var t := _tuning()
	assert_int(p.cycle_ascension(t)).is_equal(1)
	assert_int(p.cycle_ascension(t)).is_equal(2)
	assert_int(p.cycle_ascension(t)).is_equal(0)
	assert_int(p.cycle_ascension(t, -1)).is_equal(2)


func test_ascension_cycle_stays_zero_when_locked() -> void:
	var p := _hard_progress()
	assert_int(p.cycle_ascension(_tuning())).is_equal(0)


func test_ascension_shard_bonus_adds_to_hard_mode_mult() -> void:
	# 2 floors × 10 = 20 shards; Hard Mode 1.5 + two levels × 0.1 = 1.7 → 34.
	var t := _tuning()
	t.shards_per_floor = 10
	t.shards_per_room = 0
	t.win_bonus = 0
	var p := _hard_progress()
	p.ascension_unlocked = 2
	p.ascension = 2
	assert_int(p.record_run(t, {"current_floor": 2}, false)).is_equal(34)


func test_ascension_apply_on_progress_uses_active_level() -> void:
	var p := _hard_progress()
	p.ascension_unlocked = 1
	p.ascension = 1
	var out: EnemyPoolConfig = p.apply_ascension(EnemyPoolConfig.new(), _tuning())
	assert_float(out.enemy_hp_mult).is_equal_approx(1.1, 0.0001)


# ── Save / load ───────────────────────────────────────────────────────────────

func test_ascension_save_load_round_trip() -> void:
	var p := _hard_progress()
	p.ascension_unlocked = 3
	p.ascension = 2
	assert_int(p.save_to(_PATH)).is_equal(OK)
	var q: MetaProgress = MetaProgress.load_from(_PATH)
	assert_int(q.ascension_unlocked).is_equal(3)
	assert_int(q.ascension).is_equal(2)


func test_ascension_load_clamps_pick_to_unlocked() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "ascension", 5)
	cfg.set_value("progress", "ascension_unlocked", 1)
	cfg.save(_PATH)
	assert_int(MetaProgress.load_from(_PATH).ascension).is_equal(1)


func test_ascension_old_save_loads_at_zero() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "wins", 2)
	cfg.save(_PATH)
	var q: MetaProgress = MetaProgress.load_from(_PATH)
	assert_int(q.ascension_unlocked).is_equal(0)
	assert_int(q.ascension).is_equal(0)


# ── Shipped data ──────────────────────────────────────────────────────────────

func test_ascension_shipped_ladder_has_copy_for_every_level() -> void:
	assert_int(_SHIPPED.max_level()).is_greater(0)
	assert_int(_COPY.ascension_level_descs.size()).is_equal(_SHIPPED.max_level())


func test_ascension_shipped_levels_only_get_harder() -> void:
	for v: Variant in _SHIPPED.levels:  # a const-preloaded typed array iterates as Variant
		var l: AscensionLevel = v as AscensionLevel
		assert_float(l.enemy_hp_mult).is_greater_equal(1.0)
		assert_float(l.boss_hp_mult).is_greater_equal(1.0)
		assert_float(l.bullet_speed_mult).is_greater_equal(1.0)
		assert_float(l.fire_rate_mult).is_greater_equal(1.0)
		assert_float(l.telegraph_mult).is_less_equal(1.0)
		assert_float(l.heal_mult).is_less_equal(1.0)
		assert_int(l.extra_enemies).is_greater_equal(0)
		assert_float(l.shard_bonus).is_greater_equal(0.0)


func test_ascension_meta_tuning_ships_the_ladder() -> void:
	assert_object(_META.ascension).is_not_null()
	assert_int(MetaProgress.max_ascension(_META)).is_equal(_SHIPPED.max_level())


func test_ascension_heal_mult_scales_fayde_heals() -> void:
	var fayde := Node2D.new()
	fayde.add_to_group(&"player")
	var before_mult: float = HealthAndDamage.player_heal_mult
	var before_hp: int = HealthAndDamage._fayde_current_hp
	HealthAndDamage._fayde_current_hp = 10
	HealthAndDamage.player_heal_mult = 0.5
	HealthAndDamage.apply_heal(fayde, 20.0)
	assert_int(HealthAndDamage.get_fayde_hp()).is_equal(20)
	HealthAndDamage.player_heal_mult = before_mult
	HealthAndDamage._fayde_current_hp = before_hp
	fayde.free()


func test_ascension_enemy_hp_mult_scales_max_hp() -> void:
	var e := EnemyInstance.new()
	e.set(&"_max_hp", 100)
	e.apply_hp_mult(1.1)
	assert_int(e.get_max_hp()).is_equal(110)
	e.free()


func test_ascension_debug_game_loop_compiles() -> void:
	var script: GDScript = load("res://src/scenes/debug_game_loop.gd") as GDScript
	assert_object(script).is_not_null()
	assert_bool(script.can_instantiate()).is_true()


func test_ascension_menu_text_is_three_lines_at_the_top_level() -> void:
	var menu_script: GDScript = load("res://src/scenes/main_menu.gd") as GDScript
	var text: String = menu_script.call(&"ascension_text", _SHIPPED.max_level())
	assert_int(text.split("\n").size()).is_equal(3)
	assert_str(menu_script.call(&"ascension_text", 0)).is_empty()
