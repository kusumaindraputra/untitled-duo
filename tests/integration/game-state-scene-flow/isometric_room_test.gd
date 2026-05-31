## isometric_room_test.gd — Integration tests for IsometricRoom Scene Root (Story 003).
##
## Coverage:
##   AC-2a: Root node is Node2D with y_sort_enabled = true
##   AC-2b: Root script is attached (IsometricRoom instance)
##   AC-2c: EntityLayer Node2D has y_sort_enabled = true
##   AC-3a: Scene contains a TileMapLayer child node
##   AC-3b: TileMapLayer tile_set has tile_shape == TileSet.TILE_SHAPE_ISOMETRIC
##   AC-3c: TileMapLayer tile_set has tile_size == Vector2i(64, 32)
##   AC-4a: Scene contains a SpawnMarkers Node2D child
##   AC-4b: get_spawn_markers() returns an Array[Vector2]
##   AC-5a: get_spawn_markers() returns at least 3 positions
##   AC-5b: All returned positions are non-zero (not Vector2.ZERO)
##   AC-6:  IsometricRoom loads correctly via SceneManager.change_room() without null errors
##   AC-8:  IsometricRoom is NOT registered as an Autoload (no /root/IsometricRoom node)
##
## AC-7 (visual y-sort draw-order correctness) is ADVISORY/manual — not covered here.
## Evidence will be captured at production/qa/evidence/isometric-room-ysort-evidence.md
## when Story 003 is verified in /story-done.
##
## NOTE on GdUnit4 v6 lifecycle naming: use before_test() / after_test(), NOT before_each()
##   / after_each(). GdUnit4 v6 only recognises the _test variants; before_each() is silently
##   ignored, causing all instance variables to remain null during test execution.
##
## Framework: GdUnit4 v6
## Run: godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd
##      -a res://tests/integration/game-state-scene-flow/isometric_room_test.gd
##      --ignoreHeadlessMode
extends GdUnitTestSuite

const SCENE_PATH := "res://src/scenes/IsometricRoom.tscn"

## Packed scene loaded once per test.
var _scene: PackedScene = null

## Live IsometricRoom instance added to the tree for each test.
var _room: Node2D = null

# ── Per-test lifecycle ────────────────────────────────────────────────────────

func before_test() -> void:
	_scene = load(SCENE_PATH) as PackedScene
	_room = _scene.instantiate() as Node2D
	add_child(_room)
	await get_tree().process_frame


func after_test() -> void:
	if is_instance_valid(_room):
		_room.queue_free()
		_room = null
	await get_tree().process_frame


# ── AC-2a: Root is Node2D with y_sort_enabled = true ─────────────────────────

func test_isometric_room_root_is_node2d_with_y_sort_enabled() -> void:
	# Assert root type
	assert_str(_room.get_class()).is_equal("Node2D")
	# Assert y_sort_enabled is explicitly set on the root
	assert_bool(_room.y_sort_enabled).is_true()


# ── AC-2b: Root script is attached (is IsometricRoom) ────────────────────────

func test_isometric_room_root_script_is_attached() -> void:
	# The script defines class_name IsometricRoom — type check confirms it loaded
	assert_bool(_room is IsometricRoom).is_true()


# ── AC-2c: EntityLayer Node2D has y_sort_enabled = true ──────────────────────

func test_isometric_room_entity_layer_has_y_sort_enabled() -> void:
	var entity_layer: Node = _room.get_node_or_null("EntityLayer")
	assert_object(entity_layer).is_not_null()
	assert_str(entity_layer.get_class()).is_equal("Node2D")
	assert_bool((entity_layer as Node2D).y_sort_enabled).is_true()


# ── AC-3a: Scene contains a TileMapLayer child ───────────────────────────────

func test_isometric_room_contains_tile_map_layer_child() -> void:
	var tml: Node = _room.get_node_or_null("TileMapLayer")
	assert_object(tml).is_not_null()
	assert_str(tml.get_class()).is_equal("TileMapLayer")


