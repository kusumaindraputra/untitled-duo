## floor_lighting_test.gd — floor light mask, pulse pool and bullet light cap (ADR-0043).
extends GdUnitTestSuite

const ROOM_SCENE: PackedScene = preload("res://src/scenes/IsometricRoom.tscn")


func _tuning(pulses: int = 2, bullets: int = 2) -> FloorLightingTuning:
	var t := FloorLightingTuning.new()
	t.pulse_pool_size = pulses
	t.bullet_light_cap = bullets
	return t


func _lighting(t: FloorLightingTuning, floor_item: CanvasItem = null) -> FloorLighting:
	var fl := FloorLighting.new()
	fl.tuning = t
	fl.floor_item = floor_item
	add_child(fl)
	return fl


# ── Pure helpers ─────────────────────────────────────────────────────────────

func test_pulse_energy_fades_linearly() -> void:
	assert_float(FloorLighting.pulse_energy(1.0, 0.5, 1.0, 1.0)).is_equal_approx(0.5, 0.0001)
	assert_float(FloorLighting.pulse_energy(1.0, 0.0, 1.0, 1.0)).is_equal(0.0)
	assert_float(FloorLighting.pulse_energy(1.0, 2.0, 1.0, 1.0)).is_equal(1.0)


func test_pulse_energy_scales_with_flash_multiplier() -> void:
	assert_float(FloorLighting.pulse_energy(2.0, 1.0, 1.0, 0.25)).is_equal_approx(0.5, 0.0001)


func test_pulse_energy_zero_length_is_dark() -> void:
	assert_float(FloorLighting.pulse_energy(1.0, 1.0, 0.0, 1.0)).is_equal(0.0)


func test_texture_scale_covers_radius() -> void:
	assert_float(FloorLighting.texture_scale_for(64.0, 64)).is_equal_approx(2.0, 0.0001)


func test_light_texture_is_banded_radial() -> void:
	var tex: GradientTexture2D = FloorLighting.build_light_texture(32, 4)
	assert_int(tex.fill).is_equal(GradientTexture2D.FILL_RADIAL)
	assert_int(tex.gradient.interpolation_mode).is_equal(Gradient.GRADIENT_INTERPOLATE_CONSTANT)
	assert_int(tex.gradient.get_point_count()).is_equal(5)
	assert_float(tex.gradient.get_color(0).a).is_equal(1.0)
	assert_float(tex.gradient.get_color(4).a).is_equal(0.0)


# ── Node behaviour ───────────────────────────────────────────────────────────

func test_lights_only_reach_the_floor_mask() -> void:
	var fl: FloorLighting = _lighting(_tuning())
	for c: Node in fl.get_children():
		var l := c as PointLight2D
		assert_object(l).is_not_null()
		assert_int(l.range_item_cull_mask).is_equal(FloorLighting.FLOOR_LIGHT_MASK)
		assert_bool(l.shadow_enabled).is_false()
	fl.free()


func test_light_count_is_fixed_by_the_pools() -> void:
	var fl: FloorLighting = _lighting(_tuning(3, 4))
	# Fayde + 3 pulses + 4 bullet lights.
	assert_int(fl.get_child_count()).is_equal(8)
	fl.free()


func test_disabled_tuning_adds_no_lights() -> void:
	var t: FloorLightingTuning = _tuning()
	t.enabled = false
	var fl: FloorLighting = _lighting(t)
	assert_int(fl.get_child_count()).is_equal(0)
	assert_object(fl.pulse(Vector2.ZERO, Color.WHITE, 1.0, 10.0, 0.2)).is_null()
	fl.free()


