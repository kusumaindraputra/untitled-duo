## hazard_logic_test.gd — timing and geometry of room hazards (ADR-0020).
extends GdUnitTestSuite


func _spec(kind: HazardSpec.Kind) -> HazardSpec:
	var s := HazardSpec.new()
	s.kind = kind
	return s


func test_create_builds_the_right_node_for_each_kind() -> void:
	var expect: Dictionary = {
		HazardSpec.Kind.TURRET: "HazardTurret",
		HazardSpec.Kind.SWEEP_LASER: "HazardSweepLaser",
		HazardSpec.Kind.FLOOR_ZONE: "HazardFloorZone",
		HazardSpec.Kind.CLOSING_RING: "HazardClosingRing",
	}
	for k: int in expect:
		var h: StageHazard = StageHazard.create(_spec(k))
		assert_object(h).is_not_null()
		assert_str(h.get_script().get_global_name()).is_equal(expect[k])
		assert_object(h.spec).is_not_null()
		h.free()
	assert_object(StageHazard.create(null)).is_null()


func test_hazard_starts_inactive_and_toggles() -> void:
	var h: StageHazard = StageHazard.create(_spec(HazardSpec.Kind.FLOOR_ZONE))
	assert_bool(h.is_active()).is_false()
	h.set_active(true)
	assert_bool(h.is_active()).is_true()
	h.set_active(false)
	assert_bool(h.is_active()).is_false()
	h.free()


func test_floor_zone_cycles_dormant_telegraph_burning() -> void:
	var s := _spec(HazardSpec.Kind.FLOOR_ZONE)
	s.off_sec = 2.0
	s.telegraph_sec = 1.0
	s.on_sec = 1.0
	assert_int(HazardFloorZone.phase_at(0.5, s)).is_equal(HazardFloorZone.Phase.DORMANT)
	assert_int(HazardFloorZone.phase_at(2.5, s)).is_equal(HazardFloorZone.Phase.TELEGRAPH)
	assert_int(HazardFloorZone.phase_at(3.5, s)).is_equal(HazardFloorZone.Phase.BURNING)
	# Next cycle.
	assert_int(HazardFloorZone.phase_at(4.5, s)).is_equal(HazardFloorZone.Phase.DORMANT)


func test_floor_zone_phase_offset_shifts_the_cycle() -> void:
	var s := _spec(HazardSpec.Kind.FLOOR_ZONE)
	s.off_sec = 2.0
	s.telegraph_sec = 1.0
	s.on_sec = 1.0
	s.phase_offset = 3.0
	assert_int(HazardFloorZone.phase_at(0.5, s)).is_equal(HazardFloorZone.Phase.BURNING)


func test_floor_zone_is_dormant_while_inactive() -> void:
	var z: HazardFloorZone = StageHazard.create(_spec(HazardSpec.Kind.FLOOR_ZONE)) as HazardFloorZone
	z.spec.phase_offset = z.spec.off_sec + z.spec.telegraph_sec  # would burn at t=0
	assert_int(z.get_phase()).is_equal(HazardFloorZone.Phase.DORMANT)
	z.set_active(true)
	assert_int(z.get_phase()).is_equal(HazardFloorZone.Phase.BURNING)
	z.free()


func test_sweep_arms_spread_evenly_and_rotate() -> void:
	assert_float(HazardSweepLaser.arm_angle(0.0, 30.0, 0, 2)).is_equal_approx(0.0, 0.0001)
	assert_float(HazardSweepLaser.arm_angle(0.0, 30.0, 1, 2)).is_equal_approx(PI, 0.0001)
	assert_float(HazardSweepLaser.arm_angle(2.0, 45.0, 0, 3)).is_equal_approx(deg_to_rad(90.0), 0.0001)
	assert_float(HazardSweepLaser.arm_angle(1.0, -30.0, 0, 1)).is_equal_approx(deg_to_rad(-30.0), 0.0001)


func test_sweep_is_harmless_during_warmup() -> void:
	var s := _spec(HazardSpec.Kind.SWEEP_LASER)
	s.warmup_sec = 1.0
	var h: HazardSweepLaser = StageHazard.create(s) as HazardSweepLaser
	h.set_active(true)
	assert_bool(h.is_live()).is_false()
	h._active_time = 1.2
	assert_bool(h.is_live()).is_true()
	h.free()


func test_sweep_distance_to_arms() -> void:
	var s := _spec(HazardSpec.Kind.SWEEP_LASER)
	s.arm_count = 1
	s.arm_length = 100.0
	s.rotation_deg_per_sec = 0.0
	var h: HazardSweepLaser = StageHazard.create(s) as HazardSweepLaser
	h.set_active(true)
	assert_float(h.distance_to_arms(Vector2(50, 10))).is_equal_approx(10.0, 0.001)
	assert_float(h.distance_to_arms(Vector2(150, 0))).is_equal_approx(50.0, 0.001)
	h.free()


func test_closing_ring_holds_then_closes_to_minimum() -> void:
	var s := _spec(HazardSpec.Kind.CLOSING_RING)
	s.ring_delay_sec = 5.0
	s.ring_close_sec = 10.0
	s.ring_start_scale = 1.0
	s.ring_min_scale = 0.5
	assert_float(HazardClosingRing.scale_at(3.0, s)).is_equal(1.0)
	assert_float(HazardClosingRing.scale_at(10.0, s)).is_equal_approx(0.75, 0.0001)
	assert_float(HazardClosingRing.scale_at(15.0, s)).is_equal_approx(0.5, 0.0001)
	assert_float(HazardClosingRing.scale_at(99.0, s)).is_equal_approx(0.5, 0.0001)


func test_diamond_norm_matches_room_walls() -> void:
	var ex := Vector2(640, 384)
	assert_float(HazardClosingRing.diamond_norm(Vector2.ZERO, ex)).is_equal(0.0)
	assert_float(HazardClosingRing.diamond_norm(Vector2(640, 0), ex)).is_equal_approx(1.0, 0.0001)
	assert_float(HazardClosingRing.diamond_norm(Vector2(-320, 192), ex)).is_equal_approx(1.0, 0.0001)


func test_iso_radius_counts_vertical_offset_double() -> void:
	assert_bool(StageHazard.in_iso_radius(Vector2(50, 0), 56.0)).is_true()
	assert_bool(StageHazard.in_iso_radius(Vector2(0, 27), 56.0)).is_true()
	assert_bool(StageHazard.in_iso_radius(Vector2(0, 30), 56.0)).is_false()


func test_turret_runner_created_on_activation() -> void:
	var s := _spec(HazardSpec.Kind.TURRET)
	s.pattern = load("res://assets/data/bullet_patterns/turret_burst.tres")
	var t: HazardTurret = StageHazard.create(s) as HazardTurret
	assert_object(t.get_runner()).is_null()
	t.set_active(true)
	assert_object(t.get_runner()).is_not_null()
	t.free()


func test_turret_without_pattern_does_not_crash() -> void:
	var t: HazardTurret = StageHazard.create(_spec(HazardSpec.Kind.TURRET)) as HazardTurret
	t.set_active(true)
	t._hazard_tick(0.1)
	assert_object(t.get_runner()).is_null()
	t.free()
