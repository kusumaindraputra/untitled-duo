## pixel_vfx_test.gd — pixel-art raster helpers for spell VFX (ADR-0023).
extends GdUnitTestSuite

const SPELL_VFX: String = "res://src/ui/spell_vfx.gd"
const DEBUG_CIRCLE: String = "res://src/scenes/debug_circle_2d.gd"


## Expands a span list into a cell set for easy assertions.
func _cells(spans: PackedInt32Array) -> Dictionary:
	var out: Dictionary = {}
	var i: int = 0
	while i + 2 < spans.size():
		for x: int in range(spans[i + 1], spans[i + 2] + 1):
			out[Vector2i(x, spans[i])] = true
		i += 3
	return out


# ── Colour ───────────────────────────────────────────────────────────────────

func test_quantize_alpha_snaps_to_flat_steps() -> void:
	assert_float(PixelVFX.quantize_alpha(1.0)).is_equal(1.0)
	assert_float(PixelVFX.quantize_alpha(0.7)).is_equal(0.75)
	assert_float(PixelVFX.quantize_alpha(0.3)).is_equal(0.25)
	assert_float(PixelVFX.quantize_alpha(0.1)).is_equal(0.0)
	assert_float(PixelVFX.quantize_alpha(0.1, PixelVFX.FILL_ALPHA_STEPS)).is_equal(0.125)


func test_quantize_alpha_clamps_out_of_range() -> void:
	assert_float(PixelVFX.quantize_alpha(-0.5)).is_equal(0.0)
	assert_float(PixelVFX.quantize_alpha(2.0)).is_equal(1.0)


func test_palette_orders_dark_base_light() -> void:
	var ramp: Array[Color] = PixelVFX.palette(Color(0.5, 0.4, 0.3, 0.2))
	assert_int(ramp.size()).is_equal(3)
	assert_float(ramp[0].get_luminance()).is_less(ramp[1].get_luminance())
	assert_float(ramp[1].get_luminance()).is_less(ramp[2].get_luminance())
	for c: Color in ramp:
		assert_float(c.a).is_equal(1.0)


# ── Discs and rings ──────────────────────────────────────────────────────────

func test_disc_spans_area_matches_circle() -> void:
	var r: float = 20.0
	var n: int = _cells(PixelVFX.disc_spans(r)).size()
	assert_float(float(n)).is_between(PI * r * r * 0.95, PI * r * r * 1.05)


func test_disc_spans_are_symmetric() -> void:
	var cells: Dictionary = _cells(PixelVFX.disc_spans(9.5))
	for c: Vector2i in cells:
		assert_bool(cells.has(Vector2i(-c.x - 1, c.y))).is_true()
		assert_bool(cells.has(Vector2i(c.x, -c.y - 1))).is_true()


func test_disc_spans_empty_for_zero_radius() -> void:
	assert_int(PixelVFX.disc_spans(0.0).size()).is_equal(0)


func test_ring_spans_leave_the_middle_empty() -> void:
	var cells: Dictionary = _cells(PixelVFX.ring_spans(30.0, 4.0))
	assert_bool(cells.has(Vector2i(0, 0))).is_false()
	assert_bool(cells.has(Vector2i(29, 0))).is_true()
	assert_bool(cells.has(Vector2i(-30, -1))).is_true()


func test_ring_spans_have_no_holes_around_the_circle() -> void:
	var cells: Dictionary = _cells(PixelVFX.ring_spans(40.0, 2.0))
	for i: int in 360:
		var p: Vector2 = Vector2.from_angle(deg_to_rad(float(i))) * 40.0
		var hit: bool = false
		for dx: int in [-1, 0, 1]:
			for dy: int in [-1, 0, 1]:
				if cells.has(Vector2i(floori(p.x) + dx, floori(p.y) + dy)):
					hit = true
		assert_bool(hit).override_failure_message("gap at %d deg" % i).is_true()