func test_pulse_reuses_the_oldest_when_full() -> void:
	var fl: FloorLighting = _lighting(_tuning(2, 0))
	var a: PointLight2D = fl.pulse(Vector2(1, 0), Color.RED, 1.0, 10.0, 1.0)
	var b: PointLight2D = fl.pulse(Vector2(2, 0), Color.GREEN, 1.0, 10.0, 1.0)
	var c: PointLight2D = fl.pulse(Vector2(3, 0), Color.BLUE, 1.0, 10.0, 1.0)
	assert_object(a).is_not_same(b)
	assert_object(c).is_same(a)
	assert_int(fl.active_pulse_count()).is_equal(2)
	assert_vector(c.global_position).is_equal(Vector2(3, 0))
	fl.free()


func test_pulse_fades_out_and_hides() -> void:
	var fl: FloorLighting = _lighting(_tuning(1, 0))
	var l: PointLight2D = fl.pulse(Vector2.ZERO, Color.WHITE, 1.0, 10.0, 0.2)
	assert_bool(l.visible).is_true()
	fl._tick_pulses(0.1)
	assert_float(l.energy).is_less(1.0)
	fl._tick_pulses(0.2)
	assert_bool(l.visible).is_false()
	assert_int(fl.active_pulse_count()).is_equal(0)
	fl.free()


func test_bullet_lights_respect_the_cap() -> void:
	var fl: FloorLighting = _lighting(_tuning(0, 2))
	var bullets: Array = []
	for i: int in 5:
		var b := Node2D.new()
		add_child(b)
		bullets.append(b)
	assert_int(fl.assign_bullet_lights(bullets)).is_equal(2)
	# Stable: the same two bullets keep their lights on the next refresh.
	assert_int(fl.assign_bullet_lights(bullets)).is_equal(2)
	for b: Node2D in bullets:
		b.free()
	fl.free()


func test_bullet_light_moves_to_a_new_bullet_when_one_is_gone() -> void:
	var fl: FloorLighting = _lighting(_tuning(0, 1))
	var first := Node2D.new()
	var second := Node2D.new()
	add_child(first)
	add_child(second)
	second.position = Vector2(40, 0)
	fl.assign_bullet_lights([first, second])
	first.free()
	assert_int(fl.assign_bullet_lights([second])).is_equal(1)
	var lit: int = 0
	for c: Node in fl.get_children():
		var l := c as PointLight2D
		if l.visible and l.global_position == Vector2(40, 0):
			lit += 1
	assert_int(lit).is_equal(1)
	second.free()
	fl.free()


func test_attach_floor_adds_the_light_mask_bit() -> void:
	var floor_item := Node2D.new()
	add_child(floor_item)
	var fl: FloorLighting = _lighting(_tuning(), floor_item)
	assert_int(floor_item.light_mask & FloorLighting.FLOOR_LIGHT_MASK).is_equal(FloorLighting.FLOOR_LIGHT_MASK)
	# The default bit stays, so the floor keeps any other light it had.
	assert_int(floor_item.light_mask & 1).is_equal(1)
	fl.free()
	floor_item.free()


func test_room_adds_lighting_on_the_floor_tiles() -> void:
	var room: IsometricRoom = ROOM_SCENE.instantiate() as IsometricRoom
	room.decor_seed = 7
	add_child(room)
	var fl: FloorLighting = room.get_floor_lighting()
	assert_object(fl).is_not_null()
	var tiles: TileMapLayer = room.get_node(^"TileMapLayer") as TileMapLayer
	assert_object(fl.floor_item).is_same(tiles)
	assert_int(tiles.light_mask & FloorLighting.FLOOR_LIGHT_MASK).is_equal(FloorLighting.FLOOR_LIGHT_MASK)
	# Sprites keep the default mask, so floor lights never relight them.
	assert_int(room.light_mask & FloorLighting.FLOOR_LIGHT_MASK).is_equal(0)
	room.free()


func test_shipped_tuning_keeps_the_light_budget_small() -> void:
	var t: FloorLightingTuning = FloorLighting.TUNING
	assert_bool(t.enabled).is_true()
	# Fayde + pulses + bullets stays within 16 lights for the web build.
	assert_int(1 + t.pulse_pool_size + t.bullet_light_cap).is_less_equal(16)
