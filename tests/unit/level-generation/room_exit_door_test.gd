## room_exit_door_test.gd — Unit tests for RoomExitDoor (LD-20 exit trigger).
##
## Coverage:
##   - _PLAYER_LAYER constant matches PlayerController.COLLISION_LAYER_PLAYER = 2
##     (regression: collision_mask was 1 by default; player on layer 2 → body_entered never fired)
##   - _ready() sets collision_mask = _PLAYER_LAYER and monitoring = false
##   - _on_room_cleared() sets monitoring = true
##   - destination_idx defaults to -1
##   - set_destination_type stores value
##
## Note: _ready() is called manually — @onready var _label stays null (safe; _ready() doesn't use it).
## Node teardown: .free() for nodes not in scene tree (GdUnit4 headless rule).
extends GdUnitTestSuite


var _door: RoomExitDoor


func before_test() -> void:
	_door = RoomExitDoor.new()


func after_test() -> void:
	_door.free()


# ── test_01: _PLAYER_LAYER constant = 2 ──────────────────────────────────────
## Regression: collision_mask was 1 (default Area2D); player lives on layer 2.
## body_entered never fired → game stuck in COMBAT_PHASE after all enemies died.

func test_room_exit_door_player_layer_constant_is_two() -> void:
	assert_int(RoomExitDoor._PLAYER_LAYER).is_equal(2)


# ── test_02: _ready() sets collision_mask to player layer ────────────────────

func test_room_exit_door_ready_sets_collision_mask_to_player_layer() -> void:
	_door._ready()
	assert_int(_door.collision_mask).is_equal(RoomExitDoor._PLAYER_LAYER)


# ── test_03: door starts locked after _ready() ───────────────────────────────

func test_room_exit_door_starts_locked_monitoring_false() -> void:
	_door._ready()
	assert_bool(_door.monitoring).is_false()


# ── test_04: room_cleared unlocks door ───────────────────────────────────────

func test_room_exit_door_unlocks_on_room_cleared() -> void:
	_door._on_room_cleared()
	assert_bool(_door.monitoring).is_true()


# ── test_05: destination_idx defaults to -1 ──────────────────────────────────

func test_room_exit_door_default_destination_idx_is_minus_one() -> void:
	assert_int(_door.destination_idx).is_equal(-1)


# ── test_06: set_destination_type stores value ───────────────────────────────

func test_room_exit_door_set_destination_type_stores_value() -> void:
	_door.set_destination_type(DungeonGraph.ROOM_TYPE_BOSS)
	assert_int(_door.destination_type).is_equal(DungeonGraph.ROOM_TYPE_BOSS)
