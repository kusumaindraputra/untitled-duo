## RoomTransitionManager — orchestrates room-to-room transitions in a procedural dungeon (LD-20).
##
## Receives the DungeonGraph from DungeonGenerator.layer_generated, tracks which room
## the player is in, and drives SceneManager.change_room() when the player enters a door.
##
## Lives as a child node of main.tscn (not an Autoload) — add to the scene tree and call
## setup() after DungeonGenerator emits layer_generated.
##
## Scene integration is async (await SceneManager.room_changed, await Tween).
## Unit tests cover pure state methods only; the async transition is covered by manual QA.
##
## Usage:
##   var gen := DungeonGenerator.new()
##   gen.layer_generated.connect(_rtm.setup)
##   gen.generate(7, 1)
##
## GDD:     design/room-connection-model.md (LD-09), design/level-design-roadmap.md (LD-20)
## Depends: DungeonGraph (LD-16), DungeonGenerator (LD-19), SceneManager (Autoload #4)
class_name RoomTransitionManager
extends Node

## Emitted after the new room scene is ready and exit doors are wired.
signal room_transition_completed(new_room_idx: int)

## Duration in seconds for each fade half (out + in).
const FADE_DURATION_SEC: float = 0.4

var _graph: DungeonGraph = null
## Floor identity handed to every room this manager loads (ADR-0020). Set by the
## game loop before setup() / load_floor(). null = floor 1 look.
var floor_theme: FloorTheme = null
var _current_idx: int = -1
var _is_transitioning: bool = false
var _fade_rect: ColorRect = null


func _ready() -> void:
	_setup_fade_overlay()


# ── Public API ─────────────────────────────────────────────────────────────────

## Stores [param graph] and sets the starting room to the entry room.
## Call after receiving DungeonGenerator.layer_generated.
## Does NOT trigger any scene load — caller must call change_room() for the first room.
func setup(graph: DungeonGraph) -> void:
	_graph = graph
	_current_idx = graph.get_entry_room()


## Returns the DungeonGraph provided to setup(), or null if setup() has not been called.
func get_graph() -> DungeonGraph:
	return _graph


## Returns the current room index within the graph, or -1 if setup() has not been called.
func get_current_room_idx() -> int:
	return _current_idx


## Returns true while a scene swap + fade is in progress.
func is_transitioning() -> bool:
	return _is_transitioning


## Triggers a transition from the current room to [param destination_idx].
##
## Sequence: fade-out → SceneManager.change_room() → wire doors → fade-in.
## Re-entrant calls are ignored while a transition is in progress.
## Marks the current room CLEARED and the destination VISITED in the graph.
func request_transition(destination_idx: int) -> void:
	if _is_transitioning or _graph == null:
		return
	if destination_idx < 0 or destination_idx >= _graph.room_count():
		push_warning(
			"RoomTransitionManager.request_transition: destination_idx %d out of bounds."
				% destination_idx
		)
		return
	_is_transitioning = true
	_graph.set_room_state(_current_idx, DungeonGraph.ROOM_STATE_CLEARED)

	await _fade_to(1.0)

	var room: Dictionary = _graph.get_room(destination_idx)
	var tmpl: RoomTemplate = room.get("template", null) as RoomTemplate
	var packed: PackedScene = _resolve_packed_scene(tmpl)
	if packed == null:
		push_error("RoomTransitionManager: could not resolve PackedScene for room %d." % destination_idx)
		_is_transitioning = false
		return

	var captured_tmpl: RoomTemplate = tmpl
	var captured_theme: FloorTheme = floor_theme
	SceneManager.change_room(packed, func(scene: Node) -> void:
		if scene is IsometricRoom:
			if captured_tmpl != null:
				(scene as IsometricRoom).room_template = captured_tmpl
			(scene as IsometricRoom).floor_theme = captured_theme
	)
	await SceneManager.room_changed

	_current_idx = destination_idx
	_graph.set_room_state(_current_idx, DungeonGraph.ROOM_STATE_VISITED)
	_wire_exit_doors(SceneManager.get_current_scene())

	await _fade_to(0.0)

	_is_transitioning = false
	room_transition_completed.emit(_current_idx)


