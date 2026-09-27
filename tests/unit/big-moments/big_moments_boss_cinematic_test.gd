## big_moments_boss_cinematic_test.gd — BossDeathCinematic timing, flash and camera (ADR-0041).
extends GdUnitTestSuite

const T: BigMomentTuning = preload("res://assets/data/big_moment_tuning.tres")


func after_test() -> void:
	Engine.time_scale = 1.0


func test_plan_full_motion_glides_in_holds_and_glides_out() -> void:
	var p: Dictionary = BossDeathCinematic.plan(T, false)
	assert_bool(bool(p["camera"])).is_true()
	assert_float(float(p["total"])).is_equal_approx(
		T.boss_zoom_in_sec + T.boss_hold_sec + T.boss_zoom_out_sec, 0.0001)


func test_plan_reduce_motion_drops_camera_but_keeps_the_beat() -> void:
	var p: Dictionary = BossDeathCinematic.plan(T, true)
	assert_bool(bool(p["camera"])).is_false()
	assert_float(float(p["zoom_out"])).is_equal(0.0)
	assert_float(float(p["total"])).is_greater_equal(T.boss_hold_sec)


func test_flash_starts_at_peak_and_is_gone_after_flash_sec() -> void:
	assert_float(BossDeathCinematic.flash_alpha(T, 0.0, 1.0)).is_equal_approx(T.boss_flash_alpha, 0.0001)
	assert_float(BossDeathCinematic.flash_alpha(T, T.boss_flash_sec, 1.0)).is_equal(0.0)
	var mid: float = BossDeathCinematic.flash_alpha(T, T.boss_flash_sec * 0.5, 1.0)
	assert_float(mid).is_greater(0.0)
	assert_float(mid).is_less(T.boss_flash_alpha)


func test_flash_follows_reduce_flashes_scale() -> void:
	var half: float = BossDeathCinematic.flash_alpha(T, 0.0, 0.5)
	assert_float(half).is_equal_approx(T.boss_flash_alpha * 0.5, 0.0001)
	assert_float(BossDeathCinematic.flash_alpha(T, 0.0, 0.0)).is_equal(0.0)


func test_ease_glide_is_clamped_smoothstep() -> void:
	assert_float(BossDeathCinematic.ease_glide(-1.0)).is_equal(0.0)
	assert_float(BossDeathCinematic.ease_glide(0.5)).is_equal_approx(0.5, 0.0001)
	assert_float(BossDeathCinematic.ease_glide(2.0)).is_equal(1.0)


func test_boss_dissolve_ends_inside_the_beat() -> void:
	var total: float = float(BossDeathCinematic.plan(T, false)["total"])
	var fx: CharacterFxTuning = load("res://assets/data/character_fx_tuning.tres")
	assert_float(T.boss_dissolve_sec).is_greater(fx.dissolve_sec)
	assert_float(BossDeathCinematic.dissolve_real_sec(T)).is_less_equal(total)


func test_dissolve_real_sec_stretches_through_slowmo() -> void:
	var t := BigMomentTuning.new()
	t.boss_slowmo_scale = 0.5
	t.boss_slowmo_sec = 2.0
	t.boss_dissolve_sec = 0.5  # all inside the slow-mo: 0.5 / 0.5
	assert_float(BossDeathCinematic.dissolve_real_sec(t)).is_equal_approx(1.0, 0.0001)
	t.boss_dissolve_sec = 1.5  # 1.0 game s in 2 real s, then 0.5 at full speed
	assert_float(BossDeathCinematic.dissolve_real_sec(t)).is_equal_approx(2.5, 0.0001)


func test_play_runs_every_phase_then_finishes_once() -> void:
	var c := BossDeathCinematic.new()
	var done: Array[int] = [0]
	c.finished.connect(func() -> void: done[0] += 1)
	assert_bool(c.play(Vector2(100.0, 50.0))).is_true()
	assert_int(c.get_phase()).is_equal(BossDeathCinematic.Phase.ZOOM_IN)
	c.advance(T.boss_zoom_in_sec + 0.001)
	assert_int(c.get_phase()).is_equal(BossDeathCinematic.Phase.HOLD)
	c.advance(T.boss_hold_sec + 0.001)
	assert_int(c.get_phase()).is_equal(BossDeathCinematic.Phase.ZOOM_OUT)
	assert_bool(c.is_playing()).is_true()
	c.advance(T.boss_zoom_out_sec + 0.001)
	assert_bool(c.is_playing()).is_false()
	assert_int(done[0]).is_equal(1)
	c.advance(1.0)
	assert_int(done[0]).is_equal(1)
	c.free()


func test_second_play_is_refused_while_running() -> void:
	var c := BossDeathCinematic.new()
	assert_bool(c.play(Vector2.ZERO)).is_true()
	assert_bool(c.play(Vector2.ONE)).is_false()
	c.free()


func test_play_in_tree_starts_boss_slowmo() -> void:
	var c := BossDeathCinematic.new()
	add_child(c)
	c.play(Vector2.ZERO)
	c.advance(0.0)
	assert_float(Engine.time_scale).is_equal_approx(T.boss_slowmo_scale, 0.0001)
	c.free()


func test_camera_glides_to_boss_and_hands_back_to_fayde() -> void:
	var world := Node2D.new()
	add_child(world)
	var fayde_cam := Camera2D.new()
	world.add_child(fayde_cam)
	fayde_cam.make_current()
	var c := BossDeathCinematic.new()
	world.add_child(c)
	var boss_pos := Vector2(300.0, 120.0)
	c.play(boss_pos)
	var cine: Camera2D = world.get_viewport().get_camera_2d()
	assert_str(cine.name).is_equal("BossDeathCamera")
	c.advance(T.boss_zoom_in_sec + 0.001)
	assert_vector(cine.global_position).is_equal_approx(boss_pos, Vector2.ONE * 0.01)
	assert_vector(cine.zoom).is_equal_approx(fayde_cam.zoom * T.boss_zoom_mult, Vector2.ONE * 0.001)
	c.advance(T.boss_hold_sec + 0.001)
	c.advance(T.boss_zoom_out_sec + 0.001)
	assert_object(world.get_viewport().get_camera_2d()).is_same(fayde_cam)
	world.free()


func test_white_flash_is_drawn_and_cleared() -> void:
	var c := BossDeathCinematic.new()
	add_child(c)
	c.play(Vector2.ZERO)
	var flash: ColorRect = c.find_child("BossDeathFlash", true, false) as ColorRect
	assert_object(flash).is_not_null()
	assert_float(flash.color.a).is_equal_approx(T.boss_flash_alpha * GameSettings.flash_multiplier(), 0.0001)
	c.advance(10.0)
	c.advance(10.0)
	c.advance(10.0)
	assert_float(flash.color.a).is_equal(0.0)
	c.free()
