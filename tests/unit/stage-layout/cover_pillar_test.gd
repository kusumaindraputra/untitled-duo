## cover_pillar_test.gd — full-cover pillars: durability, cracks, collision contract (ADR-0020).
extends GdUnitTestSuite

const HITS: int = 12


func _pillar(hits: int = HITS) -> CoverPillar:
	var p := CoverPillar.new()
	p.setup(hits, 20.0)
	return p


func test_pillar_is_on_full_cover_layer() -> void:
	var p := _pillar()
	assert_int(p.collision_layer).is_equal(CoverPillar.LAYER_FULL_COVER)
	assert_int(p.collision_mask).is_equal(0)
	p.free()


func test_take_hit_counts_down_and_breaks_on_last_hit() -> void:
	var p := _pillar()
	for i: int in HITS - 1:
		assert_bool(p.take_hit()).is_false()
	assert_int(p.get_hits_left()).is_equal(1)
	assert_bool(p.is_broken()).is_false()
	assert_bool(p.take_hit()).is_true()
	assert_bool(p.is_broken()).is_true()
	assert_int(p.get_hits_left()).is_equal(0)
	p.free()


func test_break_emits_destroyed_once() -> void:
	var p := _pillar(2)
	var count: Array[int] = [0]
	p.destroyed.connect(func(_pos: Vector2) -> void: count[0] += 1)
	p.take_hit(CoverPillar.LASER_HITS)
	p.take_hit()
	assert_int(count[0]).is_equal(1)
	p.free()


func test_hits_after_break_are_ignored() -> void:
	var p := _pillar(1)
	p.take_hit()
	assert_bool(p.take_hit()).is_false()
	assert_int(p.get_hits_left()).is_equal(0)
	p.free()


func test_zero_or_negative_hit_is_noop() -> void:
	var p := _pillar()
	assert_bool(p.take_hit(0)).is_false()
	assert_bool(p.take_hit(-3)).is_false()
	assert_int(p.get_hits_left()).is_equal(HITS)
	p.free()


func test_setup_clamps_hits_to_at_least_one() -> void:
	var p := _pillar(0)
	assert_int(p.max_hits).is_equal(1)
	assert_bool(p.take_hit()).is_true()
	p.free()


func test_crack_stage_rises_with_wear() -> void:
	assert_int(CoverPillar.crack_stage_for(HITS, HITS)).is_equal(0)
	assert_int(CoverPillar.crack_stage_for(1, HITS)).is_equal(CoverPillar.CRACK_STAGES)
	var last: int = 0
	for left: int in range(HITS, 0, -1):
		var st: int = CoverPillar.crack_stage_for(left, HITS)
		assert_int(st).is_greater_equal(last)
		last = st
	assert_int(CoverPillar.crack_stage_for(5, 0)).is_equal(0)


func test_cast_beam_without_world_returns_full_length() -> void:
	var hit: Dictionary = CoverPillar.cast_beam(null, Vector2.ZERO, 0.0, 300.0)
	assert_float(float(hit["length"])).is_equal(300.0)
	assert_object(hit["pillar"]).is_null()


func test_enemy_bullets_collide_with_pillars() -> void:
	assert_int(Projectile.COLLISION_MASK_FULL_COVER).is_equal(CoverPillar.LAYER_FULL_COVER)


func test_fayde_cannot_walk_or_dash_through_pillars() -> void:
	assert_int(PlayerController.COLLISION_MASK_NORMAL & CoverPillar.LAYER_FULL_COVER).is_not_equal(0)
	assert_int(PlayerController.COLLISION_MASK_DASHING & CoverPillar.LAYER_FULL_COVER).is_not_equal(0)
	# Dash still passes through enemies (4) and debris (16).
	assert_int(PlayerController.COLLISION_MASK_DASHING & 20).is_equal(0)


func test_bullet_hitting_pillar_wears_it_down() -> void:
	var p := _pillar(3)
	var b := Projectile.new()
	b._on_body_entered(p)
	assert_int(p.get_hits_left()).is_equal(2)
	assert_bool(b.is_live()).is_false()
	b.free()
	p.free()


func test_laser_beam_length_defaults_to_pattern_length() -> void:
	var laser := EnemyLaser.new()
	var pat := BulletPattern.new()
	pat.length = 400.0
	laser.pattern = pat
	assert_float(laser.beam_length()).is_equal(400.0)
	laser.free()


func test_laser_blocked_by_pillar_in_tree() -> void:
	var p := _pillar(10)
	add_child(p)
	p.global_position = Vector2(200, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var hit: Dictionary = CoverPillar.cast_beam(p.get_world_2d(), Vector2.ZERO, 0.0, 500.0)
	assert_float(float(hit["length"])).is_less(200.0)
	assert_object(hit["pillar"]).is_same(p)
	remove_child(p)
	p.free()


## Regression: with monitorable = false, Godot 4.6 never reported body_entered, so
## bullets flew through walls. A flying bullet must stop at a pillar and chip it.
func test_flying_bullet_is_stopped_by_pillar() -> void:
	# Isolation: an earlier suite's hitstop / slow-mo may leave time_scale low.
	Engine.time_scale = 1.0
	var p := _pillar(5)
	add_child(p)
	p.global_position = Vector2(100, 0)
	var b := Projectile.new()
	add_child(b)
	b.global_position = Vector2.ZERO
	b.launch_pattern(Vector2.RIGHT, 1.0, BulletPattern.new(), 200.0)
	for _i: int in 240:
		await get_tree().physics_frame
		if p.get_hits_left() < 5:
			break
	assert_int(p.get_hits_left()).is_equal(4)
	if is_instance_valid(b):
		assert_bool(b.is_live()).is_false()
		assert_float(b.global_position.x).is_less(100.0)
		remove_child(b)
		b.free()
	remove_child(p)
	p.free()