# ── AC-3b: TileMapLayer tile_shape is TILE_SHAPE_ISOMETRIC ───────────────────

func test_isometric_room_tile_map_layer_shape_is_isometric() -> void:
	var tml := _room.get_node("TileMapLayer") as TileMapLayer
	assert_object(tml.tile_set).is_not_null()
	assert_int(tml.tile_set.tile_shape).is_equal(TileSet.TILE_SHAPE_ISOMETRIC)


# ── AC-3c: TileMapLayer tile_size is Vector2i(64, 32) ────────────────────────

func test_isometric_room_tile_map_layer_tile_size_is_64x32() -> void:
	var tml := _room.get_node("TileMapLayer") as TileMapLayer
	assert_object(tml.tile_set).is_not_null()
	assert_int(tml.tile_set.tile_size.x).is_equal(64)
	assert_int(tml.tile_set.tile_size.y).is_equal(32)


# ── AC-4a: Scene contains a SpawnMarkers Node2D child ────────────────────────

func test_isometric_room_contains_spawn_markers_node() -> void:
	var sm: Node = _room.get_node_or_null("SpawnMarkers")
	assert_object(sm).is_not_null()
	assert_str(sm.get_class()).is_equal("Node2D")


# ── AC-4b: get_spawn_markers() returns an Array[Vector2] ─────────────────────

func test_isometric_room_get_spawn_markers_returns_array() -> void:
	var room := _room as IsometricRoom
	var result: Array[Vector2] = room.get_spawn_markers()
	assert_object(result).is_not_null()
	assert_bool(result.size() > 0).is_true()


# ── AC-5a: get_spawn_markers() returns at least 3 positions ──────────────────

func test_isometric_room_get_spawn_markers_returns_at_least_three() -> void:
	var room := _room as IsometricRoom
	var result: Array[Vector2] = room.get_spawn_markers()
	assert_bool(result.size() >= 3).is_true()


# ── AC-5b: All returned positions are non-zero ───────────────────────────────

func test_isometric_room_spawn_markers_all_non_zero() -> void:
	var room := _room as IsometricRoom
	var result: Array[Vector2] = room.get_spawn_markers()
	for pos: Vector2 in result:
		# At least one component must be non-zero
		assert_bool(pos.x != 0.0 or pos.y != 0.0).is_true()


# ── AC-6: Loads via SceneManager.change_room() without null errors ────────────

func test_isometric_room_loads_via_scene_manager_without_errors() -> void:
	# Arrange — free the auto-instantiated room from before_test();
	# we will load a fresh one through SceneManager instead.
	if is_instance_valid(_room):
		_room.queue_free()
		_room = null
	await get_tree().process_frame

	var sm: Node = get_node("/root/SceneManager")
	var fake_root := Node2D.new()
	add_child(fake_root)

	# Inject fake sub-scene root and reset SceneManager state.
	sm._sub_scene_root = fake_root
	sm._current_scene = null
	sm._is_swapping = false

	# Act
	sm.change_room(_scene)
	await get_tree().process_frame

	# Assert — exactly one child loaded, it is in the tree
	assert_int(fake_root.get_child_count()).is_equal(1)
	var loaded: Node = fake_root.get_child(0)
	assert_object(loaded).is_not_null()
	assert_bool(loaded.is_inside_tree()).is_true()

	# Cleanup — restore SceneManager to clean state
	sm._current_scene = null
	sm._sub_scene_root = null
	sm._is_swapping = false
	fake_root.queue_free()
	await get_tree().process_frame


# ── AC-8: IsometricRoom is NOT registered as an Autoload ─────────────────────

func test_isometric_room_not_registered_as_autoload() -> void:
	# Autoloads are reachable at /root/<AutoloadName>.
	# IsometricRoom is a scene node — no Autoload entry must exist.
	var autoload_node: Node = get_node_or_null("/root/IsometricRoom")
	assert_object(autoload_node).is_null()