## Wires RoomExitDoor children of [param room_scene] to the outgoing edges
## from [param _current_idx] in the graph.
##
## Doors are matched to outgoing edges in order. Extra doors (if scene has more
## than outgoing edges) are hidden; missing doors (fewer than edges) are warned.
func wire_exit_doors(room_scene: Node) -> void:
	_wire_exit_doors(room_scene)


## Replaces the current dungeon floor with [param graph] and loads its entry room.
##
## Sequence: fade-out → SceneManager.change_room(entry) → wire doors → fade-in.
## Re-entrant calls while a transition is in progress are silently ignored.
## The caller need not await — connect to [signal room_transition_completed] for completion.
##
## Usage (from floor orchestrator):
##   rtm.load_floor(new_graph)
##   # _on_room_transitioned fires via room_transition_completed when ready
func load_floor(graph: DungeonGraph) -> void:
	if _is_transitioning or graph == null:
		return
	_is_transitioning = true
	_graph = graph
	_current_idx = _graph.get_entry_room()

	await _fade_to(1.0)

	var entry: Dictionary = _graph.get_room(_current_idx)
	var tmpl: RoomTemplate = entry.get("template", null) as RoomTemplate
	var packed: PackedScene = _resolve_packed_scene(tmpl)
	if packed == null:
		push_error("RoomTransitionManager.load_floor: could not resolve PackedScene for entry room.")
		_is_transitioning = false
		return

	var captured_tmpl: RoomTemplate = tmpl
	var captured_theme: FloorTheme = floor_theme
	SceneManager.change_room(packed, func(scene: Node) -> void:
		if scene is IsometricRoom:
			if captured_tmpl != null:
				(scene as IsometricRoom).room_template = captured_tmpl
			(scene as IsometricRoom).floor_theme = captured_theme
	)
	await SceneManager.room_changed

	_graph.set_room_state(_current_idx, DungeonGraph.ROOM_STATE_VISITED)
	_wire_exit_doors(SceneManager.get_current_scene())

	await _fade_to(0.0)

	_is_transitioning = false
	room_transition_completed.emit(_current_idx)


# ── Private ────────────────────────────────────────────────────────────────────

func _wire_exit_doors(room_scene: Node) -> void:
	if room_scene == null or _graph == null:
		return
	var outgoing: Array[int] = _graph.get_outgoing(_current_idx)
	var doors: Array[Node] = _collect_exit_doors(room_scene)

	for i: int in range(doors.size()):
		var door: RoomExitDoor = doors[i] as RoomExitDoor
		if i < outgoing.size():
			door.destination_idx = outgoing[i]
			var dest_room: Dictionary = _graph.get_room(outgoing[i])
			door.set_destination_type(int(dest_room.get("type", DungeonGraph.ROOM_TYPE_COMBAT)))
			if not door.player_entered.is_connected(request_transition):
				door.player_entered.connect(request_transition)
			door.show()
		else:
			door.hide()   # more doors in scene than graph edges

	if outgoing.size() > doors.size():
		push_warning(
			"RoomTransitionManager: room %d has %d outgoing edges but only %d doors in scene."
				% [_current_idx, outgoing.size(), doors.size()]
		)


func _collect_exit_doors(room_scene: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in room_scene.get_children():
		if child is RoomExitDoor:
			result.append(child)
	return result


## Returns the PackedScene for [param tmpl]. Placeholder until TemplateRoom (LD-15)
## exposes a factory method. Currently returns the default IsometricRoom scene for all templates.
func _resolve_packed_scene(_tmpl: RoomTemplate) -> PackedScene:
	return load("res://src/scenes/IsometricRoom.tscn") as PackedScene


func _setup_fade_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.anchor_right = 1.0
	_fade_rect.anchor_bottom = 1.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_fade_rect)
	add_child(canvas)


func _fade_to(target_alpha: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "color:a", target_alpha, FADE_DURATION_SEC)
	await tween.finished
