## bullet_budget_test.gd — Live bullet cap and redraw gating for the web build (ADR-0050).
##
## Coverage:
##   at_cap counts live bullets in the enemy_bullet group; cap 0 never blocks
##   BulletPool.acquire returns null at the cap and a bullet again once one is spent
##   needs_redraw: trail growth, homing turn and end fade redraw; steady flight does not
##   the shipped tuning keeps a cap inside its documented safe range
extends GdUnitTestSuite

var _parent: Node2D = null


func before_test() -> void:
	_parent = Node2D.new()
	add_child(_parent)


func after_test() -> void:
	if is_instance_valid(_parent):
		remove_child(_parent)
		_parent.free()
	_parent = null


func _launch(pool: BulletPool) -> Projectile:
	var b: Projectile = pool.acquire()
	if b != null:
		b.launch(Vector2.RIGHT, 1.0)
	return b


func test_at_cap_false_below_cap() -> void:
	var pool: BulletPool = BulletPool.for_parent(_parent)
	_launch(pool)
	_launch(pool)
	assert_bool(Projectile.at_cap(get_tree(), 3)).is_false()


func test_at_cap_true_at_cap() -> void:
	var pool: BulletPool = BulletPool.for_parent(_parent)
	for i: int in 3:
		_launch(pool)
	assert_bool(Projectile.at_cap(get_tree(), 3)).is_true()


func test_at_cap_zero_never_blocks() -> void:
	var pool: BulletPool = BulletPool.for_parent(_parent)
	_launch(pool)
	assert_bool(Projectile.at_cap(get_tree(), 0)).is_false()


func test_at_cap_null_tree_false() -> void:
	assert_bool(Projectile.at_cap(null, 1)).is_false()


func test_acquire_returns_null_at_tuning_cap() -> void:
	var pool: BulletPool = BulletPool.for_parent(_parent)
	var cap: int = Projectile.TUNING.max_live_bullets
	for i: int in cap:
		assert_object(_launch(pool)).is_not_null()
	assert_object(pool.acquire()).is_null()


func test_acquire_works_again_after_a_bullet_is_spent() -> void:
	var pool: BulletPool = BulletPool.for_parent(_parent)
	var first: Projectile = null
	for i: int in Projectile.TUNING.max_live_bullets:
		var b: Projectile = _launch(pool)
		if first == null:
			first = b
	first.cancel()  # leaves the group at once; pool release is deferred
	assert_object(pool.acquire()).is_not_null()


func test_needs_redraw_while_trail_grows() -> void:
	assert_bool(Projectile.needs_redraw(0.05, 10.0, 400.0,
		BulletPattern.Motion.STRAIGHT, 0.0)).is_true()


func test_needs_redraw_false_in_steady_flight() -> void:
	assert_bool(Projectile.needs_redraw(0.5, 100.0, 400.0,
		BulletPattern.Motion.STRAIGHT, 0.0)).is_false()


func test_needs_redraw_false_for_sine_in_steady_flight() -> void:
	assert_bool(Projectile.needs_redraw(0.5, 100.0, 400.0,
		BulletPattern.Motion.SINE, 0.0)).is_false()


func test_needs_redraw_while_homing_turns() -> void:
	assert_bool(Projectile.needs_redraw(0.5, 100.0, 400.0,
		BulletPattern.Motion.HOMING, 0.8)).is_true()


func test_needs_redraw_false_after_homing_window() -> void:
	assert_bool(Projectile.needs_redraw(1.2, 100.0, 400.0,
		BulletPattern.Motion.HOMING, 0.8)).is_false()


func test_needs_redraw_in_end_fade() -> void:
	var traveled: float = 400.0 - Projectile.DESPAWN_FADE_DIST + 1.0
	assert_bool(Projectile.needs_redraw(1.0, traveled, 400.0,
		BulletPattern.Motion.STRAIGHT, 0.0)).is_true()


func test_shipped_cap_in_safe_range() -> void:
	assert_int(Projectile.TUNING.max_live_bullets).is_between(160, 320)
