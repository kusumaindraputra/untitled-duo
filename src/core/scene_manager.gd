## SceneManager — Autoload #4. Owns room-to-room sub-scene swaps.
##
## Contract (ADR-0002, ADR-0005):
##   - Registered as Autoload position 4 in Project Settings (ADR-0002).
##   - No class_name — Godot 4 parse error when class_name matches Autoload node name.
##   - change_room() swaps the active sub-scene under SubSceneRoot on main.tscn.
##   - await get_tree().process_frame between queue_free() and add_child() — TR-GSF-003.
##   - Re-entrancy guard rejects nested change_room() calls with push_error() (TR-GSF-003).
##   - CanvasLayer (layer 10) on main.tscn is never touched — persists across all swaps (ADR-0005).
##
## Forbidden: Never use change_scene_to_file() — destroys main scene root and loses HUD (ADR-0005).
##
## Registration: Autoload #4 in Project Settings → AutoLoad (ADR-0002).
## No class_name — Godot 4 parse error when class_name matches Autoload node name.
## Access in game code: SceneManager.change_room(scene) (via Autoload path, not class_name).
extends Node

# ── Signals ───────────────────────────────────────────────────────────────────

## Emitted after the new scene is added to the tree and before this function returns.
## [param new_scene] is the newly instantiated and added scene root node.
signal room_changed(new_scene: Node)

# ── Private state ─────────────────────────────────────────────────────────────

## The currently active sub-scene, or null if no room has been loaded yet.
var _current_scene: Node = null

## True while a swap is in progress — guards against re-entrant change_room() calls.
var _is_swapping: bool = false

## Cached reference to the SubSceneRoot node on main.tscn.
## Resolved in _ready() via the scene tree path. If main.tscn is not the root
## (e.g. in integration tests), callers must set this before calling change_room().
var _sub_scene_root: Node2D = null

# ── Built-in ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	GameStateManager.state_changed.connect(_on_state_changed)

# ── Public API ────────────────────────────────────────────────────────────────

## Returns the currently active sub-scene, or null if no room has been loaded.
func get_current_scene() -> Node:
	return _current_scene


## Registers [param scene] as the initial room that already exists in the launch scene.
## Call once from debug_game_loop._ready() so the first change_room() correctly
## frees the bootstrapped room instead of leaving a duplicate under SubSceneRoot.
##
## Also caches [param scene]'s parent as the SubSceneRoot for future swaps. This
## decouples change_room() from the launch scene's root node name — main.tscn uses
## "main", demo.tscn uses "demo", and integration tests use throwaway roots; all
## work because the initial room is always a direct child of SubSceneRoot.
func set_initial_scene(scene: Node) -> void:
	_current_scene = scene
	if scene != null:
		var parent: Node = scene.get_parent()
		if parent is Node2D:
			_sub_scene_root = parent as Node2D


## Swaps the active sub-scene to a new instantiation of [param packed_scene].
##
## Performs the swap in three steps:
## 1. queue_free() the old scene (if any).
## 2. await get_tree().process_frame — ensures old scene is fully removed (TR-GSF-003).
## 3. instantiate(), optionally configure via [param pre_configure], then add_child().
##
## [param pre_configure] Optional Callable(Node) called after instantiate() but before
## add_child() (before _ready()). Use to set @export properties that must be live
## when _ready() fires — e.g. setting room_template on IsometricRoom.
##
## Re-entrancy guard: if called while a swap is already in progress, logs a
## push_error() and returns immediately — the in-progress swap is not interrupted.
##
## [param packed_scene] must be a valid PackedScene. Null is not accepted.
func change_room(packed_scene: PackedScene, pre_configure: Callable = Callable()) -> void:
	if _is_swapping:
		push_error("[SceneManager] change_room() called while swap in progress — rejected")
		return
	# Lazy init — Autoload _ready() fires before the launch scene loads; resolve on
	# first use. Prefer the active scene's SubSceneRoot (works for any root node name),
	# then fall back to the legacy /root/main path.
	if _sub_scene_root == null:
		var root_scene: Node = get_tree().current_scene
		if root_scene != null:
			_sub_scene_root = root_scene.get_node_or_null("SubSceneRoot") as Node2D
		if _sub_scene_root == null:
			_sub_scene_root = get_node_or_null("/root/main/SubSceneRoot") as Node2D
		if _sub_scene_root == null:
			push_error("[SceneManager] SubSceneRoot not found in active scene or /root/main — is a launch scene loaded?")
			return
	_is_swapping = true

	if _current_scene != null:
		_current_scene.queue_free()
		_current_scene = null
		await get_tree().process_frame  # TR-GSF-003: frame boundary between free and add

	var new_scene: Node = packed_scene.instantiate()
	if new_scene == null:
		push_error("[SceneManager] PackedScene.instantiate() returned null — swap aborted")
		_is_swapping = false
		return

	if pre_configure.is_valid():
		pre_configure.call(new_scene)

	_sub_scene_root.add_child(new_scene)

	_current_scene = new_scene
	_is_swapping = false
	room_changed.emit(new_scene)

# ── Signal callbacks ──────────────────────────────────────────────────────────

## Reacts to GameStateManager state transitions (ADR-0003).
## Drives room loads reactively — SceneManager does not poll state.
func _on_state_changed(_old_state: int, _new_state: int) -> void:
	# Room load logic will be wired here as scenes are implemented.
	# For now this is a stub that fulfils the connection contract (TR-GSF-004).
	pass
