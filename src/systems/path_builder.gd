## PathBuilder — branching path algorithm for procedural dungeon generation.
##
## Generates a DungeonGraph with rooms typed and edges connected according to the
## forward-branching rules in the Room Connection Model.
##
## Pure algorithm (RefCounted, no scene dependency). Consumed by DungeonGenerator
## (LD-19); output is consumed by RoomSelector (LD-18) which assigns templates.
##
## Usage:
##   var pb := PathBuilder.new()
##   var graph: DungeonGraph = pb.generate(7, 1)
##   assert(graph.is_acyclic())
##   assert(PathBuilder.max_exits(graph) <= 3)
##   assert(PathBuilder.path_length_diff(graph) <= 1)
##
## GDD:     design/room-connection-model.md (LD-09)
##          design/room-type-taxonomy.md   (LD-06)
## Roadmap: design/level-design-roadmap.md (LD-17)
class_name PathBuilder
extends RefCounted


# ── Constants ──────────────────────────────────────────────────────────────────

## Minimum rooms per layer. Fewer than 5 would leave no room for pacing.
const MIN_ROOM_COUNT: int = 5


# ── Public API ─────────────────────────────────────────────────────────────────

## Generates a filled [DungeonGraph] following branching rules for [param room_count]
## rooms (5–8) on [param layer] (1 or 2). Returns null and push_warning on invalid input.
## Rooms are typed (Combat/Elite/Rest/Boss) but templates are null — RoomSelector (LD-18)
## assigns them later.
func generate(room_count: int, layer: int = 1) -> DungeonGraph:
	if room_count < MIN_ROOM_COUNT:
		push_warning("PathBuilder.generate: room_count %d < minimum %d." % [room_count, MIN_ROOM_COUNT])
		return null

	var g := DungeonGraph.new()

	# ── Room type counts (from room-type-taxonomy.md § Room Selector Algorithm) ──
	var remaining: int = room_count - 2   # minus Rest + Boss
	var elite_count: int = 1 if remaining >= 5 else 0
	var combat_count: int = remaining - elite_count

	# ── Phase 1: create all rooms ──────────────────────────────────────────────
	# Edges are deferred to Phase 2 so we never reference a room index that doesn't exist yet.

	if room_count <= 5:
		for _i: int in range(combat_count):
			g.add_room(DungeonGraph.ROOM_TYPE_COMBAT)
		g.add_room(DungeonGraph.ROOM_TYPE_REST)
		g.add_room(DungeonGraph.ROOM_TYPE_BOSS)
		_assert_room_count(g, room_count)
		_build_linear_edges(g)
	else:
		# Start + branch point.
		g.add_room(DungeonGraph.ROOM_TYPE_COMBAT)           # index 0
		g.add_room(DungeonGraph.ROOM_TYPE_COMBAT)           # index 1

		var after: int = combat_count + elite_count - 2    # rooms after start + branch
		var left_count: int = ceili(float(after) / 2.0)
		var right_count: int = after - left_count

		# Left path chain.
		var elite_placed: bool = false
		for i: int in range(left_count):
			var is_last_left: bool = (i == left_count - 1)
			var put_elite: bool = not elite_placed and elite_count > 0 and is_last_left and left_count >= right_count
			if put_elite:
				elite_placed = true
				g.add_room(DungeonGraph.ROOM_TYPE_ELITE)
			else:
				g.add_room(DungeonGraph.ROOM_TYPE_COMBAT)

		# Right path chain.
		for i: int in range(right_count):
			var is_last_right: bool = (i == right_count - 1)
			var put_elite: bool = not elite_placed and elite_count > 0 and is_last_right
			if put_elite:
				elite_placed = true
				g.add_room(DungeonGraph.ROOM_TYPE_ELITE)
			else:
				g.add_room(DungeonGraph.ROOM_TYPE_COMBAT)

		# Rest + Boss always last two.
		g.add_room(DungeonGraph.ROOM_TYPE_REST)
		g.add_room(DungeonGraph.ROOM_TYPE_BOSS)
		_assert_room_count(g, room_count)

		_build_branch_edges(g, left_count, right_count, room_count)

	return g