func test_ring_spans_area_matches_annulus() -> void:
	var n: int = _cells(PixelVFX.ring_spans(50.0, 4.0)).size()
	var expected: float = TAU * 50.0 * 4.0
	assert_float(float(n)).is_between(expected * 0.9, expected * 1.1)


# ── Strokes ──────────────────────────────────────────────────────────────────

func test_line_cells_cover_both_endpoints() -> void:
	var cells: Dictionary = PixelVFX.line_cells(Vector2(0.5, 0.5), Vector2(20.5, 10.5), 1.0)
	assert_bool(cells.has(Vector2i(0, 0))).is_true()
	assert_bool(cells.has(Vector2i(20, 10))).is_true()


func test_line_cells_one_pixel_wide_is_one_cell_per_column() -> void:
	var cells: Dictionary = PixelVFX.line_cells(Vector2(0.5, 0.5), Vector2(30.5, 0.5), 1.0)
	assert_int(cells.size()).is_equal(31)


func test_line_cells_width_scales_thickness() -> void:
	var cells: Dictionary = PixelVFX.line_cells(Vector2(0.0, 0.5), Vector2(30.0, 0.5), 4.0)
	var rows: Dictionary = {}
	for c: Vector2i in cells:
		rows[c.y] = true
	assert_int(rows.size()).is_between(4, 5)


func test_arc_cells_stay_within_the_swept_angles() -> void:
	var cells: Dictionary = PixelVFX.arc_cells(Vector2.ZERO, 30.0, 0.0, PI * 0.5, 1.0)
	for c: Vector2i in cells:
		assert_int(c.x).is_greater_equal(-1)
		assert_int(c.y).is_greater_equal(-1)
		var d: float = (Vector2(c) + Vector2(0.5, 0.5)).length()
		assert_float(d).is_between(28.5, 31.5)


func test_cells_to_spans_merges_runs() -> void:
	var cells: Dictionary = {
		Vector2i(0, 0): true, Vector2i(1, 0): true, Vector2i(2, 0): true,
		Vector2i(5, 0): true, Vector2i(0, 1): true,
	}
	var spans: PackedInt32Array = PixelVFX.cells_to_spans(cells)
	assert_array(Array(spans)).is_equal([0, 0, 2, 0, 5, 5, 1, 0, 0])


func test_convex_polygon_spans_fill_a_square() -> void:
	var sq := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
	assert_int(_cells(PixelVFX.convex_polygon_spans(sq)).size()).is_equal(100)


func test_convex_polygon_spans_row_stride_keeps_every_other_row() -> void:
	var sq := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
	var cells: Dictionary = _cells(PixelVFX.convex_polygon_spans(sq, 2))
	assert_int(cells.size()).is_equal(50)
	for c: Vector2i in cells:
		assert_int(c.y % 2).is_equal(0)


# ── Grid alignment ───────────────────────────────────────────────────────────

func test_snap_origin_aligns_to_world_grid() -> void:
	var n := Node2D.new()
	add_child(n)
	n.global_position = Vector2(10.75, -3.25)
	var o: Vector2 = PixelVFX.snap_origin(n)
	assert_vector(n.global_position + o).is_equal(Vector2(10.0, -4.0))
	n.free()


func test_snap_origin_is_zero_outside_the_tree() -> void:
	var n := Node2D.new()
	assert_vector(PixelVFX.snap_origin(n)).is_equal(Vector2.ZERO)
	n.free()


# ── Wiring guard ─────────────────────────────────────────────────────────────

## Spell VFX and Fayde's cast beam must not fall back to antialiased vector
## strokes, which break the pixel-art look (ADR-0023).
func test_spell_vfx_and_cast_beam_use_no_vector_strokes() -> void:
	for path: String in [SPELL_VFX, DEBUG_CIRCLE]:
		var src: String = FileAccess.get_file_as_string(path)
		for call: String in ["draw_arc(", "draw_line(", "draw_polyline(", "draw_circle("]:
			assert_bool(src.contains(call)).override_failure_message(
					"%s still calls %s" % [path, call]).is_false()
