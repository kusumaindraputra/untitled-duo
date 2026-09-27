## big_moments_room_clear_test.gd — room clear moment: slow-mo, CLEAR banner, orb pull,
## door burst and the DeferredWarp it relies on (ADR-0041).
extends GdUnitTestSuite

const T: BigMomentTuning = preload("res://assets/data/big_moment_tuning.tres")
const COPY: UICopy = preload("res://assets/data/ui_copy.tres")


func after_test() -> void:
	Engine.time_scale = 1.0


# ── DeferredWarp ──────────────────────────────────────────────────────────────

func test_deferred_warp_applies_at_once_when_time_is_free() -> void:
	var w := DeferredWarp.new()
	w.request(0.3, 0.2, 0.3)
	assert_bool(w.tick(get_tree(), 0.0)).is_true()
	assert_bool(w.was_applied()).is_true()
	assert_float(Engine.time_scale).is_equal_approx(0.3, 0.0001)


func test_deferred_warp_waits_for_hitstop_then_applies() -> void:
	var w := DeferredWarp.new()
	Engine.time_scale = 0.05  # a kill hitstop
	w.request(0.3, 0.2, 0.3)
	assert_bool(w.tick(get_tree(), 0.05)).is_false()
	assert_bool(w.is_pending()).is_true()
	assert_float(Engine.time_scale).is_equal_approx(0.05, 0.0001)
	Engine.time_scale = 1.0  # hitstop ended
	assert_bool(w.tick(get_tree(), 0.05)).is_true()
	assert_float(Engine.time_scale).is_equal_approx(0.3, 0.0001)


func test_deferred_warp_gives_up_after_wait() -> void:
	var w := DeferredWarp.new()
	Engine.time_scale = 0.05
	w.request(0.3, 0.2, 0.1)
	w.tick(get_tree(), 0.2)
	assert_bool(w.is_pending()).is_false()
	Engine.time_scale = 1.0
	assert_bool(w.tick(get_tree(), 0.0)).is_false()
	assert_float(Engine.time_scale).is_equal(1.0)


# ── RoomClearMoment ───────────────────────────────────────────────────────────

func test_should_play_needs_kills_and_a_non_boss_room() -> void:
	assert_bool(RoomClearMoment.should_play(3, DungeonGraph.ROOM_TYPE_COMBAT)).is_true()
	assert_bool(RoomClearMoment.should_play(1, DungeonGraph.ROOM_TYPE_ELITE)).is_true()
	assert_bool(RoomClearMoment.should_play(0, DungeonGraph.ROOM_TYPE_REST)).is_false()
	assert_bool(RoomClearMoment.should_play(0, DungeonGraph.ROOM_TYPE_COMBAT)).is_false()
	assert_bool(RoomClearMoment.should_play(5, DungeonGraph.ROOM_TYPE_BOSS)).is_false()


func test_kills_count_only_during_combat() -> void:
	var m := RoomClearMoment.new()
	m._on_enemy_killed(1, 0, GameEnums.DamageClass.NONE)
	assert_int(m.get_room_kills()).is_equal(0)
	m._on_combat_started(false)
	m._on_enemy_killed(1, 0, GameEnums.DamageClass.NONE)
	m._on_enemy_killed(2, 0, GameEnums.DamageClass.NONE)
	assert_int(m.get_room_kills()).is_equal(2)
	m.free()


func test_cleared_room_plays_once_with_banner_and_slowmo() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var m := RoomClearMoment.new()
	m.banner_layer = layer
	add_child(m)
	var plays: Array[int] = [0]
	m.played.connect(func() -> void: plays[0] += 1)
	m._on_combat_started(false)
	m._on_enemy_killed(1, 0, GameEnums.DamageClass.NONE)
	m.finish_room()
	m.finish_room()
	assert_int(plays[0]).is_equal(1)
	var banner: ClearBanner = layer.get_node_or_null(^"ClearBanner") as ClearBanner
	assert_object(banner).is_not_null()
	assert_str(banner.get_text()).is_equal(COPY.room_clear_banner)
	assert_float(Engine.time_scale).is_equal_approx(T.clear_slowmo_scale, 0.0001)
	m.free()
	layer.free()


func test_empty_room_clear_plays_nothing() -> void:
	var m := RoomClearMoment.new()
	var plays: Array[int] = [0]
	m.played.connect(func() -> void: plays[0] += 1)
	m._on_combat_started(false)
	m.finish_room()
	assert_int(plays[0]).is_equal(0)
	m.free()


func test_reward_waits_for_the_banner_beat() -> void:
	assert_float(RoomClearMoment.reward_delay_sec()).is_equal_approx(T.clear_in_sec + T.clear_hold_sec, 0.0001)
	var quick := BigMomentTuning.new()
	quick.clear_in_sec = 0.1
	quick.clear_hold_sec = 0.1
	assert_float(RoomClearMoment.reward_delay_sec(quick)).is_equal(0.5)


func test_clear_copy_is_set() -> void:
	assert_str(COPY.room_clear_banner).is_not_empty()


# ── ClearBanner ───────────────────────────────────────────────────────────────

func test_clear_rule_grows_to_full_width() -> void:
	assert_float(ClearBanner.rule_half_width(0.0, false)).is_equal(0.0)
	assert_float(ClearBanner.rule_half_width(1.0, false)).is_equal_approx(ClearBanner.RULE_WIDTH * 0.5, 0.0001)
	assert_float(ClearBanner.rule_half_width(0.0, true)).is_equal_approx(ClearBanner.RULE_WIDTH * 0.5, 0.0001)


# ── Orb pull ──────────────────────────────────────────────────────────────────

func test_orb_pull_eases_in_then_runs_full_speed() -> void:
	assert_float(PickupOrb.pull_ramp(0.0)).is_equal_approx(PickupOrb.PULL_START, 0.0001)
	var mid: float = PickupOrb.pull_ramp(T.orb_pull_ramp_sec * 0.5)
	assert_float(mid).is_greater(PickupOrb.PULL_START)
	assert_float(mid).is_less(1.0)
	assert_float(PickupOrb.pull_ramp(T.orb_pull_ramp_sec * 2.0)).is_equal(1.0)


func test_pulled_orb_still_reaches_fayde() -> void:
	var orb := PickupOrb.new()
	orb.position = Vector2(400.0, 0.0)
	orb.magnetize(3.0)
	var arrived: bool = false
	for i: int in 600:
		if orb.step(1.0 / 60.0, Vector2.ZERO):
			arrived = true
			break
	assert_bool(arrived).is_true()
	orb.free()


# ── Door burst ────────────────────────────────────────────────────────────────

func test_door_bursts_when_it_unlocks() -> void:
	var door := RoomExitDoor.new()
	add_child(door)
	assert_bool(door.is_bursting()).is_false()
	door._on_room_cleared()
	assert_bool(door.is_bursting()).is_true()
	door.free()


# ── Shake hook ────────────────────────────────────────────────────────────────

func test_shake_hook_is_safe_with_or_without_screen_shake() -> void:
	var has_autoload: bool = get_tree().root.get_node_or_null(ShakeHook.AUTOLOAD_PATH) != null
	assert_bool(ShakeHook.impact(ShakeHook.MASSIVE)).is_equal(has_autoload)
