## enemy_hazards_test.gd — EnemyLaser and MortarShell (ADR-0018).
##
## Coverage:
##   Laser: distance_to_beam geometry; TELEGRAPH → ACTIVE after telegraph_sec
##   Mortar: explodes after telegraph_sec; splash ring spawns pooled bullets
extends GdUnitTestSuite

const DT: float = 1.0 / 60.0

var _parent: Node2D = null


func before_test() -> void:
	_parent = Node2D.new()
	add_child(_parent)


func after_test() -> void:
	if is_instance_valid(_parent):
		remove_child(_parent)
		_parent.free()
	_parent = null


func _laser_pattern() -> BulletPattern:
	var p := BulletPattern.new()
	p.kind = BulletPattern.Kind.LASER
	p.telegraph_sec = 0.5
	p.active_sec = 0.3
	p.length = 200.0
	p.width = 5.0
	return p


func test_laser_distance_to_beam() -> void:
	var laser := EnemyLaser.new()
	laser.pattern = _laser_pattern()
	laser.angle = 0.0
	_parent.add_child(laser)
	assert_float(laser.distance_to_beam(Vector2(100.0, 30.0))).is_equal_approx(30.0, 0.01)
	# Past the beam's end: distance to the end point.
	assert_float(laser.distance_to_beam(Vector2(240.0, 0.0))).is_equal_approx(40.0, 0.01)


func test_laser_goes_active_after_telegraph() -> void:
	var laser := EnemyLaser.new()
	laser.pattern = _laser_pattern()
	_parent.add_child(laser)
	assert_int(laser.get_phase()).is_equal(EnemyLaser.Phase.TELEGRAPH)
	for _i: int in 32:
		laser._physics_process(DT)
	assert_int(laser.get_phase()).is_equal(EnemyLaser.Phase.ACTIVE)


func test_mortar_explodes_after_telegraph_and_splashes() -> void:
	var p := BulletPattern.new()
	p.kind = BulletPattern.Kind.MORTAR
	p.telegraph_sec = 0.3
	p.splash_count = 6
	var shell := MortarShell.new()
	shell.pattern = p
	_parent.add_child(shell)
	for _i: int in 10:
		shell._physics_process(DT)
	assert_bool(shell.has_exploded()).is_false()
	for _i: int in 10:
		shell._physics_process(DT)
	assert_bool(shell.has_exploded()).is_true()
	var pool: BulletPool = BulletPool.for_parent(_parent)
	var live: int = 0
	for child: Node in pool.get_children():
		if child is Projectile and (child as Projectile).is_live():
			live += 1
	assert_int(live).is_equal(6)
