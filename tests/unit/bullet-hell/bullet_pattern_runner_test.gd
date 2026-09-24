## bullet_pattern_runner_test.gd — BulletPatternRunner geometry + timing (ADR-0018).
##
## Coverage:
##   compute_angles: AIMED single, FAN spread edges, RING spacing, SPIRAL spin, fixed aim
##   tick: initial delay, windup before fire, burst count + spacing, interval, speed_step
##   is_active: hp_threshold gate
##   reset: restarts the cycle
##
## Pure RefCounted logic — no nodes, no scene tree.
extends GdUnitTestSuite

const DT: float = 1.0 / 60.0


func _pattern() -> BulletPattern:
	var p := BulletPattern.new()
	p.initial_delay = 0.5
	p.interval = 1.0
	p.windup_sec = 0.0
	p.count = 1
	p.bursts = 1
	return p


## Ticks [param runner] for [param seconds] and returns every event produced.
func _run(runner: BulletPatternRunner, seconds: float, aim: float = 0.0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var steps: int = roundi(seconds / DT)
	for _i: int in steps:
		out.append_array(runner.tick(DT, aim))
	return out


func _fires(events: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ev: Dictionary in events:
		if ev["type"] == BulletPatternRunner.EVENT_FIRE:
			out.append(ev)
	return out


# ── Geometry ──────────────────────────────────────────────────────────────────

func test_compute_angles_aimed_single_points_at_aim() -> void:
	var p := _pattern()
	var angles: PackedFloat32Array = BulletPatternRunner.compute_angles(p, 1.0, 0)
	assert_int(angles.size()).is_equal(1)
	assert_float(angles[0]).is_equal_approx(1.0, 0.0001)


func test_compute_angles_fan_spans_spread_centred_on_aim() -> void:
	var p := _pattern()
	p.shape = BulletPattern.Shape.FAN
	p.count = 3
	p.spread_deg = 60.0
	var angles: PackedFloat32Array = BulletPatternRunner.compute_angles(p, 0.0, 0)
	assert_int(angles.size()).is_equal(3)
	assert_float(angles[0]).is_equal_approx(deg_to_rad(-30.0), 0.0001)
	assert_float(angles[1]).is_equal_approx(0.0, 0.0001)
	assert_float(angles[2]).is_equal_approx(deg_to_rad(30.0), 0.0001)


func test_compute_angles_ring_is_evenly_spaced_full_circle() -> void:
	var p := _pattern()
	p.shape = BulletPattern.Shape.RING
	p.count = 8
	var angles: PackedFloat32Array = BulletPatternRunner.compute_angles(p, 0.0, 0)
	assert_int(angles.size()).is_equal(8)
	for i: int in range(1, 8):
		var gap: float = wrapf(angles[i] - angles[i - 1], 0.0, TAU)
		assert_float(gap).is_equal_approx(TAU / 8.0, 0.0001)


func test_compute_angles_spiral_rotates_by_spin_per_volley() -> void:
	var p := _pattern()
	p.shape = BulletPattern.Shape.SPIRAL
	p.count = 2
	p.spin_deg = 10.0
	p.aim_at_player = false
	var first: PackedFloat32Array = BulletPatternRunner.compute_angles(p, 2.0, 0)
	var third: PackedFloat32Array = BulletPatternRunner.compute_angles(p, 2.0, 2)
	# aim_at_player = false → aim ignored; volley 2 is rotated by 20°.
	assert_float(first[0]).is_equal_approx(0.0, 0.0001)
	assert_float(third[0]).is_equal_approx(deg_to_rad(20.0), 0.0001)


# ── Timing ────────────────────────────────────────────────────────────────────

func test_tick_no_fire_before_initial_delay() -> void:
	var runner := BulletPatternRunner.new(_pattern())
	var events: Array[Dictionary] = _run(runner, 0.4)
	assert_int(_fires(events).size()).is_equal(0)


func test_tick_fires_once_after_initial_delay() -> void:
	var runner := BulletPatternRunner.new(_pattern())
	var events: Array[Dictionary] = _run(runner, 0.6)
	assert_int(_fires(events).size()).is_equal(1)


func test_tick_fires_every_interval() -> void:
	# delay 0.5 + interval 1.0 → fires at ~0.5, ~1.5, ~2.5
	var runner := BulletPatternRunner.new(_pattern())
	var events: Array[Dictionary] = _run(runner, 2.6)
	assert_int(_fires(events).size()).is_equal(3)


func test_tick_windup_event_precedes_fire() -> void:
	var p := _pattern()
	p.windup_sec = 0.2
	var runner := BulletPatternRunner.new(p)
	var events: Array[Dictionary] = _run(runner, 0.6)
	assert_int(events.size()).is_equal(2)
	assert_str(String(events[0]["type"])).is_equal(String(BulletPatternRunner.EVENT_WINDUP))
	assert_str(String(events[1]["type"])).is_equal(String(BulletPatternRunner.EVENT_FIRE))


func test_tick_bursts_emit_one_volley_each() -> void:
	var p := _pattern()
	p.bursts = 3
	p.burst_interval = 0.1
	var runner := BulletPatternRunner.new(p)
	var events: Array[Dictionary] = _run(runner, 0.9)
	assert_int(_fires(events).size()).is_equal(3)


func test_tick_speed_step_adds_per_volley() -> void:
	var p := _pattern()
	p.bursts = 2
	p.burst_interval = 0.1
	p.speed = 100.0
	p.speed_step = 25.0
	var runner := BulletPatternRunner.new(p)
	var fires: Array[Dictionary] = _fires(_run(runner, 0.8))
	assert_float(float(fires[0]["speed"])).is_equal_approx(100.0, 0.001)
	assert_float(float(fires[1]["speed"])).is_equal_approx(125.0, 0.001)


func test_tick_fan_locks_aim_for_whole_firing() -> void:
	var p := _pattern()
	p.shape = BulletPattern.Shape.FAN
	p.bursts = 2
	p.burst_interval = 0.1
	var runner := BulletPatternRunner.new(p)
	var fires: Array[Dictionary] = []
	fires.append_array(_fires(_run(runner, 0.55, 0.0)))  # first volley at aim 0
	fires.append_array(_fires(_run(runner, 0.2, 1.5)))   # aim moved; FAN keeps 0
	assert_int(fires.size()).is_equal(2)
	var second: PackedFloat32Array = fires[1]["angles"]
	assert_float(second[0]).is_equal_approx(0.0, 0.0001)


func test_tick_aimed_reaims_every_volley() -> void:
	var p := _pattern()
	p.shape = BulletPattern.Shape.AIMED
	p.bursts = 2
	p.burst_interval = 0.1
	var runner := BulletPatternRunner.new(p)
	var fires: Array[Dictionary] = []
	fires.append_array(_fires(_run(runner, 0.55, 0.0)))
	fires.append_array(_fires(_run(runner, 0.2, 1.5)))
	var second: PackedFloat32Array = fires[1]["angles"]
	assert_float(second[0]).is_equal_approx(1.5, 0.0001)


# ── HP gate / reset ───────────────────────────────────────────────────────────

func test_is_active_respects_hp_threshold() -> void:
	var p := _pattern()
	p.hp_threshold = 0.5
	var runner := BulletPatternRunner.new(p)
	assert_bool(runner.is_active(0.8)).is_false()
	assert_bool(runner.is_active(0.5)).is_true()
	assert_bool(runner.is_active(0.2)).is_true()


func test_reset_restarts_initial_delay() -> void:
	var runner := BulletPatternRunner.new(_pattern())
	_run(runner, 0.4)
	runner.reset()
	var events: Array[Dictionary] = _run(runner, 0.4)
	assert_int(_fires(events).size()).is_equal(0)
