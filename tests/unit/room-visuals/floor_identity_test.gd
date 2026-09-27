## floor_identity_test.gd — per-floor props, motif tiles, backdrop silhouettes and whimsy (ADR-0038).
extends GdUnitTestSuite

const ROOM_SCENE: PackedScene = preload("res://src/scenes/IsometricRoom.tscn")
const THEME_PATHS: Array[String] = [
	"res://assets/data/floor_themes/floor_theme_1.tres",
	"res://assets/data/floor_themes/floor_theme_2.tres",
	"res://assets/data/floor_themes/floor_theme_3.tres",
]
const BOSS_TYPE: int = 3


func _theme(i: int) -> FloorTheme:
	return load(THEME_PATHS[i]) as FloorTheme


func _build(theme: FloorTheme, template: RoomTemplate = null, decor_seed: int = 7) -> IsometricRoom:
	var room: IsometricRoom = ROOM_SCENE.instantiate()
	room.floor_theme = theme
	room.room_template = template
	room.decor_seed = decor_seed
	add_child(room)
	return room


func _destroy(room: IsometricRoom) -> void:
	remove_child(room)
	room.free()


func _decor(room: IsometricRoom) -> RoomDecor:
	return room.get_node("RoomDecor") as RoomDecor


# ── Floor looks ────────────────────────────────────────────────────────────────

func test_each_floor_has_its_own_motif() -> void:
	var seen: Array[int] = []
	for i: int in THEME_PATHS.size():
		var m: int = _theme(i).look.motif
		assert_int(m).is_not_equal(RoomLook.Motif.STONE)
		assert_bool(seen.has(m)).is_false()
		seen.append(m)


func test_each_floor_has_its_own_whimsy_pool() -> void:
	var seen: Dictionary = {}
	for i: int in THEME_PATHS.size():
		var kinds: Array[int] = _theme(i).look.whimsy_kinds
		assert_int(kinds.size()).is_greater(0)
		for k: int in kinds:
			assert_int(k).is_between(0, RoomLook.Whimsy.size() - 1)
			assert_bool(seen.has(k)).is_false()
			seen[k] = true


func test_each_motif_has_its_own_prop_set() -> void:
	var seen: Dictionary = {}
	for m: int in RoomLook.Motif.values():
		for p: int in PropArt.rim_props(m):
			assert_bool(seen.has(p)).is_false()
			seen[p] = true
		assert_bool(PropArt.hangs(PropArt.face_prop(m))).is_true()


# ── PropArt ────────────────────────────────────────────────────────────────────

func test_every_prop_paints_a_shape_with_empty_corners() -> void:
	var look := RoomLook.new()
	for p: int in PropArt.Prop.values():
		var img: Image = PropArt.build_image(p, look)
		assert_object(Vector2i(img.get_width(), img.get_height())).is_equal(PropArt.SIZES[p])
		assert_float(img.get_pixel(0, 0).a).is_equal(0.0)
		var filled: int = 0
		for y: int in img.get_height():
			for x: int in img.get_width():
				if img.get_pixel(x, y).a > 0.0:
					filled += 1
		assert_int(filled).is_greater(20)


func test_props_are_deterministic() -> void:
	var look := RoomLook.new()
	for p: int in PropArt.Prop.values():
		assert_bool(PropArt.build_image(p, look).get_data() == PropArt.build_image(p, look).get_data()).is_true()


func test_props_only_use_the_look_palette() -> void:
	var look: RoomLook = _theme(2).look
	var palette: Array[Color] = [look.prop_dark, look.prop_mid, look.prop_light, look.prop_glow]
	for p: int in PropArt.rim_props(look.motif):
		var img: Image = PropArt.build_image(p, look)
		for y: int in img.get_height():
			for x: int in img.get_width():
				var c: Color = img.get_pixel(x, y)
				if c.a == 0.0:
					continue
				var found: bool = false
				for q: Color in palette:
					# RGBA8 storage rounds each channel to 1/255.
					if absf(c.r - q.r) < 0.01 and absf(c.g - q.g) < 0.01 and absf(c.b - q.b) < 0.01:
						found = true
				assert_bool(found).is_true()


func test_prop_palettes_stay_below_jewel_saturation() -> void:
	# Art bible rule 3: full jewel-tone saturation belongs to magic only.
	for i: int in THEME_PATHS.size():
		var look: RoomLook = _theme(i).look
		for c: Color in [look.prop_dark, look.prop_mid, look.prop_light, look.prop_glow, look.silhouette]:
			assert_float(c.s).is_less(0.6)


# ── Motif tiles ────────────────────────────────────────────────────────────────

