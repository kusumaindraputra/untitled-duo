## wall_crossing_test.gd — Fayde never leaves the arena through an ArenaBounds segment.
##
## Coverage:
##   Enemies do not collide with Fayde (their mask has no player bit), so one can walk
##   onto her. Her own move_and_slide() then pushes her out of the enemy, and at the
##   bottom corner of the floor that push used to carry her over the wall segment, after
##   which she was outside the room for good (balance bot, PR #103). The test drives an
##   enemy body into her at that corner and checks she stays on the inside.
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite)
extends GdUnitTestSuite

const PlayerScene: PackedScene = preload("res://src/scenes/PlayerController.tscn")

const _ACTIONS: Array[StringName] = [
	&"move_right", &"move_left", &"move_up", &"move_down", &"dash"
]
## Two floor-rim segments meeting in a V at the origin, like the bottom corner of an
## isometric floor. The room is above the V (y < -|x| / 2).
const _RIM: PackedVector2Array = [
	Vector2(-320, -160), Vector2(0, 0), Vector2(0, 0), Vector2(320, -160),
]
## Fayde wedged in the corner (touching both segments), and where the enemies walk in from (straight
## above her and a little to either side, since the push depends on the exact overlap).
const _FAYDE_START := Vector2(0, -9)
const _ENEMY_STARTS: Array[Vector2] = [
	Vector2(-6, -42), Vector2(-3, -42), Vector2(-1, -42), Vector2(0.001, -42),
	Vector2(1, -42), Vector2(3, -42), Vector2(6, -42),
]
## Where the enemy waits, well away from Fayde, until the physics bodies have settled.
const _ENEMY_PARKED := Vector2(0, -300)
const _ENEMY_SPEED: float = 120.0
const _FRAMES: int = 120

var _root: Node2D = null
var _temp_actions: Array[StringName] = []


func before_test() -> void:
	_temp_actions.clear()
	for action: StringName in _ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			_temp_actions.append(action)
	_root = Node2D.new()
	add_child(_root)


func after_test() -> void:
	for action: StringName in _temp_actions:
		InputMap.erase_action(action)
	_temp_actions.clear()
	if is_instance_valid(_root):
		remove_child(_root)
		_root.free()
	_root = null


func _make_rim() -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var cs := CollisionShape2D.new()
	var shape := ConcavePolygonShape2D.new()
	shape.segments = _RIM
	cs.shape = shape
	wall.add_child(cs)
	_root.add_child(wall)


func _make_fayde() -> PlayerController:
	var pc := PlayerScene.instantiate() as PlayerController
	_root.add_child(pc)
	pc._on_combat_started()
	pc.global_position = _FAYDE_START
	return pc


## Same body setup as EnemyInstance: layer 4, mask 49 (no player bit), radius 8.
func _make_enemy(at: Vector2) -> CharacterBody2D:
	var enemy := CharacterBody2D.new()
	enemy.collision_layer = 4
	enemy.collision_mask = 49
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	cs.shape = circle
	enemy.add_child(cs)
	_root.add_child(enemy)
	enemy.global_position = at
	return enemy


func _inside_room(p: Vector2) -> bool:
	return p.y < -absf(p.x) * 0.5


## GIVEN Fayde standing in the floor's bottom corner
## WHEN an enemy walks onto her from inside the room for 2 s
## THEN she is still inside the room (checked for several approach offsets)
func test_enemy_walking_onto_fayde_in_corner_keeps_her_inside() -> void:
	_make_rim()
	for start: Vector2 in _ENEMY_STARTS:
		var pc := _make_fayde()
		var enemy := _make_enemy(_ENEMY_PARKED)
		# Let both bodies settle in the physics server before the enemy walks in.
		for i: int in 3:
			await get_tree().physics_frame
		pc.global_position = _FAYDE_START
		enemy.global_position = start
		await get_tree().physics_frame
		var left_at: Vector2 = Vector2.INF
		for i: int in _FRAMES:
			var to_fayde: Vector2 = pc.global_position - enemy.global_position
			enemy.velocity = to_fayde.normalized() * _ENEMY_SPEED if to_fayde.length() > 0.5 else Vector2.ZERO
			enemy.move_and_slide()
			await get_tree().physics_frame
			if left_at == Vector2.INF and not _inside_room(pc.global_position):
				left_at = pc.global_position
		assert_vector(left_at).override_failure_message(
			"Enemy from %s pushed Fayde out of the room at %s" % [start, left_at]).is_equal(Vector2.INF)
		_root.remove_child(pc)
		pc.free()
		_root.remove_child(enemy)
		enemy.free()


## GIVEN Fayde next to the rim with nothing else around
## WHEN she walks along the rim
## THEN the guard does not stop legal movement
func test_walking_along_rim_still_moves() -> void:
	_make_rim()
	var pc := _make_fayde()
	pc.global_position = Vector2(-100, -62)
	await get_tree().physics_frame

	Input.action_press(&"move_left")
	for i: int in 30:
		await get_tree().physics_frame
	Input.action_release(&"move_left")

	assert_float(pc.global_position.x).is_less(-120.0)
	assert_bool(_inside_room(pc.global_position)).is_true()


## GIVEN a step that would move Fayde's centre across the rim
## WHEN _undo_wall_crossing runs
## THEN she is put back where the step started
func test_undo_wall_crossing_restores_start_position() -> void:
	_make_rim()
	var pc := _make_fayde()
	await get_tree().physics_frame
	var before := Vector2(0, -12)
	pc.global_position = Vector2(0, 10)
	pc.velocity = Vector2(0, 50)

	pc._undo_wall_crossing(before)

	assert_vector(pc.global_position).is_equal(before)
	assert_vector(pc.velocity).is_equal(Vector2.ZERO)


## GIVEN a step that stays inside the room
## WHEN _undo_wall_crossing runs
## THEN the position is left alone
func test_undo_wall_crossing_keeps_legal_step() -> void:
	_make_rim()
	var pc := _make_fayde()
	await get_tree().physics_frame
	pc.global_position = Vector2(20, -40)

	pc._undo_wall_crossing(Vector2(0, -40))

	assert_vector(pc.global_position).is_equal(Vector2(20, -40))
