## style_meter_test.gd — StyleMeter gain, decay, penalty and room rank (ADR-0019).
##
## Pure RefCounted logic. Tuning is a fresh PaceTuning so the tests pin their own
## thresholds instead of depending on the shipped .tres values.
extends GdUnitTestSuite


func _tuning() -> PaceTuning:
	var t := PaceTuning.new()
	t.style_max = 100.0
	t.style_hit_penalty = 30.0
	t.style_idle_grace_sec = 1.0
	t.style_decay_per_sec = 10.0
	t.rank_thresholds = PackedFloat32Array([60.0, 40.0, 20.0, 10.0])
	return t


func test_style_add_caps_at_max() -> void:
	var m := StyleMeter.new(_tuning())
	m.add(70.0)
	m.add(70.0)
	assert_float(m.get_value()).is_equal(100.0)
	assert_float(m.get_ratio()).is_equal(1.0)


func test_style_add_ignores_non_positive() -> void:
	var m := StyleMeter.new(_tuning())
	m.add(-5.0)
	m.add(0.0)
	assert_float(m.get_value()).is_equal(0.0)


func test_style_does_not_decay_inside_idle_grace() -> void:
	var m := StyleMeter.new(_tuning())
	m.add(50.0)
	m.tick(0.9)
	assert_float(m.get_value()).is_equal(50.0)


func test_style_decays_after_idle_grace() -> void:
	var m := StyleMeter.new(_tuning())
	m.add(50.0)
	m.tick(1.0)  # grace used up
	m.tick(1.0)  # one second of decay at 10/s
	assert_float(m.get_value()).is_equal_approx(40.0, 0.001)


func test_style_add_restarts_idle_grace() -> void:
	var m := StyleMeter.new(_tuning())
	m.add(50.0)
	m.tick(0.9)
	m.add(1.0)
	m.tick(0.9)
	assert_float(m.get_value()).is_equal(51.0)


func test_style_hit_penalty_floors_at_zero() -> void:
	var m := StyleMeter.new(_tuning())
	m.add(50.0)
	m.on_hit()
	assert_float(m.get_value()).is_equal(20.0)
	m.on_hit()
	assert_float(m.get_value()).is_equal(0.0)


func test_style_rank_for_thresholds() -> void:
	var m := StyleMeter.new(_tuning())
	assert_int(m.rank_for(60.0)).is_equal(StyleMeter.Rank.S)
	assert_int(m.rank_for(59.9)).is_equal(StyleMeter.Rank.A)
	assert_int(m.rank_for(40.0)).is_equal(StyleMeter.Rank.A)
	assert_int(m.rank_for(20.0)).is_equal(StyleMeter.Rank.B)
	assert_int(m.rank_for(10.0)).is_equal(StyleMeter.Rank.C)
	assert_int(m.rank_for(9.9)).is_equal(StyleMeter.Rank.D)


func test_style_room_rank_is_time_weighted_average() -> void:
	var m := StyleMeter.new(_tuning())
	m.begin_room()
	m.add(80.0)
	m.tick(0.5)   # 0.5 s at 80 (inside grace)
	m.on_hit()    # drop to 50
	m.tick(0.5)   # 0.5 s at 50
	assert_float(m.get_room_average()).is_equal_approx(65.0, 0.001)
	assert_int(m.end_room()).is_equal(StyleMeter.Rank.S)


func test_style_empty_room_ranks_d() -> void:
	var m := StyleMeter.new(_tuning())
	m.begin_room()
	assert_int(m.end_room()).is_equal(StyleMeter.Rank.D)


func test_style_meter_carries_over_between_rooms() -> void:
	var m := StyleMeter.new(_tuning())
	m.add(45.0)
	m.end_room()
	m.begin_room()
	assert_float(m.get_value()).is_equal(45.0)


func test_style_reset_clears_everything() -> void:
	var m := StyleMeter.new(_tuning())
	m.begin_room()
	m.add(45.0)
	m.tick(0.5)
	m.reset()
	assert_float(m.get_value()).is_equal(0.0)
	assert_float(m.get_room_average()).is_equal(0.0)


func test_style_letter_and_pick() -> void:
	assert_str(StyleMeter.letter(StyleMeter.Rank.S)).is_equal("S")
	assert_str(StyleMeter.letter(StyleMeter.Rank.D)).is_equal("D")
	var table := PackedFloat32Array([12.0, 8.0])
	assert_float(StyleMeter.pick(table, StyleMeter.Rank.A)).is_equal(8.0)
	assert_float(StyleMeter.pick(table, StyleMeter.Rank.C)).is_equal(0.0)
