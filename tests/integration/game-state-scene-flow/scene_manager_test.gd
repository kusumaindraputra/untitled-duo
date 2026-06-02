## scene_manager_test.gd — Integration tests for SceneManager Autoload (Story 002).
##
## Coverage:
##   AC-1:  SceneManager Autoload node is present in the scene tree at /root/SceneManager
##   AC-2:  change_room() loads scene as child of the injected sub-scene root
##   AC-3:  get_current_scene() returns a non-null node inside the tree after load
##   AC-4:  get_current_scene() returns null before any room is loaded
##   AC-5:  change_room() removes old scene and adds new scene; count remains 1
##   AC-6:  Old scene is freed (not in tree) after swap
##   AC-7:  CanvasLayer remains in the tree before and after a room swap (TR-GSF-004)
##   AC-8:  CanvasLayer is the same instance before and after a room swap
##   AC-9:  Re-entrancy guard: second change_room() call while swapping is rejected
##   AC-10: _is_swapping is false after change_room() completes
##   AC-11: room_changed signal is emitted with a non-null node after swap
##   AC-12: SceneManager._on_state_changed is connected to GameStateManager.state_changed
##
## Integration test strategy:
##   SceneManager is an Autoload — we test the live Autoload instance at /root/SceneManager.
##   To avoid mutating the Autoload's real _sub_scene_root (which points into main.tscn when
##   running under the full project), each test injects a fresh Node2D (_fake_sub_root) into
##   the Autoload before calling change_room(). A fake CanvasLayer (_fake_canvas) is added
##   as a sibling child of the test suite to stand in for the persistent HUD.
##   After each test, _current_scene and _sub_scene_root are restored to null so tests are
##   isolated.
##
## NOTE on GdUnit4 v6 lifecycle naming: use before_test() / after_test(), NOT before_each()
##   / after_each(). GdUnit4 v6 only recognises the _test variants; before_each() is silently
##   ignored, causing all instance variables to remain null during test execution.
##
## Framework: GdUnit4 v6
## Run: godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd
##      -a res://tests/integration/game-state-scene-flow/ --ignoreHeadlessMode
extends GdUnitTestSuite

const SCENE_A_PATH := "res://tests/integration/game-state-scene-flow/fixtures/TestSceneA.tscn"
const SCENE_B_PATH := "res://tests/integration/game-state-scene-flow/fixtures/TestSceneB.tscn"

## Live Autoload instance under test.
## Assigned in before_test() via the Autoload global singleton. In GdUnit4 v6,
## get_node_or_null("/root/SceneManager") can return null from the test execution
## context; the Autoload global name resolves correctly in all contexts.
var _sm: Node = null

## Fake sub-scene root injected into SceneManager before each test.
## Freed in after_test().
var _fake_sub_root: Node2D = null

## Fake CanvasLayer added as a sibling of SceneManager to stand in for the
## persistent HUD node. Freed in after_test().
var _fake_canvas: CanvasLayer = null

## Packed scenes, pre-loaded each test via load().
var _scene_a: PackedScene = null
var _scene_b: PackedScene = null

# ── Per-test lifecycle (GdUnit4 v6: before_test / after_test) ─────────────────

## GdUnit4 v6 per-test setup hook. Named before_test() — GdUnit4 does not
## recognise before_each(); that name is silently ignored.
func before_test() -> void:
	# Access the live Autoload via the scene tree path. The bare global singleton
	# name (SceneManager) resolves to null inside GdUnit4 v6 lifecycle hooks;
	# get_node() on the absolute path is reliable from any Node context.
	_sm = get_node("/root/SceneManager")

	# Load fixture scenes fresh each test.
	_scene_a = load(SCENE_A_PATH) as PackedScene
	_scene_b = load(SCENE_B_PATH) as PackedScene

	# Create a fresh fake sub-scene root and add it to the tree so
	# SceneManager can call add_child() on it.
	_fake_sub_root = Node2D.new()
	add_child(_fake_sub_root)

	# Create a fake CanvasLayer to represent the persistent HUD node.
	_fake_canvas = CanvasLayer.new()
	_fake_canvas.layer = 10
	add_child(_fake_canvas)

	# Inject the fake root into the live Autoload and reset state.
	_sm._sub_scene_root = _fake_sub_root
	_sm._current_scene = null
	_sm._is_swapping = false
	TestEventLog.events.clear()


