## spawn_glyph_test.gd — spawn glyph timeline and drawing (ADR-0043).
extends GdUnitTestSuite


func _tuning() -> SpawnGlyphTuning:
	var t := SpawnGlyphTuning.new()
	t.draw_sec = 0.2
	t.rise_sec = 0.3
	t.settle_sec = 0.1
	t.fade_sec = 0.4
	t.alpha = 0.8
	return t


func test_rise_waits_for_draw_and_hold() -> void:
	var t: SpawnGlyphTuning = _tuning()
	assert_float(SpawnGlyph.rise_delay(t, 0.0)).is_equal_approx(0.2, 0.0001)
	assert_float(SpawnGlyph.rise_delay(t, 0.5)).is_equal_approx(0.7, 0.0001)


func test_negative_hold_is_ignored() -> void:
	var t: SpawnGlyphTuning = _tuning()
	assert_float(SpawnGlyph.rise_delay(t, -1.0)).is_equal_approx(0.2, 0.0001)


func test_active_and_total_follow_the_timeline() -> void:
	var t: SpawnGlyphTuning = _tuning()
	assert_float(SpawnGlyph.active_delay(t, 0.0)).is_equal_approx(0.6, 0.0001)
	assert_float(SpawnGlyph.total_sec(t, 0.0)).is_equal_approx(1.0, 0.0001)


func test_sweep_closes_over_draw_sec() -> void:
	var t: SpawnGlyphTuning = _tuning()
	assert_float(SpawnGlyph.sweep_at(0.0, t)).is_equal(0.0)
	assert_float(SpawnGlyph.sweep_at(0.1, t)).is_equal_approx(0.5, 0.0001)
	assert_float(SpawnGlyph.sweep_at(5.0, t)).is_equal(1.0)


func test_zero_draw_sec_is_drawn_at_once() -> void:
	var t: SpawnGlyphTuning = _tuning()
	t.draw_sec = 0.0
	assert_float(SpawnGlyph.sweep_at(0.0, t)).is_equal(1.0)


func test_alpha_is_full_until_fade_then_reaches_zero() -> void:
	var t: SpawnGlyphTuning = _tuning()
	assert_float(SpawnGlyph.alpha_at(0.05, t, 0.0)).is_equal_approx(0.8, 0.0001)
	assert_float(SpawnGlyph.alpha_at(0.55, t, 0.0)).is_equal_approx(0.8, 0.0001)
	assert_float(SpawnGlyph.alpha_at(0.8, t, 0.0)).is_equal_approx(0.4, 0.0001)
	assert_float(SpawnGlyph.alpha_at(1.0, t, 0.0)).is_equal(0.0)


func test_hold_pulses_between_seventy_and_full_strength() -> void:
	var t: SpawnGlyphTuning = _tuning()
	for i: int in 20:
		var a: float = SpawnGlyph.alpha_at(0.2 + 0.025 * float(i), t, 0.5)
		assert_float(a).is_between(0.8 * 0.7 - 0.0001, 0.8 + 0.0001)


func test_ellipse_is_flattened_by_iso_ratio() -> void:
	var p: Vector2 = SpawnGlyph.ellipse_point(10.0, PI * 0.5, 0.5)
	assert_float(p.x).is_equal_approx(0.0, 0.0001)
	assert_float(p.y).is_equal_approx(5.0, 0.0001)


func test_full_glyph_has_rings_and_runes() -> void:
	var g := SpawnGlyph.new()
	g.tuning = _tuning()
	var spans: Array = g._build_spans(1.0, 0.0)
	assert_int(spans.size()).is_equal(3)
	for s: Variant in spans:
		assert_int((s as PackedInt32Array).size()).is_greater(0)
	g.free()


func test_glyph_grows_with_size_mult() -> void:
	var g := SpawnGlyph.new()
	g.tuning = _tuning()
	var small: PackedInt32Array = g._build_spans(1.0, 0.0)[1]
	g.size_mult = 2.0
	var big: PackedInt32Array = g._build_spans(1.0, 0.0)[1]
	assert_int(_width(big)).is_greater(_width(small))
	g.free()


func test_glyph_frees_itself_after_its_lifetime() -> void:
	var g := SpawnGlyph.new()
	g.tuning = _tuning()
	add_child(g)
	g._process(SpawnGlyph.total_sec(g.tuning, 0.0) + 0.01)
	assert_bool(g.is_queued_for_deletion()).is_true()
	await get_tree().process_frame


func test_glyph_sits_on_the_floor_layer() -> void:
	var g := SpawnGlyph.new()
	g.tuning = _tuning()
	add_child(g)
	assert_int(g.z_index).is_equal(SpawnGlyph.FLOOR_Z)
	g.free()


func test_shipped_tuning_loads() -> void:
	var t: SpawnGlyphTuning = WaveManager.SPAWN_GLYPH_TUNING
	assert_object(t).is_not_null()
	assert_float(t.draw_sec).is_greater(0.0)
	assert_float(t.rise_sec).is_greater(0.0)


## x extent covered by a span list (max x1 - min x0).
func _width(spans: PackedInt32Array) -> int:
	var lo: int = 1 << 30
	var hi: int = -(1 << 30)
	var i: int = 0
	while i + 2 < spans.size():
		lo = mini(lo, spans[i + 1])
		hi = maxi(hi, spans[i + 2])
		i += 3
	return hi - lo