func test_stone_look_never_picks_the_motif_tile() -> void:
	var look := RoomLook.new()
	look.worn_chance = 1.0
	look.motif_chance = 1.0
	for x: int in range(-10, 10):
		assert_int(FloorTileAtlas.variant_for_cell(Vector2i(x, 3), look)).is_not_equal(FloorTileAtlas.Variant.MOTIF)


func test_motif_look_picks_the_motif_tile() -> void:
	var look := RoomLook.new()
	look.motif = RoomLook.Motif.CONDUIT
	look.glyph_chance = 0.0
	look.crack_chance = 0.0
	look.worn_chance = 1.0
	look.motif_chance = 1.0
	assert_int(FloorTileAtlas.variant_for_cell(Vector2i(2, 5), look)).is_equal(FloorTileAtlas.Variant.MOTIF)


func test_each_motif_paints_a_different_tile() -> void:
	var tiles: Array[PackedByteArray] = []
	for m: int in [RoomLook.Motif.SCRAP, RoomLook.Motif.CONDUIT, RoomLook.Motif.CRYSTAL]:
		var look := RoomLook.new()
		look.motif = m
		var img: Image = FloorTileAtlas.build_image(look)
		var tile: Image = img.get_region(Rect2i(FloorTileAtlas.Variant.MOTIF * FloorTileAtlas.TILE_W, 0, FloorTileAtlas.TILE_W, FloorTileAtlas.TILE_H))
		var worn: Image = img.get_region(Rect2i(FloorTileAtlas.Variant.WORN * FloorTileAtlas.TILE_W, 0, FloorTileAtlas.TILE_W, FloorTileAtlas.TILE_H))
		assert_bool(tile.get_data() == worn.get_data()).is_false()
		for t: PackedByteArray in tiles:
			assert_bool(t == tile.get_data()).is_false()
		tiles.append(tile.get_data())


# ── Backdrop ───────────────────────────────────────────────────────────────────

func test_backdrop_takes_the_motif_and_silhouette() -> void:
	var look: RoomLook = _theme(1).look
	var bd := RoomBackdrop.new()
	bd.setup(look)
	assert_int(int(bd.get_backdrop_param(&"motif"))).is_equal(RoomLook.Motif.CONDUIT)
	assert_object(bd.get_backdrop_param(&"silhouette_color")).is_equal(look.silhouette)
	bd.free()


# ── Room decor ─────────────────────────────────────────────────────────────────

func test_every_floor_room_gets_props_and_one_whimsy() -> void:
	for i: int in THEME_PATHS.size():
		var theme: FloorTheme = _theme(i)
		var room := _build(theme)
		var decor: RoomDecor = _decor(room)
		var rim: Array[Node] = decor.get_rim_props()
		assert_int(rim.size()).is_between(1, theme.look.rim_props_max)
		assert_int(decor.get_face_props().size()).is_greater(0)
		assert_object(decor.get_whimsy()).is_not_null()
		assert_bool(theme.look.whimsy_kinds.has(decor.get_whimsy().kind)).is_true()
		var allowed: Array[int] = PropArt.rim_props(theme.look.motif)
		for p: Node in rim:
			assert_bool(allowed.has(int(p.get_meta(&"prop")))).is_true()
		_destroy(room)


func test_decor_owns_no_collision_or_navigation() -> void:
	for i: int in THEME_PATHS.size():
		var room := _build(_theme(i))
		var stack: Array[Node] = [_decor(room)]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			assert_bool(n is CollisionObject2D or n is CollisionShape2D or n is NavigationObstacle2D).is_false()
			stack.append_array(n.get_children())
		_destroy(room)


func test_rim_props_and_whimsy_stand_off_the_walkable_floor() -> void:
	for i: int in THEME_PATHS.size():
		var room := _build(_theme(i))
		var tm: TileMapLayer = room.get_node("TileMapLayer")
		var used: Dictionary = {}
		for c: Vector2i in tm.get_used_cells():
			used[c] = true
		var decor: RoomDecor = _decor(room)
		var points: Array[Vector2] = []
		for p: Node in decor.get_rim_props():
			points.append((p as Node2D).position)
		points.append(decor.get_whimsy().position)
		for pt: Vector2 in points:
			assert_bool(used.has(tm.local_to_map(pt))).is_false()
		_destroy(room)


