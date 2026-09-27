## room_visuals_test.gd — procedural floor tiles, platform edge and backdrop (ADR-0021).
extends GdUnitTestSuite

const ROOM_SCENE: PackedScene = preload("res://src/scenes/IsometricRoom.tscn")
const THEME_PATHS: Array[String] = [
	"res://assets/data/floor_themes/floor_theme_1.tres",
	"res://assets/data/floor_themes/floor_theme_2.tres",
	"res://assets/data/floor_themes/floor_theme_3.tres",
]


# ── FloorTileAtlas ───────────────────────────────────────────────────────────

func test_atlas_has_one_tile_per_variant() -> void:
	var img: Image = FloorTileAtlas.build_image(RoomLook.new())
	assert_int(img.get_width()).is_equal(FloorTileAtlas.TILE_W * FloorTileAtlas.VARIANT_COUNT)
	assert_int(img.get_height()).is_equal(FloorTileAtlas.TILE_H)


func test_every_tile_is_a_diamond() -> void:
	var img: Image = FloorTileAtlas.build_image(RoomLook.new())
	for v: int in FloorTileAtlas.VARIANT_COUNT:
		var ox: int = v * FloorTileAtlas.TILE_W
		# Centre is solid, the four corners are empty.
		assert_float(img.get_pixel(ox + 32, 16).a).is_equal(1.0)
		assert_float(img.get_pixel(ox, 0).a).is_equal(0.0)
		assert_float(img.get_pixel(ox + 63, 0).a).is_equal(0.0)
		assert_float(img.get_pixel(ox, 31).a).is_equal(0.0)
		assert_float(img.get_pixel(ox + 63, 31).a).is_equal(0.0)


func test_atlas_is_deterministic() -> void:
	var look := RoomLook.new()
	var a: PackedByteArray = FloorTileAtlas.build_image(look).get_data()
	var b: PackedByteArray = FloorTileAtlas.build_image(look).get_data()
	assert_bool(a == b).is_true()


func test_atlas_follows_the_look_colours() -> void:
	var look := RoomLook.new()
	look.floor_base = Color(0.0, 0.0, 1.0)
	look.grain = 0.0
	var img: Image = FloorTileAtlas.build_image(look)
	var c: Color = img.get_pixel(20, 16)  # plain tile, inside the bevel
	assert_float(c.b).is_equal_approx(1.0, 0.01)
	assert_float(c.r).is_equal_approx(0.0, 0.01)


func test_variant_is_plain_when_every_chance_is_zero() -> void:
	var look := RoomLook.new()
	look.glyph_chance = 0.0
	look.crack_chance = 0.0
	look.worn_chance = 0.0
	for x: int in range(-10, 10):
		for y: int in range(-10, 10):
			assert_int(FloorTileAtlas.variant_for_cell(Vector2i(x, y), look)).is_equal(FloorTileAtlas.Variant.PLAIN)


func test_variant_is_glyph_when_glyph_chance_is_one() -> void:
	var look := RoomLook.new()
	look.glyph_chance = 1.0
	assert_int(FloorTileAtlas.variant_for_cell(Vector2i(3, -7), look)).is_equal(FloorTileAtlas.Variant.GLYPH)


func test_variant_share_matches_the_chances() -> void:
	var look := RoomLook.new()
	look.glyph_chance = 0.0
	look.crack_chance = 0.0
	look.worn_chance = 0.5
	var worn: int = 0
	for x: int in range(-20, 20):
		for y: int in range(-20, 20):
			if FloorTileAtlas.variant_for_cell(Vector2i(x, y), look) == FloorTileAtlas.Variant.WORN:
				worn += 1
	# 1600 cells at 50 %: well inside 40–60 % for a decent hash.
	assert_int(worn).is_between(640, 960)


func test_hash01_stays_in_unit_range() -> void:
	for i: int in range(-50, 50):
		var h: float = FloorTileAtlas.hash01(i, i * 7, 3)
		assert_bool(h >= 0.0 and h < 1.0).is_true()


# ── RoomBackdrop ─────────────────────────────────────────────────────────────

func test_backdrop_takes_its_colours_from_the_look() -> void:
	var look := RoomLook.new()
	look.backdrop_top = Color(0.1, 0.2, 0.3)
	look.vignette = 0.6
	var bd := RoomBackdrop.new()
	bd.setup(look)
	assert_object(bd.get_backdrop_param(&"top_color")).is_equal(look.backdrop_top)
	assert_float(bd.get_vignette_strength()).is_equal_approx(0.6, 0.001)
	bd.free()


func test_backdrop_sits_under_the_world_and_vignette_under_the_hud() -> void:
	var bd := RoomBackdrop.new()
	bd.setup(RoomLook.new())
	var back: CanvasLayer = bd.get_node("Backdrop")
	var front: CanvasLayer = bd.get_node("Vignette")
	assert_int(back.layer).is_less(0)
	assert_int(front.layer).is_greater(0)
	assert_int(front.layer).is_less(10)  # CombatHUD CanvasLayer
	bd.free()


# ── Floor themes and rooms ───────────────────────────────────────────────────

func test_every_floor_theme_has_its_own_look() -> void:
	var seen: Array[RoomLook] = []
	for path: String in THEME_PATHS:
		var theme: FloorTheme = load(path)
		assert_object(theme.look).is_not_null()
		assert_bool(seen.has(theme.look)).is_false()
		seen.append(theme.look)


func _build(theme: FloorTheme = null) -> IsometricRoom:
	var room: IsometricRoom = ROOM_SCENE.instantiate()
	room.floor_theme = theme
	add_child(room)
	return room


func _destroy(room: IsometricRoom) -> void:
	remove_child(room)
	room.free()


func test_room_without_theme_uses_the_default_look() -> void:
	var room := _build()
	assert_object(room.get_look()).is_not_null()
	assert_object(room.get_look().floor_base).is_equal(RoomLook.new().floor_base)
	_destroy(room)


func test_room_uses_the_theme_look() -> void:
	var theme: FloorTheme = load(THEME_PATHS[2])
	var room := _build(theme)
	assert_object(room.get_look()).is_same(theme.look)
	_destroy(room)


func test_room_floor_uses_several_tile_variants() -> void:
	var room := _build()
	var tm: TileMapLayer = room.get_node("TileMapLayer")
	var variants: Dictionary = {}
	for cell: Vector2i in tm.get_used_cells():
		variants[tm.get_cell_atlas_coords(cell).x] = true
	assert_int(variants.size()).is_greater(1)
	_destroy(room)


func test_platform_edge_hangs_under_the_lower_boundary() -> void:
	var room := _build()
	var edges: Array[PackedVector2Array] = room.get_lower_boundary_edges()
	assert_int(edges.size()).is_greater(0)
	var edge_root: QuadBatch = room.get_node("PlatformEdge") as QuadBatch
	assert_int(edge_root.quad_count()).is_equal(edges.size())
	assert_int(edge_root.z_index).is_less(0)
	# Edges come back ordered left to right.
	for e: PackedVector2Array in edges:
		assert_bool(e[0].x < e[1].x).is_true()
	_destroy(room)


func test_room_adds_a_backdrop() -> void:
	var room := _build()
	assert_object(room.get_node_or_null("RoomBackdrop")).is_not_null()
	_destroy(room)