## GdUnit4 v6 per-test teardown hook. Named after_test() — GdUnit4 does not
## recognise after_each(); that name is silently ignored.
func after_test() -> void:
	# Restore SceneManager to a clean state so the Autoload is not polluted.
	# Clear references before freeing nodes to avoid dangling pointers.
	_sm._current_scene = null
	_sm._sub_scene_root = null
	_sm._is_swapping = false

	# Use free() (immediate) instead of queue_free() — GdUnit4's orphan monitor
	# runs synchronously after after_test() and will crash trying to cast
	# objects that are only queued for deletion (GdUnitOrphanNodesMonitor:202).
	if is_instance_valid(_fake_sub_root):
		remove_child(_fake_sub_root)
		_fake_sub_root.free()
	_fake_sub_root = null

	if is_instance_valid(_fake_canvas):
		remove_child(_fake_canvas)
		_fake_canvas.free()
	_fake_canvas = null

# ── AC-1: Autoload is present in the scene tree ───────────────────────────────

func test_scene_manager_is_in_scene_tree_as_autoload() -> void:
	# Arrange / Act — resolve via Autoload global name
	var node: Node = SceneManager

	# Assert — the Autoload singleton is a valid node in the tree
	assert_object(node).is_not_null()
	assert_bool(node.is_inside_tree()).is_true()


# ── AC-2: change_room() loads scene into sub-scene root ───────────────────────

func test_scene_manager_change_room_loads_scene_into_sub_scene_root() -> void:
	# Arrange — _fake_sub_root injected in before_test()

	# Act
	_sm.change_room(_scene_a)
	await get_tree().process_frame

	# Assert — exactly one child was added to the fake sub root
	assert_int(_fake_sub_root.get_child_count()).is_equal(1)


# ── AC-3: get_current_scene() is non-null and in tree after load ──────────────

func test_scene_manager_change_room_current_scene_is_set_after_load() -> void:
	# Arrange
	# Act
	_sm.change_room(_scene_a)
	await get_tree().process_frame

	# Assert
	assert_object(_sm.get_current_scene()).is_not_null()
	assert_bool(_sm.get_current_scene().is_inside_tree()).is_true()


# ── AC-4: get_current_scene() returns null initially ─────────────────────────

func test_scene_manager_get_current_scene_returns_null_initially() -> void:
	# Arrange — _current_scene was reset to null in before_test()

	# Act / Assert
	assert_object(_sm.get_current_scene()).is_null()


# ── AC-5: change_room() removes old scene and adds new; count stays 1 ─────────

func test_scene_manager_change_room_removes_old_scene_and_adds_new() -> void:
	# Arrange
	_sm.change_room(_scene_a)
	await get_tree().process_frame

	# Act — swap to scene B
	_sm.change_room(_scene_b)
	await get_tree().process_frame

	# Assert — only one child remains
	assert_int(_fake_sub_root.get_child_count()).is_equal(1)

	# The remaining child must be TestSceneB (name comes from the scene root node)
	var remaining: Node = _fake_sub_root.get_child(0)
	assert_str(remaining.name).is_equal("TestSceneB")


# ── AC-6: Old scene is freed (not a valid instance) after swap ────────────────

func test_scene_manager_old_scene_not_in_tree_after_swap() -> void:
	# Arrange
	_sm.change_room(_scene_a)
	await get_tree().process_frame
	var old_scene: Node = _sm.get_current_scene()

	# Act
	_sm.change_room(_scene_b)
	await get_tree().process_frame

	# Assert — queue_free() + process_frame means old_scene has been freed
	assert_bool(is_instance_valid(old_scene)).is_false()


# ── AC-7: CanvasLayer survives room swap ──────────────────────────────────────

func test_scene_manager_canvas_layer_survives_room_swap() -> void:
	# Arrange
	_sm.change_room(_scene_a)
	await get_tree().process_frame

	# Assert canvas is still in tree after first swap
	assert_bool(_fake_canvas.is_inside_tree()).is_true()

	# Act
	_sm.change_room(_scene_b)
	await get_tree().process_frame

	# Assert canvas is still in tree after second swap
	assert_bool(_fake_canvas.is_inside_tree()).is_true()


# ── AC-8: CanvasLayer is the same instance before and after swap ──────────────

func test_scene_manager_canvas_layer_same_instance_before_and_after_swap() -> void:
	# Arrange — record instance id before any swap
	var id_before: int = _fake_canvas.get_instance_id()

	# Act
	_sm.change_room(_scene_a)
	await get_tree().process_frame

	# Assert — same object, same id
	assert_int(_fake_canvas.get_instance_id()).is_equal(id_before)


# ── AC-9: Re-entrancy guard rejects call while swapping ──────────────────────

