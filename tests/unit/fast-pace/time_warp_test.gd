## time_warp_test.gd — TimeWarp guard for shared Engine.time_scale effects (ADR-0019).
extends GdUnitTestSuite


func after_test() -> void:
	Engine.time_scale = 1.0


func test_time_warp_applies_when_free() -> void:
	assert_bool(TimeWarp.try_apply(get_tree(), 0.3, 0.2)).is_true()
	assert_float(Engine.time_scale).is_equal_approx(0.3, 0.0001)


func test_time_warp_refuses_while_another_warp_is_active() -> void:
	Engine.time_scale = 0.05  # e.g. a hitstop
	assert_bool(TimeWarp.try_apply(get_tree(), 0.3, 0.2)).is_false()
	assert_float(Engine.time_scale).is_equal_approx(0.05, 0.0001)


func test_time_warp_refuses_without_tree_or_duration() -> void:
	assert_bool(TimeWarp.try_apply(null, 0.3, 0.2)).is_false()
	assert_bool(TimeWarp.try_apply(get_tree(), 0.3, 0.0)).is_false()
	assert_float(Engine.time_scale).is_equal(1.0)


func test_time_warp_release_restores_only_its_own_scale() -> void:
	Engine.time_scale = 0.15  # death slow-mo took over
	TimeWarp.release(0.3)
	assert_float(Engine.time_scale).is_equal_approx(0.15, 0.0001)
	Engine.time_scale = 0.3
	TimeWarp.release(0.3)
	assert_float(Engine.time_scale).is_equal(1.0)


func test_time_warp_restores_after_real_duration() -> void:
	assert_bool(TimeWarp.try_apply(get_tree(), 0.3, 0.05)).is_true()
	await await_millis(150)
	assert_float(Engine.time_scale).is_equal(1.0)
