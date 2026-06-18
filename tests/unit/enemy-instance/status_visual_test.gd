## status_visual_test.gd — Unit tests for EnemyInstance status effect tint visuals.
##
## Coverage:
##   AC: apply_status_visual(FREEZE) sets icy-blue modulate immediately.
##   AC: apply_status_visual(CHILL) sets light-blue modulate immediately.
##   AC: apply_status_visual(BURN) starts a looping tween (modulate moves from WHITE).
##   AC: apply_status_visual(STAGGER) delegates to request_hit_flash (overbright white).
##   AC: apply_status_visual kills the previous _status_tween before starting a new one.
##   AC: clear_status_visual kills _status_tween on a tinted enemy.
##
## GdUnit4 v6.1.3 | Godot 4.6
extends GdUnitTestSuite


func _make_enemy() -> EnemyInstance:
	var e := EnemyInstance.new()
	add_child(e)
	auto_free(e)
	return e


# ── AC: FREEZE sets icy-blue modulate ────────────────────────────────────────

## GIVEN enemy at Color.WHITE
## WHEN apply_status_visual(FREEZE, 2.0) is called
## THEN modulate is immediately set to icy-blue Color(0.5, 0.8, 1.4, 1.0)
func test_apply_status_visual_freeze_sets_icy_blue() -> void:
	var enemy := _make_enemy()
	enemy.modulate = Color.WHITE

	enemy.apply_status_visual(GameEnums.BaseStatus.FREEZE, 2.0)

	assert_float(enemy.modulate.r).is_equal_approx(0.5, 0.01)
	assert_float(enemy.modulate.g).is_equal_approx(0.8, 0.01)
	assert_float(enemy.modulate.b).is_equal_approx(1.4, 0.01)
	assert_float(enemy.modulate.a).is_equal_approx(1.0, 0.01)


# ── AC: CHILL sets light-blue modulate ───────────────────────────────────────

## GIVEN enemy at Color.WHITE
## WHEN apply_status_visual(CHILL, 1.5) is called
## THEN modulate is immediately set to light-blue Color(0.8, 0.9, 1.2, 1.0)
func test_apply_status_visual_chill_sets_light_blue() -> void:
	var enemy := _make_enemy()
	enemy.modulate = Color.WHITE

	enemy.apply_status_visual(GameEnums.BaseStatus.CHILL, 1.5)

	assert_float(enemy.modulate.r).is_equal_approx(0.8, 0.01)
	assert_float(enemy.modulate.g).is_equal_approx(0.9, 0.01)
	assert_float(enemy.modulate.b).is_equal_approx(1.2, 0.01)
	assert_float(enemy.modulate.a).is_equal_approx(1.0, 0.01)


# ── AC: BURN starts a looping tween ──────────────────────────────────────────

## GIVEN enemy at Color.WHITE
## WHEN apply_status_visual(BURN, 2.0) is called
## THEN after one process frame modulate is no longer pure WHITE (tween is running)
func test_apply_status_visual_burn_changes_modulate_from_white() -> void:
	var enemy := _make_enemy()
	enemy.modulate = Color.WHITE

	enemy.apply_status_visual(GameEnums.BaseStatus.BURN, 2.0)

	await get_tree().process_frame
	# Burn tween targets Color(1.6, 0.5, 0.1) — any deviation from WHITE confirms tween is active.
	var still_white: bool = (
		is_equal_approx(enemy.modulate.r, 1.0)
		and is_equal_approx(enemy.modulate.g, 1.0)
		and is_equal_approx(enemy.modulate.b, 1.0)
	)
	assert_bool(still_white).is_false()


# ── AC: STAGGER delegates to request_hit_flash (overbright white) ─────────────

## GIVEN enemy at Color.WHITE
## WHEN apply_status_visual(STAGGER, 0.3) is called
## THEN modulate is immediately set to overbright (r > 1.0)
func test_apply_status_visual_stagger_triggers_overbright_flash() -> void:
	var enemy := _make_enemy()
	enemy.modulate = Color.WHITE

	enemy.apply_status_visual(GameEnums.BaseStatus.STAGGER, 0.3)

	assert_float(enemy.modulate.r).is_greater(1.0)


# ── AC: new call kills previous _status_tween ────────────────────────────────

## GIVEN FREEZE is already active (icy-blue tint + status_tween running)
## WHEN apply_status_visual(CHILL, 1.5) is called
## THEN modulate is updated to the new CHILL color (old tween killed)
func test_apply_status_visual_replaces_previous_status_tween() -> void:
	var enemy := _make_enemy()
	enemy.apply_status_visual(GameEnums.BaseStatus.FREEZE, 2.0)

	# Apply a different status — should kill the FREEZE tween and set CHILL color.
	enemy.apply_status_visual(GameEnums.BaseStatus.CHILL, 1.5)

	assert_float(enemy.modulate.r).is_equal_approx(0.8, 0.01)
	assert_float(enemy.modulate.g).is_equal_approx(0.9, 0.01)
	assert_float(enemy.modulate.b).is_equal_approx(1.2, 0.01)


# ── AC: clear_status_visual kills status_tween ───────────────────────────────

## GIVEN FREEZE visual is active (modulate = icy-blue, tween running)
## WHEN clear_status_visual(FREEZE) is called
## THEN a fade-to-white tween is queued (modulate will be WHITE after duration)
func test_clear_status_visual_freeze_queues_fade_to_white() -> void:
	var enemy := _make_enemy()
	enemy.apply_status_visual(GameEnums.BaseStatus.FREEZE, 2.0)
	# Confirm icy-blue is set.
	assert_float(enemy.modulate.b).is_greater(1.0)

	enemy.clear_status_visual(GameEnums.BaseStatus.FREEZE)

	# After enough frames the tween should restore WHITE (0.15s tween → many frames).
	await get_tree().create_timer(0.2).timeout
	assert_float(enemy.modulate.r).is_equal_approx(1.0, 0.05)
	assert_float(enemy.modulate.g).is_equal_approx(1.0, 0.05)
	assert_float(enemy.modulate.b).is_equal_approx(1.0, 0.05)