func test_back_ledge_lies_outside_the_floor() -> void:
	var room := _build(_theme(0))
	var tm: TileMapLayer = room.get_node("TileMapLayer")
	var used: Dictionary = {}
	for c: Vector2i in tm.get_used_cells():
		used[c] = true
	var cells: Array[Vector2] = RoomDecor.ledge_cells(room.get_upper_boundary_edges())
	assert_int(cells.size()).is_greater(0)
	for c: Vector2 in cells:
		assert_bool(used.has(tm.local_to_map(c))).is_false()
	# Per tile: two faces, the cap and the two lip segments (ADR-0050 QuadBatch).
	assert_int(_decor(room).get_ledge().quad_count()).is_equal(cells.size() * 5)
	_destroy(room)


func test_rim_props_keep_clear_of_the_exit_doors() -> void:
	var room := _build(_theme(0))
	var doors: Array[Vector2] = []
	for c: Node in room.get_children():
		if c is RoomExitDoor:
			doors.append((c as Node2D).position)
	assert_int(doors.size()).is_greater(0)
	for p: Node in _decor(room).get_rim_props():
		for d: Vector2 in doors:
			assert_float((p as Node2D).position.distance_to(d)).is_greater_equal(RoomDecor.KEEP_CLEAR)
	_destroy(room)


func test_decor_does_not_change_the_room_layout() -> void:
	# Same room built twice with different decor seeds: identical floor and walls.
	var a := _build(_theme(1), null, 1)
	var b := _build(_theme(1), null, 99)
	var ta: TileMapLayer = a.get_node("TileMapLayer")
	var tb: TileMapLayer = b.get_node("TileMapLayer")
	assert_int(ta.get_used_cells().size()).is_equal(tb.get_used_cells().size())
	assert_int(a.get_node("ArenaBounds").get_child_count()).is_equal(b.get_node("ArenaBounds").get_child_count())
	_destroy(a)
	_destroy(b)


func test_same_seed_gives_the_same_decor() -> void:
	var a := _build(_theme(2), null, 42)
	var b := _build(_theme(2), null, 42)
	var pa: Array[Node] = _decor(a).get_rim_props()
	var pb: Array[Node] = _decor(b).get_rim_props()
	assert_int(pa.size()).is_equal(pb.size())
	for k: int in pa.size():
		assert_int(int(pa[k].get_meta(&"prop"))).is_equal(int(pb[k].get_meta(&"prop")))
		assert_object((pa[k] as Node2D).position).is_equal((pb[k] as Node2D).position)
	assert_int(_decor(a).get_whimsy().kind).is_equal(_decor(b).get_whimsy().kind)
	_destroy(a)
	_destroy(b)


func test_boss_room_gets_one_accent_and_no_clutter() -> void:
	var tmpl: RoomTemplate = _theme(0).boss_templates[0]
	assert_int(tmpl.room_type).is_equal(BOSS_TYPE)
	var room := _build(_theme(0), tmpl)
	var decor: RoomDecor = _decor(room)
	var rim: Array[Node] = decor.get_rim_props()
	assert_int(rim.size()).is_equal(1)
	assert_int(int(rim[0].get_meta(&"prop"))).is_equal(PropArt.Prop.BROKEN_COLUMN)
	assert_int(decor.get_face_props().size()).is_equal(0)
	assert_object(decor.get_whimsy()).is_not_null()
	_destroy(room)


func test_whimsy_holds_still_with_reduce_motion() -> void:
	var w := WhimsyDetail.new()
	w.setup(RoomLook.Whimsy.STEAM_VENT, RoomLook.new(), 0.0)
	var had: GameSettings = GameSettings.current
	var s := GameSettings.new()
	s.reduce_motion = true
	GameSettings.current = s
	w._process(0.5)
	assert_float(w.clock()).is_equal(0.0)
	GameSettings.current = had
	w.free()


func test_first_room_can_be_reskinned_with_the_floor_look() -> void:
	var room := _build(null)
	var cells_before: int = (room.get_node("TileMapLayer") as TileMapLayer).get_used_cells().size()
	var walls_before: int = room.get_node("ArenaBounds").get_child_count()
	var theme: FloorTheme = _theme(1)
	room.apply_floor_look(theme)
	assert_object(room.get_look()).is_same(theme.look)
	assert_int((room.get_node("TileMapLayer") as TileMapLayer).get_used_cells().size()).is_equal(cells_before)
	assert_int(room.get_node("ArenaBounds").get_child_count()).is_equal(walls_before)
	var decor: RoomDecor = _decor(room)
	assert_bool(theme.look.whimsy_kinds.has(decor.get_whimsy().kind)).is_true()
	var bd: RoomBackdrop = room.get_node("RoomBackdrop")
	assert_int(int(bd.get_backdrop_param(&"motif"))).is_equal(RoomLook.Motif.CONDUIT)
	_destroy(room)
