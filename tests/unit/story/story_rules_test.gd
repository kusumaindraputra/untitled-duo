## story_rules_test.gd — memory-fragment unlock rules, endings and the shipped story (ADR-0027).
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const _PATH: String = "user://test_progress_story.cfg"


func _config(count: int) -> StoryConfig:
	var cfg := StoryConfig.new()
	for i: int in count:
		var f := MemoryFragment.new()
		f.id = StringName("frag_%d" % i)
		f.title = "Fragment %d" % i
		f.body = "Body %d" % i
		cfg.fragments.append(f)
	cfg.ending_partial = MemoryFragment.new()
	cfg.ending_partial.id = &"partial"
	cfg.ending_true = MemoryFragment.new()
	cfg.ending_true.id = &"true"
	cfg.death_unlock_min_rooms = 3
	cfg.ending_min_floor = 3
	return cfg


func after_test() -> void:
	if FileAccess.file_exists(_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_PATH))


# ── Beats ─────────────────────────────────────────────────────────────────────

func test_story_floor_clear_recovers_fragment() -> void:
	assert_bool(StoryRules.beat_recovers(StoryRules.Beat.FLOOR_CLEAR, 0, _config(3))).is_true()


func test_story_death_below_room_minimum_recovers_nothing() -> void:
	assert_bool(StoryRules.beat_recovers(StoryRules.Beat.DEATH, 2, _config(3))).is_false()


func test_story_death_at_room_minimum_recovers_fragment() -> void:
	assert_bool(StoryRules.beat_recovers(StoryRules.Beat.DEATH, 3, _config(3))).is_true()


func test_story_win_recovers_fragment() -> void:
	assert_bool(StoryRules.beat_recovers(StoryRules.Beat.WIN, 0, _config(3))).is_true()


func test_story_disabled_beats_recover_nothing() -> void:
	var cfg := _config(3)
	cfg.unlock_on_floor_clear = false
	cfg.unlock_on_death = false
	cfg.unlock_on_win = false
	assert_bool(StoryRules.beat_recovers(StoryRules.Beat.FLOOR_CLEAR, 9, cfg)).is_false()
	assert_bool(StoryRules.beat_recovers(StoryRules.Beat.DEATH, 9, cfg)).is_false()
	assert_bool(StoryRules.beat_recovers(StoryRules.Beat.WIN, 9, cfg)).is_false()


# ── Lookup ────────────────────────────────────────────────────────────────────

func test_story_fragment_at_out_of_range_is_null() -> void:
	var cfg := _config(2)
	assert_object(StoryRules.fragment_at(-1, cfg)).is_null()
	assert_object(StoryRules.fragment_at(2, cfg)).is_null()
	assert_str(String(StoryRules.fragment_at(1, cfg).id)).is_equal("frag_1")


func test_story_index_of_known_and_unknown_ids() -> void:
	var cfg := _config(3)
	assert_int(StoryRules.index_of(&"frag_2", cfg)).is_equal(2)
	assert_int(StoryRules.index_of(&"mem_worn_journal", cfg)).is_equal(-1)


# ── Endings ───────────────────────────────────────────────────────────────────

func test_story_win_before_ending_floor_plays_no_ending() -> void:
	assert_bool(StoryRules.plays_ending(1, _config(3))).is_false()


func test_story_win_on_ending_floor_plays_ending() -> void:
	assert_bool(StoryRules.plays_ending(3, _config(3))).is_true()


func test_story_missing_fragments_gives_partial_ending() -> void:
	var cfg := _config(3)
	assert_str(String(StoryRules.ending_for(2, cfg).id)).is_equal("partial")
	assert_bool(StoryRules.is_complete(2, cfg)).is_false()


func test_story_all_fragments_gives_true_ending() -> void:
	var cfg := _config(3)
	assert_str(String(StoryRules.ending_for(3, cfg).id)).is_equal("true")
	assert_bool(StoryRules.is_complete(3, cfg)).is_true()


func test_story_empty_story_is_never_complete() -> void:
	assert_bool(StoryRules.is_complete(0, _config(0))).is_false()


# ── MetaProgress ──────────────────────────────────────────────────────────────

func test_story_recover_fragment_advances_in_order() -> void:
	var p := MetaProgress.new()
	assert_int(p.recover_fragment(3)).is_equal(0)
	assert_int(p.recover_fragment(3)).is_equal(1)
	assert_int(p.fragments_found).is_equal(2)


func test_story_recover_fragment_when_complete_returns_minus_one() -> void:
	var p := MetaProgress.new()
	p.fragments_found = 3
	assert_int(p.recover_fragment(3)).is_equal(-1)
	assert_int(p.fragments_found).is_equal(3)


func test_story_record_ending_sets_matching_flag() -> void:
	var p := MetaProgress.new()
	p.record_ending(false)
	assert_bool(p.ending_seen).is_true()
	assert_bool(p.true_ending_seen).is_false()
	p.record_ending(true)
	assert_bool(p.true_ending_seen).is_true()


func test_story_progress_round_trips_through_save() -> void:
	var p := MetaProgress.new()
	p.fragments_found = 4
	p.ending_seen = true
	p.true_ending_seen = true
	assert_int(p.save_to(_PATH)).is_equal(OK)
	var loaded := MetaProgress.load_from(_PATH)
	assert_int(loaded.fragments_found).is_equal(4)
	assert_bool(loaded.ending_seen).is_true()
	assert_bool(loaded.true_ending_seen).is_true()


func test_story_old_save_without_story_fields_loads_zero() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "shards", 12)
	cfg.save(_PATH)
	var loaded := MetaProgress.load_from(_PATH)
	assert_int(loaded.fragments_found).is_equal(0)
	assert_bool(loaded.ending_seen).is_false()


# ── Shipped story ─────────────────────────────────────────────────────────────

func test_story_shipped_config_has_ten_complete_fragments() -> void:
	var cfg: StoryConfig = StoryRules.CONFIG
	assert_int(cfg.fragments.size()).is_equal(10)
	var ids: Dictionary[StringName, bool] = {}
	for f: MemoryFragment in cfg.fragments:
		assert_object(f).is_not_null()
		assert_str(f.title).is_not_empty()
		assert_str(f.body).is_not_empty()
		assert_bool(ids.has(f.id)).is_false()
		ids[f.id] = true


func test_story_shipped_config_has_both_endings() -> void:
	var cfg: StoryConfig = StoryRules.CONFIG
	assert_object(cfg.ending_partial).is_not_null()
	assert_object(cfg.ending_true).is_not_null()
	assert_str(cfg.ending_partial.body).is_not_empty()
	assert_str(cfg.ending_true.body).is_not_empty()
