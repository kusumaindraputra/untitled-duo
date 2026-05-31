## adr_0001_api_test.gd — ADR-0001 API verification: TileMapLayer isometric +
## Compatibility renderer (Godot 4.6).
##
## Coverage:
##   V-1: TileMapLayer class exists and instantiates without error
##   V-2: TileSet.TILE_SHAPE_ISOMETRIC constant equals 1 (isometric, not square)
##   V-3: TileSet.tile_shape can be set to TILE_SHAPE_ISOMETRIC and read back
##   V-4: TileSet.tile_size can be set to Vector2i(64, 32) and read back
##   V-5: TileMapLayer.tile_set accepts an isometric TileSet assignment
##   V-6: Node2D.y_sort_enabled property is readable and writable
##   V-7: TileMapLayer is the correct class (not deprecated TileMap)
##
## Visual y-sort ordering (draw-order correctness) is NOT verified here — it
## requires rendering output and is deferred to Story 003 AC-4 (Advisory manual
## check documented in production/qa/evidence/isometric-room-ysort-evidence.md).
##
## Result: PASS here → ADR-0001 Validation section updated with API PASS verdict.
##
## Framework: GdUnit4 v6
## Run: godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd
##      -a res://tests/integration/game-state-scene-flow/adr_0001_api_test.gd
##      --ignoreHeadlessMode
extends GdUnitTestSuite


# ── V-1: TileMapLayer exists and instantiates ─────────────────────────────────

func test_adr0001_tile_map_layer_instantiates_without_error() -> void:
	# Arrange / Act
	var tml := TileMapLayer.new()

	# Assert
	assert_object(tml).is_not_null()
	assert_bool(is_instance_valid(tml)).is_true()
	tml.free()


# ── V-2: TILE_SHAPE_ISOMETRIC constant value ──────────────────────────────────

func test_adr0001_tile_shape_isometric_constant_is_one() -> void:
	# Godot 4.x TileSet.TileShape enum:
	#   TILE_SHAPE_SQUARE = 0, TILE_SHAPE_ISOMETRIC = 1
	assert_int(TileSet.TILE_SHAPE_ISOMETRIC).is_equal(1)


func test_adr0001_tile_shape_isometric_differs_from_square() -> void:
	assert_bool(
		TileSet.TILE_SHAPE_ISOMETRIC != TileSet.TILE_SHAPE_SQUARE
	).is_true()


# ── V-3: TileSet.tile_shape read/write ────────────────────────────────────────

func test_adr0001_tile_set_tile_shape_can_be_set_to_isometric() -> void:
	# Arrange
	var ts := TileSet.new()

	# Act
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC

	# Assert
	assert_int(ts.tile_shape).is_equal(TileSet.TILE_SHAPE_ISOMETRIC)


# ── V-4: TileSet.tile_size 64×32 ─────────────────────────────────────────────

func test_adr0001_tile_set_tile_size_can_be_set_to_64x32() -> void:
	# Arrange
	var ts := TileSet.new()

	# Act
	ts.tile_size = Vector2i(64, 32)

	# Assert — width and height checked separately to get precise failure messages
	assert_int(ts.tile_size.x).is_equal(64)
	assert_int(ts.tile_size.y).is_equal(32)


# ── V-5: TileMapLayer accepts isometric TileSet ───────────────────────────────

func test_adr0001_tile_map_layer_accepts_isometric_tileset_assignment() -> void:
	# Arrange
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_size = Vector2i(64, 32)
	var tml := TileMapLayer.new()

	# Act
	tml.tile_set = ts

	# Assert — TileSet is assigned and shape/size survive the assignment
	assert_object(tml.tile_set).is_not_null()
	assert_int(tml.tile_set.tile_shape).is_equal(TileSet.TILE_SHAPE_ISOMETRIC)
	assert_int(tml.tile_set.tile_size.x).is_equal(64)
	assert_int(tml.tile_set.tile_size.y).is_equal(32)
	tml.free()


# ── V-6: Node2D.y_sort_enabled property ──────────────────────────────────────

func test_adr0001_node2d_y_sort_enabled_can_be_set_true() -> void:
	# Arrange
	var node := Node2D.new()

	# Act
	node.y_sort_enabled = true

	# Assert
	assert_bool(node.y_sort_enabled).is_true()
	node.free()


func test_adr0001_node2d_y_sort_enabled_default_is_false() -> void:
	# Default state — y_sort_enabled must be opt-in, not on by default
	var node := Node2D.new()
	assert_bool(node.y_sort_enabled).is_false()
	node.free()


# ── V-7: Class name confirms TileMapLayer (not deprecated TileMap) ────────────

func test_adr0001_tile_map_layer_class_name_is_tile_map_layer() -> void:
	var tml := TileMapLayer.new()
	assert_str(tml.get_class()).is_equal("TileMapLayer")
	tml.free()