func test_scene_manager_change_room_rejects_call_while_swapping() -> void:
	# Arrange — manually set swapping flag to simulate in-progress swap
	_sm._is_swapping = true

	# Act
	_sm.change_room(_scene_a)

	# Assert — nothing was added; sub root still empty
	assert_int(_fake_sub_root.get_child_count()).is_equal(0)

	# Cleanup — reset flag so after_each() doesn't leave Autoload in bad state
	_sm._is_swapping = false


# ── AC-10: _is_swapping is false after change_room() completes ───────────────

func test_scene_manager_is_swapping_false_after_completion() -> void:
	# Arrange
	# Act
	_sm.change_room(_scene_a)
	await get_tree().process_frame

	# Assert
	assert_bool(_sm._is_swapping).is_false()


# ── AC-11: room_changed signal is emitted after swap ─────────────────────────

func test_scene_manager_room_changed_signal_emitted_after_swap() -> void:
	# Arrange — store the lambda so it can be disconnected precisely
	var received: Array[Node] = []
	var on_room_changed: Callable = func(scene: Node) -> void: received.append(scene)
	_sm.room_changed.connect(on_room_changed)

	# Act
	_sm.change_room(_scene_a)
	await get_tree().process_frame

	# Assert — signal fired exactly once with a non-null scene
	assert_int(received.size()).is_equal(1)
	assert_object(received[0]).is_not_null()

	# Cleanup — disconnect the stored callable to avoid signal accumulation across tests
	_sm.room_changed.disconnect(on_room_changed)


# ── AC-12: SceneManager connected to GameStateManager.state_changed ──────────

func test_scene_manager_connected_to_game_state_manager() -> void:
	# Arrange — access the live GameStateManager via its Autoload global name
	var gsm: Node = GameStateManager

	# Assert — the connection must exist
	assert_object(gsm).is_not_null()
	assert_bool(
		gsm.state_changed.is_connected(_sm._on_state_changed)
	).is_true()


# ── TR-GSF-003: exit_tree fires before ready on swap (frame-ordering) ────────

func test_scene_manager_exit_tree_fires_before_new_scene_ready_on_swap() -> void:
	# Arrange — load scene_a; TestEventLog records "TestSceneA:ready"
	await _sm.change_room(_scene_a)
	# Reset log so only the swap events are captured
	TestEventLog.events.clear()

	# Act — await the full swap; deferred free of scene_a runs before process_frame
	# resumes the coroutine, so exit_tree must precede ready in the log
	await _sm.change_room(_scene_b)

	# Assert — both events recorded in correct order
	var exit_idx: int = TestEventLog.events.find("TestSceneA:exit_tree")
	var ready_idx: int = TestEventLog.events.find("TestSceneB:ready")
	assert_bool(exit_idx >= 0).is_true()
	assert_bool(ready_idx >= 0).is_true()
	assert_bool(exit_idx < ready_idx).is_true()


# ── Async re-entrancy: second call rejected while first is suspended ──────────

func test_scene_manager_rejects_change_room_during_async_swap() -> void:
	# Arrange — load scene_a so _current_scene != null (triggers the await path)
	await _sm.change_room(_scene_a)

	# Act — start swap to scene_b WITHOUT awaiting; function suspends at
	# await get_tree().process_frame inside change_room, returning control here
	_sm.change_room(_scene_b)

	# _is_swapping is true while the first swap is suspended
	assert_bool(_sm._is_swapping).is_true()

	# Second call during the suspended window — must be rejected
	_sm.change_room(_scene_a)

	# Let the first swap complete
	await get_tree().process_frame

	# Assert — only scene_b was loaded; second call had no effect
	assert_int(_fake_sub_root.get_child_count()).is_equal(1)
	assert_str(_fake_sub_root.get_child(0).name).is_equal("TestSceneB")
	assert_bool(_sm._is_swapping).is_false()


# ── Mid-swap null window: get_current_scene() returns null during await ───────

func test_scene_manager_current_scene_null_during_swap_window() -> void:
	# Arrange — load scene_a so the swap will hit the await path
	await _sm.change_room(_scene_a)

	# Act — start swap to scene_b WITHOUT awaiting; function suspends after
	# queue_free() and _current_scene = null, before instantiate()
	_sm.change_room(_scene_b)

	# During the await window: _current_scene is null, swap is in progress
	assert_object(_sm.get_current_scene()).is_null()
	assert_bool(_sm._is_swapping).is_true()

	# Let the swap complete
	await get_tree().process_frame

	# After completion: current scene is set and swap flag cleared
	assert_object(_sm.get_current_scene()).is_not_null()
	assert_bool(_sm._is_swapping).is_false()
