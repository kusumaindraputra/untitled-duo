## DungeonGraph — directed acyclic graph representing room nodes and forward-branching
## connections for procedural dungeon generation.
##
## Pure data structure (RefCounted, no scene tree dependency). Built by PathBuilder
## (LD-17), consumed by RoomSelector (LD-18) and DungeonGenerator (LD-19).
##
## Rooms are indexed by auto-incrementing integer. Each room carries a type (Combat,
## Elite, Rest, BossGate), an optional RoomTemplate reference, and a traversal state
## (UNVISITED / VISITED / CLEARED).
##
## Edges are directed (from→to) and idempotent — connecting the same pair twice is
## a no-op. Reverse edges are distinct (one edge per direction).
##
## Usage:
##   var g := DungeonGraph.new()
##   var start: int = g.add_room(0)       # Combat = 0
##   var boss: int  = g.add_room(3)       # BossGate = 3
##   g.add_edge(start, boss)
##   assert(g.has_path(start, boss))
##
## GDD:     design/room-connection-model.md, design/room-type-taxonomy.md
## Roadmap: design/level-design-roadmap.md (LD-16)
class_name DungeonGraph
extends RefCounted


# ── Constants ──────────────────────────────────────────────────────────────────

const ROOM_STATE_UNVISITED: int = 0
const ROOM_STATE_VISITED:  int = 1
const ROOM_STATE_CLEARED:  int = 2

const ROOM_TYPE_COMBAT:  int = 0
const ROOM_TYPE_ELITE:   int = 1
const ROOM_TYPE_REST:    int = 2
const ROOM_TYPE_BOSS:    int = 3


# ── Internal state ─────────────────────────────────────────────────────────────

var _rooms: Array[Dictionary] = []   ## [{type: int, template: RoomTemplate?, state: int}, …]
var _edges: Array[Dictionary] = []   ## [{from: int, to: int}, …]


# ── Public API ─────────────────────────────────────────────────────────────────

## Appends a room of [param type] with optional [param template] reference.
## Returns the new room's index (0-based). Always succeeds.
func add_room(type: int, template: RoomTemplate = null) -> int:
	_rooms.append({
		"type": type,
		"template": template,
		"state": ROOM_STATE_UNVISITED,
	})
	return _rooms.size() - 1


## Creates a directed edge from [param from_idx] to [param to_idx].
## Idempotent: adding the same pair twice does not create a duplicate.
## Named add_edge (not connect) to avoid shadowing Object.connect().
func add_edge(from_idx: int, to_idx: int) -> void:
	if from_idx < 0 or from_idx >= _rooms.size():
		push_warning("DungeonGraph.add_edge: from_idx %d out of bounds." % from_idx)
		return
	if to_idx < 0 or to_idx >= _rooms.size():
		push_warning("DungeonGraph.add_edge: to_idx %d out of bounds." % to_idx)
		return
	for e: Dictionary in _edges:
		if int(e["from"]) == from_idx and int(e["to"]) == to_idx:
			return   # already connected
	_edges.append({"from": from_idx, "to": to_idx})


## Returns the room Dictionary at [param idx], or {} if out of bounds.
## Keys: type (int), template (RoomTemplate?), state (int).
func get_room(idx: int) -> Dictionary:
	if idx < 0 or idx >= _rooms.size():
		return {}
	return _rooms[idx]


## Sets the traversal state of room [param idx].
func set_room_state(idx: int, state: int) -> void:
	if idx < 0 or idx >= _rooms.size():
		push_warning("DungeonGraph.set_room_state: idx %d out of bounds." % idx)
		return
	_rooms[idx]["state"] = state


## Returns all room indices that [param idx] has an outgoing edge to.
func get_outgoing(idx: int) -> Array[int]:
	var result: Array[int] = []
	for e: Dictionary in _edges:
		if int(e["from"]) == idx:
			result.append(int(e["to"]))
	return result


## Returns all room indices that have an outgoing edge to [param idx].
func get_incoming(idx: int) -> Array[int]:
	var result: Array[int] = []
	for e: Dictionary in _edges:
		if int(e["to"]) == idx:
			result.append(int(e["from"]))
	return result


func room_count() -> int:
	return _rooms.size()


func edge_count() -> int:
	return _edges.size()


## Returns all room indices matching [param type] (Combat=0, Elite=1, Rest=2, Boss=3).
func get_rooms_by_type(type: int) -> Array[int]:
	var result: Array[int] = []
	for i: int in range(_rooms.size()):
		if int(_rooms[i]["type"]) == type:
			result.append(i)
	return result


## Returns the entry room index (room with no incoming edges).
## Returns -1 if the graph is empty.
func get_entry_room() -> int:
	if _rooms.is_empty():
		return -1
	var incoming: Dictionary = {}   # idx → count
	for e: Dictionary in _edges:
		var to_idx: int = int(e["to"])
		incoming[to_idx] = int(incoming.get(to_idx, 0)) + 1
	for i: int in range(_rooms.size()):
		if not incoming.has(i):
			return i
	return -1  # all rooms have incoming edges (should not happen in a DAG with ≥1 node)


## Returns all room indices with no outgoing edges.
func get_exit_rooms() -> Array[int]:
	var result: Array[int] = []
	for i: int in range(_rooms.size()):
		if get_outgoing(i).is_empty():
			result.append(i)
	return result


## BFS reachability: returns true if [param to_idx] is reachable from [param from_idx]
## along directed edges. Returns true when from_idx == to_idx (identity).
func has_path(from_idx: int, to_idx: int) -> bool:
	if from_idx == to_idx:
		return true
	if from_idx < 0 or from_idx >= _rooms.size():
		return false
	if to_idx < 0 or to_idx >= _rooms.size():
		return false
	var visited: Dictionary = {}
	var queue: Array[int] = [from_idx]
	while not queue.is_empty():
		var current: int = queue.pop_back()
		if visited.has(current):
			continue
		visited[current] = true
		for nb: int in get_outgoing(current):
			if nb == to_idx:
				return true
			if not visited.has(nb):
				queue.append(nb)
	return false


## Kahn's topological sort — returns true if the graph contains no cycle.
## Used by PathBuilder (LD-17) to validate the DAG invariant before consumption.
func is_acyclic() -> bool:
	if _rooms.is_empty():
		return true
	var in_degree: Dictionary = {}   # idx → count
	for i: int in range(_rooms.size()):
		in_degree[i] = 0
	for e: Dictionary in _edges:
		var to_idx: int = int(e["to"])
		in_degree[to_idx] = int(in_degree.get(to_idx, 0)) + 1
	var queue: Array[int] = []
	for i: int in range(_rooms.size()):
		if int(in_degree[i]) == 0:
			queue.append(i)
	var visited_count: int = 0
	while not queue.is_empty():
		var current: int = queue.pop_back()
		visited_count += 1
		for nb: int in get_outgoing(current):
			in_degree[nb] = int(in_degree[nb]) - 1
			if int(in_degree[nb]) == 0:
				queue.append(nb)
	return visited_count == _rooms.size()
