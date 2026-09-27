## offscreen_indicators_test.gd — edge-arrow placement maths and the player-hit kick.
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const SCREEN := Rect2(Vector2.ZERO, Vector2(1152, 648))


func test_offscreen_indicators_point_inside_rect_is_onscreen() -> void:
	assert_bool(OffscreenIndicators.is_offscreen(Vector2(576, 324), SCREEN, 12.0)).is_false()


func test_offscreen_indicators_point_past_edge_is_offscreen() -> void:
	assert_bool(OffscreenIndicators.is_offscreen(Vector2(1300, 324), SCREEN, 12.0)).is_true()
	assert_bool(OffscreenIndicators.is_offscreen(Vector2(576, -40), SCREEN, 12.0)).is_true()


func test_offscreen_indicators_point_inside_pad_counts_as_offscreen() -> void:
	# 5 px from the right edge: the sprite is mostly cut off, so it gets an arrow.
	assert_bool(OffscreenIndicators.is_offscreen(Vector2(1147, 324), SCREEN, 12.0)).is_true()


func test_offscreen_indicators_edge_point_right_side_hits_right_margin() -> void:
	var p: Vector2 = OffscreenIndicators.edge_point(Vector2(3000, 324), SCREEN, 26.0)
	assert_float(p.x).is_equal_approx(1152.0 - 26.0, 0.01)
	assert_float(p.y).is_equal_approx(324.0, 0.01)


func test_offscreen_indicators_edge_point_top_side_hits_top_margin() -> void:
	var p: Vector2 = OffscreenIndicators.edge_point(Vector2(576, -2000), SCREEN, 26.0)
	assert_float(p.y).is_equal_approx(26.0, 0.01)
	assert_float(p.x).is_equal_approx(576.0, 0.01)


func test_offscreen_indicators_edge_point_diagonal_stays_inside_rect() -> void:
	var inner: Rect2 = SCREEN.grow(-26.0).grow(0.01)
	for target: Vector2 in [Vector2(-900, -900), Vector2(2500, 1400), Vector2(-50, 2000)]:
		var p: Vector2 = OffscreenIndicators.edge_point(target, SCREEN, 26.0)
		assert_bool(inner.has_point(p)).override_failure_message("%s -> %s" % [target, p]).is_true()


func test_offscreen_indicators_edge_point_keeps_direction() -> void:
	var c: Vector2 = SCREEN.get_center()
	var target := Vector2(-600, 900)
	var p: Vector2 = OffscreenIndicators.edge_point(target, SCREEN, 26.0)
	assert_float((p - c).normalized().dot((target - c).normalized())).is_equal_approx(1.0, 0.0001)


func test_offscreen_indicators_alpha_full_near_and_min_far() -> void:
	assert_float(OffscreenIndicators.alpha_for_distance(0.0)).is_equal(1.0)
	assert_float(OffscreenIndicators.alpha_for_distance(OffscreenIndicators.NEAR_DIST)).is_equal(1.0)
	assert_float(OffscreenIndicators.alpha_for_distance(99999.0)).is_equal_approx(
		OffscreenIndicators.MIN_ALPHA, 0.0001)


func test_player_hit_adds_camera_trauma() -> void:
	var prev: GameSettings = GameSettings.current
	GameSettings.current = null
	ScreenShake.reset()
	var player := PlayerController.new()
	player.add_to_group(&"player")
	player._on_player_damage_taken(player, 5, 90)
	assert_float(ScreenShake.get_trauma()).is_equal_approx(PlayerController.CAMERA_TUNING.player_hit_trauma, 0.001)
	player.free()
	ScreenShake.reset()
	GameSettings.current = prev


func test_player_hit_zero_damage_adds_no_trauma() -> void:
	ScreenShake.reset()
	var player := PlayerController.new()
	player.add_to_group(&"player")
	player._on_player_damage_taken(player, 0, 90)
	assert_float(ScreenShake.get_trauma()).is_equal(0.0)
	player.free()


func test_enemy_is_winding_up_false_when_idle() -> void:
	var enemy := EnemyInstance.new()
	assert_bool(enemy.is_winding_up()).is_false()
	enemy.free()
