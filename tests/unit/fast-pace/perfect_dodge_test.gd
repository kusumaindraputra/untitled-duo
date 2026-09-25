## perfect_dodge_test.gd — Perfect Dodge rules (ADR-0019).
##
## Coverage:
##   PlayerController.register_perfect_dodge: dash-only, once per dash, cooldown, signal
##   SpellCastingEffects: add_special_meter, grant_perfect_cast window and expiry
##   PaceDirector: a Perfect Dodge adds meter, grants a free Perfect and style
##
## PlayerController / PaceDirector are .new() and never enter the tree. SCE is the
## autoload; its wave state is reset after each test.
extends GdUnitTestSuite

const PlayerControllerScript = preload("res://src/gameplay/player_controller.gd")
const T: PaceTuning = preload("res://assets/data/pace_tuning.tres")


func after_test() -> void:
	SpellCastingEffects._on_preparation_started(0, 0)
	Engine.time_scale = 1.0


func _dashing_player() -> PlayerController:
	var pc: PlayerController = PlayerControllerScript.new() as PlayerController
	pc._controller_state = PlayerController.ControllerState.DASHING
	pc._dash_duration_timer = PlayerController.DASH_DURATION
	return pc


func test_perfect_dodge_requires_a_dash() -> void:
	var pc: PlayerController = PlayerControllerScript.new() as PlayerController
	pc._controller_state = PlayerController.ControllerState.ENABLED
	pc._is_invincible = true  # post-hit grace is not a dash
	assert_bool(pc.register_perfect_dodge(Vector2.ZERO)).is_false()
	pc.free()


func test_perfect_dodge_counts_once_per_dash() -> void:
	var pc := _dashing_player()
	var hits: Array = []
	pc.perfect_dodged.connect(func(p: Vector2) -> void: hits.append(p))
	assert_bool(pc.register_perfect_dodge(Vector2(3, 4))).is_true()
	assert_bool(pc.register_perfect_dodge(Vector2(5, 6))).is_false()
	assert_int(hits.size()).is_equal(1)
	assert_that(hits[0]).is_equal(Vector2(3, 4))
	pc.free()


func test_perfect_dodge_cooldown_blocks_next_dash() -> void:
	var pc := _dashing_player()
	pc.register_perfect_dodge(Vector2.ZERO)
	# A new dash starts while the cooldown is still running.
	pc._perfect_dodged_this_dash = false
	assert_bool(pc.register_perfect_dodge(Vector2.ZERO)).is_false()
	pc._perfect_dodge_cd = 0.0
	assert_bool(pc.register_perfect_dodge(Vector2.ZERO)).is_true()
	pc.free()


func test_sce_add_special_meter_adds_and_ignores_negative() -> void:
	SpellCastingEffects._on_preparation_started(0, 0)
	SpellCastingEffects.add_special_meter(7.5)
	SpellCastingEffects.add_special_meter(-3.0)
	assert_float(SpellCastingEffects.get_special_meter()).is_equal_approx(7.5, 0.001)


func test_sce_grant_perfect_cast_expires() -> void:
	SpellCastingEffects._on_preparation_started(0, 0)
	SpellCastingEffects.grant_perfect_cast(0.5)
	assert_bool(SpellCastingEffects.has_free_perfect()).is_true()
	SpellCastingEffects._process(0.6)
	assert_bool(SpellCastingEffects.has_free_perfect()).is_false()


func test_sce_preparation_clears_free_perfect() -> void:
	SpellCastingEffects.grant_perfect_cast(2.0)
	SpellCastingEffects._on_preparation_started(0, 0)
	assert_bool(SpellCastingEffects.has_free_perfect()).is_false()


func test_pace_director_perfect_dodge_rewards() -> void:
	SpellCastingEffects._on_preparation_started(0, 0)
	var pd := PaceDirector.new()
	var seen: Array = []
	pd.perfect_dodge_triggered.connect(func(p: Vector2) -> void: seen.append(p))
	pd._on_perfect_dodged(Vector2(1, 2))
	assert_float(SpellCastingEffects.get_special_meter()).is_equal_approx(T.perfect_dodge_meter_gain, 0.001)
	assert_bool(SpellCastingEffects.has_free_perfect()).is_equal(T.perfect_dodge_cast_window_sec > 0.0)
	assert_float(pd.style.get_value()).is_equal(T.style_perfect_dodge)
	assert_int(seen.size()).is_equal(1)
	pd.free()