## Returns the maximum outgoing edge count from any room in [param graph].
## Used by tests to verify AC-CM-06 (max 3 exits — no analysis paralysis).
static func max_exits(graph: DungeonGraph) -> int:
	var m: int = 0
	for i: int in range(graph.room_count()):
		var out: int = graph.get_outgoing(i).size()
		if out > m:
			m = out
	return m


## Returns the hop-count difference between the longest and shortest path from the
## branch point to the Rest room. For linear graphs (no branch), returns 0.
## Used by tests to verify AC-CM-07 (diff ≤ 1).
static func path_length_diff(graph: DungeonGraph) -> int:
	if graph.room_count() == 0:
		return 0
	# Find branch point: room with >1 outgoing edge.
	var branch_idx: int = -1
	for i: int in range(graph.room_count()):
		if graph.get_outgoing(i).size() > 1:
			branch_idx = i
			break
	if branch_idx < 0:
		return 0   # linear — no branch
	# Find Rest room.
	var rests: Array[int] = graph.get_rooms_by_type(DungeonGraph.ROOM_TYPE_REST)
	if rests.is_empty():
		return 0
	var rest_idx: int = rests[0]
	# BFS from branch to Rest — collect all path lengths.
	var path_lengths: Array[int] = _collect_path_lengths(graph, branch_idx, rest_idx)
	if path_lengths.size() < 2:
		return 0
	var lo: int = path_lengths.min()
	var hi: int = path_lengths.max()
	return hi - lo


# ── Private edge builders ──────────────────────────────────────────────────────

## Linear chain edges: 0→1→2→...→(N-2)→(N-1).
func _build_linear_edges(g: DungeonGraph) -> void:
	for i: int in range(g.room_count() - 1):
		g.add_edge(i, i + 1)


## Branch edges with room_count >= 6.
##
## Room layout by index:
##   0: Combat (start)
##   1: Combat (branch point)
##   2 .. 2+left_count-1: left path
##   2+left_count .. rest_idx-1: right path
##   rest_idx (= room_count-2): Rest
##   boss_idx (= room_count-1): Boss
func _build_branch_edges(g: DungeonGraph, left_count: int, right_count: int, room_count: int) -> void:
	var left_start: int = 2
	var left_end: int = left_start + left_count - 1
	var right_start: int = left_end + 1
	var right_end: int = right_start + right_count - 1
	var rest_idx: int = room_count - 2
	var boss_idx: int = room_count - 1

	# start → branch
	g.add_edge(0, 1)

	# left path chain
	g.add_edge(1, left_start)
	for i: int in range(left_start, left_end):
		g.add_edge(i, i + 1)
	g.add_edge(left_end, rest_idx)

	# right path chain
	g.add_edge(1, right_start)
	for i: int in range(right_start, right_end):
		g.add_edge(i, i + 1)
	g.add_edge(right_end, rest_idx)

	# Rest → Boss
	g.add_edge(rest_idx, boss_idx)


# ── Private helpers ────────────────────────────────────────────────────────────

func _assert_room_count(g: DungeonGraph, expected: int) -> void:
	var actual: int = g.room_count()
	if actual != expected:
		push_warning("PathBuilder: expected %d rooms, got %d." % [expected, actual])


## BFS from [param start] to [param target]: collects all distinct path lengths
## (edge-count distance) found to the target.
static func _collect_path_lengths(graph: DungeonGraph, start: int, target: int) -> Array[int]:
	var results: Array[int] = []
	var queue: Array[Dictionary] = [{"node": start, "dist": 0}]
	var visited: Dictionary = {}   # node → min_dist
	while not queue.is_empty():
		var entry: Dictionary = queue.pop_back()
		var node: int = int(entry["node"])
		var dist: int = int(entry["dist"])
		if visited.has(node) and int(visited[node]) <= dist:
			continue   # already visited at same or shorter distance
		visited[node] = dist
		if node == target:
			results.append(dist)
			continue   # don't traverse beyond target
		for nb: int in graph.get_outgoing(node):
			queue.append({"node": nb, "dist": dist + 1})
	return results
