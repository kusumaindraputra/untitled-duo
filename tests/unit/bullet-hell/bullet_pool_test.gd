## bullet_pool_test.gd — BulletPool reuse (ADR-0018).
##
## Coverage:
##   for_parent creates one pool per parent and reuses it
##   acquire → despawn → release returns the bullet to the idle list
##   a reused bullet comes back live with launch defaults restored
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


func test_for_parent_returns_same_pool() -> void:
	var a: BulletPool = BulletPool.for_parent(_parent)
	var b: BulletPool = BulletPool.for_parent(_parent)
	assert_object(a).is_same(b)


func test_for_parent_null_returns_null() -> void:
	assert_object(BulletPool.for_parent(null)).is_null()


func test_released_bullet_is_reused() -> void:
	var pool: BulletPool = BulletPool.for_parent(_parent)
	var b: Projectile = pool.acquire()
	b.launch(Vector2.RIGHT, 1.0)
	b.cancel()
	pool.release(b)  # what the deferred call does at end of frame
	assert_int(pool.idle_count()).is_equal(1)
	var again: Projectile = pool.acquire()
	assert_object(again).is_same(b)
	assert_bool(again.is_live()).is_true()
	assert_float(again._distance_traveled).is_equal(0.0)
	assert_int(pool.idle_count()).is_equal(0)


func test_release_ignores_live_bullet() -> void:
	var pool: BulletPool = BulletPool.for_parent(_parent)
	var b: Projectile = pool.acquire()
	b.launch(Vector2.RIGHT, 1.0)
	pool.release(b)
	assert_int(pool.idle_count()).is_equal(0)
