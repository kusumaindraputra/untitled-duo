## IsometricRoom — root script for dungeon room scenes.
##
## Implements the IsometricRoom node (ADR-0001: Isometric 2D View).
## This scene is loaded and unloaded by SceneManager.change_room() (ADR-0002,
## ADR-0005). It is NOT an Autoload — its lifetime is bound to the arena scene.
##
## Contracts:
##   ADR-0001: Root Node2D has y_sort_enabled = true; TileMapLayer uses
##             TileSet.TILE_SHAPE_ISOMETRIC with tile size Vector2i(64, 32).
##   ADR-0002: IsometricRoom is a scene node, not an Autoload.
##   ADR-0005: Lives under SubSceneRoot on main.tscn; freed on room transition.
##
## get_spawn_markers() is consumed by WaveManager (Enemy AI epic) to place
## enemy spawns. Returns global positions of all Marker2D children under
## the SpawnMarkers node.
class_name IsometricRoom
extends Node2D

const _FLOOR_SOURCE_ID: int = 0
## Scan radius. Must be >= max(x_radius, y_radius) = max(20, 24).
const _FLOOR_RADIUS: int = 26
## Arena diamond half-extents in screen pixels.
## Full diamond 1280×768 game-px. At combat zoom 2.0×: visible 576×324 — Fayde (~64px)
## occupies ~15% of height, matching Hades character-to-room scale ratio.
## At prep zoom 0.55×: full arena visible with ~400px border.
## x_radius = 640/32 = 20 tiles wide, y_radius = 384/16 = 24 tiles deep.
const _WALL_HALF_X: int = 640
const _WALL_HALF_Y: int = 384
## Screen pixels per tile isometric axis unit (tile_size = 64x32 → half = 32x16).
const _TILE_X_STEP: int = 32
const _TILE_Y_STEP: int = 16
## Half-cover debris: blocks movement, not Prana/projectiles (S9-09, design/quick-specs/arena-cover-types.md).
const _HALF_COVER_LAYER: int = 16  # bit 4 — Layer 5 in Godot physics layer UI
const _DEBRIS_RADIUS: float = 22.0
const _DEBRIS_NAV_RADIUS: float = 28.0
## Random obstacle placement — tuning knobs from design/gdd/level-generation.md.
## Deprecated: prefer obstacle_config resource (LD-02). Kept for test backward compat.
const _DEBRIS_COUNT_MIN: int = 5
const _DEBRIS_COUNT_MAX: int = 9
const _DEBRIS_INNER_SCALE: float = 0.82
const _DEBRIS_MIN_CENTER_DIST: float = 90.0
const _DEBRIS_MIN_SPAWN_DIST: float = 110.0
const _DEBRIS_MIN_BETWEEN_DIST: float = 75.0
const _DEBRIS_PLACE_ATTEMPTS: int = 80
## RING layout: tiles closer to the centre than this diamond norm form the walled core.
const RING_HOLE_NORM: float = 0.3
## CROSS layout: half-width of the vertical arm and half-height of the horizontal arm (px).
const CROSS_ARM_HALF_X: int = 128
const CROSS_ARM_HALF_Y: int = 80
## Pillars and random hazards keep this far from spawn markers, Fayde's start and doors.
const _PILLAR_KEEP_CLEAR_DIST: float = 120.0
## Clearance used for a random hazard when no tile is _PILLAR_KEEP_CLEAR_DIST from everything.
const _HAZARD_FALLBACK_CLEAR_DIST: float = 75.0

## Obstacle placement parameters. Set in the scene inspector to override per-template
## defaults. Falls back to a default ObstacleConfig (5–9 obstacles, inner 82 % diamond,
## 90/110/75 px clearances, 80 attempts). (LD-02)
@export var obstacle_config: ObstacleConfig = null

## Room template resource — data-driven room layout (LD-12).
## When set, _ready() uses template tile_cells, valid_zone_polygons, and spawn_positions
## instead of generating a default diamond. null = default diamond arena.
@export var room_template: RoomTemplate = null

## Floor identity (ADR-0020): floor tint, pillar colour, debris tint. Set by
## RoomTransitionManager before the room enters the tree. null = floor 1 look.
@export var floor_theme: FloorTheme = null

## Anchor object to place in this room (LD-22).
## Set by RoomPopulator when room type is Memory Chamber. null = no anchor in this room.
## Placed at a safe position inside the walkable zone after _build_floor() completes.
@export var anchor_object_data: AnchorObject = null

## Seed for the background props and whimsy detail (ADR-0038). -1 = random per build.
@export var decor_seed: int = -1

# ── @onready ──────────────────────────────────────────────────────────────────

@onready var _spawn_markers: Node2D = $SpawnMarkers
@onready var _tile_map: TileMapLayer = $TileMapLayer
@onready var _arena_bounds: StaticBody2D = $ArenaBounds

var _look: RoomLook = null
var _ambience_tween: Tween = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	var custom_cells: Array[Vector2i] = _resolve_layout_cells()
	if not custom_cells.is_empty():
		_build_floor_from_cells(custom_cells)
	else:
		_build_floor()
	if room_template != null and not room_template.spawn_positions.is_empty():
		_place_spawn_markers_from_template()
	else:
		_place_spawn_markers()
	_build_walls()
	_build_platform_edge()
	_add_backdrop()
	if not custom_cells.is_empty():
		_build_navigation_from_template_boundary()
	else:
		_build_navigation()
	var debris: Array[Vector2] = _build_debris_obstacles()
	_apply_floor_theme()
	var reserved: Array[Vector2] = debris.duplicate()
	reserved.append_array(_build_hazards(debris))
	_build_pillars(reserved)
	if anchor_object_data != null:
		_place_anchor_object(anchor_object_data)
	_spawn_exit_door()
	_build_decor()

# ── Public API ────────────────────────────────────────────────────────────────

## Returns the player spawn position: SW corner tile center.
## Guaranteed inside the safe zone (norm 0.5–0.82) — not OOB at combat zoom 2.0×.
## Fallback: Vector2.ZERO if no valid tile found (e.g. empty tile map in tests).
func get_player_spawn_position() -> Vector2:
	return _find_sw_position()


## Returns global positions of all Marker2D children under SpawnMarkers.
## Used by WaveManager to place enemy spawns (Enemy AI epic).
## Returns at least 3 non-zero Vector2 positions at MVP scope.
##
## Example:
##   var positions: Array[Vector2] = room.get_spawn_markers()
##   for pos in positions:
##       spawn_enemy_at(pos)
func get_spawn_markers() -> Array[Vector2]:
	if not is_node_ready() or _spawn_markers == null:
		return []
	var markers: Array[Vector2] = []
	for child: Node in _spawn_markers.get_children():
		if child is Marker2D:
			markers.append(child.global_position)
	return markers

# ── Private ───────────────────────────────────────────────────────────────────

## Spawns up to 3 RoomExitDoor Area2D nodes clustered in the NE corner.
## Positions are chosen by _find_ne_positions (safe zone norm 0.5–0.82, spaced ≥60px).
## Fallback: one door at Vector2(0, -300) if no valid NE tiles are found.
## RTM.wire_exit_doors() wires destinations after room load; hides surplus doors.
func _spawn_exit_door() -> void:
	var positions: Array[Vector2] = _find_ne_positions(3)
	if positions.is_empty():
		positions = [Vector2(0.0, -300.0)]
	for pos: Vector2 in positions:
		var door := RoomExitDoor.new()
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 30.0
		shape.shape = circle
		door.add_child(shape)
		door.position = pos
		add_child(door)


## Collects tile-map positions and delegates to _score_sw.
func _find_sw_position() -> Vector2:
	if _tile_map == null:
		return Vector2.ZERO
	var positions: Array[Vector2] = []
	for c: Vector2i in _tile_map.get_used_cells():
		positions.append(_tile_map.map_to_local(c))
	return _score_sw(positions)


## Pure function: returns the SW-most position from [param positions] in the safe zone.
## Safe zone: norm 0.5–0.82 (|x|/WALL_HALF_X + |y|/WALL_HALF_Y).
## SW score = -x + y (maximised when x is negative, y is positive — bottom-left screen).
## Returns Vector2.ZERO when no position passes the safe zone filter.
func _score_sw(positions: Array[Vector2]) -> Vector2:
	var best_pos: Vector2 = Vector2.ZERO
	var best_score: float = -INF
	for pos: Vector2 in positions:
		var norm: float = absf(pos.x) / float(_WALL_HALF_X) + absf(pos.y) / float(_WALL_HALF_Y)
		if norm < 0.5 or norm > 0.82:
			continue
		var score: float = -pos.x + pos.y
		if score > best_score:
			best_score = score
			best_pos = pos
	return best_pos


## Collects tile-map positions and delegates to _score_ne.
func _find_ne_positions(n: int) -> Array[Vector2]:
	if _tile_map == null:
		return []
	var positions: Array[Vector2] = []
	for c: Vector2i in _tile_map.get_used_cells():
		positions.append(_tile_map.map_to_local(c))
	return _score_ne(positions, n)


## Pure function: picks top [param n] NE positions from [param positions], spaced ≥60px.
## Safe zone: norm 0.5–0.82. NE score = x - y (maximised when x positive, y negative — top-right screen).
## Returns fewer than n if not enough valid candidates exist.
func _score_ne(positions: Array[Vector2], n: int) -> Array[Vector2]:
	var scored: Array[Dictionary] = []
	for pos: Vector2 in positions:
		var norm: float = absf(pos.x) / float(_WALL_HALF_X) + absf(pos.y) / float(_WALL_HALF_Y)
		if norm < 0.5 or norm > 0.82:
			continue
		scored.append({"pos": pos, "score": pos.x - pos.y})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	var result: Array[Vector2] = []
	for entry: Dictionary in scored:
		if result.size() >= n:
			break
		var candidate: Vector2 = entry["pos"] as Vector2
		var too_close: bool = false
		for chosen: Vector2 in result:
			if candidate.distance_to(chosen) < 60.0:
				too_close = true
				break
		if not too_close:
			result.append(candidate)
	return result


## Adds a NavigationRegion2D covering the diamond tile area.
## Enemies can query NavigationServer2D for pathfinding within this region.
func _build_navigation() -> void:
	var nav_region := NavigationRegion2D.new()
	var nav_poly := NavigationPolygon.new()
	# Diamond vertices: right → bottom → left → top (clockwise in Godot Y-down space).
	nav_poly.vertices = PackedVector2Array([
		Vector2(_WALL_HALF_X, 0),
		Vector2(0, _WALL_HALF_Y),
		Vector2(-_WALL_HALF_X, 0),
		Vector2(0, -_WALL_HALF_Y),
	])
	nav_poly.add_polygon(PackedInt32Array([0, 1, 2]))
	nav_poly.add_polygon(PackedInt32Array([0, 2, 3]))
	nav_region.navigation_polygon = nav_poly
	add_child(nav_region)


## Chooses which tile cells to use for this room's floor.
## Priority: (1) hand-authored tile_cells in template, (2) procedural layout_style,
## (3) empty → _ready() falls back to default diamond _build_floor().
func _resolve_layout_cells() -> Array[Vector2i]:
	if room_template == null:
		return []
	if not room_template.tile_cells.is_empty():
		return room_template.tile_cells
	match room_template.layout_style:
		1:   # NARROW — 60 % size diamond, tight corridors
			return _generate_narrow_cells()
		2:   # SPLIT — two chambers connected by a bridge
			return _generate_split_cells()
		3:   # ARENA — wide flat diamond, open combat space
			return _generate_arena_cells()
		4:   # CORRIDOR — narrow elongated diamond, linear movement
			return _generate_corridor_cells()
		5:   # RING — walled core in the middle, fight around it (ADR-0020)
			return _generate_ring_cells()
		6:   # CROSS — four arms around an open hub (ADR-0020)
			return _generate_cross_cells()
	return []   # DIAMOND (0) or unknown → default diamond


## Generates tile cells for a 60 % diamond (NARROW layout).
## Creates a compact arena that forces closer combat.
func _generate_narrow_cells() -> Array[Vector2i]:
	var xr: int = (_WALL_HALF_X / _TILE_X_STEP) * 6 / 10   # 60 % of 20 = 12
	var yr: int = (_WALL_HALF_Y / _TILE_Y_STEP) * 6 / 10   # 60 % of 24 = 14
	var scan: int = max(xr, yr) + 2
	var cells: Dictionary = {}
	for tx: int in range(-scan, scan + 1):
		for ty: int in range(-scan, scan + 1):
			var norm: float = float(abs(tx - ty)) / float(xr) + float(abs(tx + ty)) / float(yr)
			if norm <= 1.0:
				cells[Vector2i(tx, ty)] = true
	return _flood_fill_cells(cells, Vector2i(0, 0))


## Generates tile cells for a wide, flat arena (ARENA layout).
## 120 % x-radius, 75 % y-radius → visually wider and shallower than the default diamond.
## Creates an open combat space that favours ranged play.
func _generate_arena_cells() -> Array[Vector2i]:
	const ARENA_XR: int = 24   # 120 % of default 20 → wider screen x
	const ARENA_YR: int = 18   # 75 % of default 24 → shallower screen y
	var scan: int = max(ARENA_XR, ARENA_YR) + 2
	var cells: Dictionary = {}
	for tx: int in range(-scan, scan + 1):
		for ty: int in range(-scan, scan + 1):
			var norm: float = float(abs(tx - ty)) / float(ARENA_XR) + float(abs(tx + ty)) / float(ARENA_YR)
			if norm <= 1.0:
				cells[Vector2i(tx, ty)] = true
	return _flood_fill_cells(cells, Vector2i(0, 0))


## Generates tile cells for a narrow, elongated corridor (CORRIDOR layout).
## 50 % x-radius, 125 % y-radius → a tall narrow room that forces linear movement.
func _generate_corridor_cells() -> Array[Vector2i]:
	const CORRIDOR_XR: int = 10  # 50 % of default 20 → narrow screen x
	const CORRIDOR_YR: int = 30  # 125 % of default 24 → deep screen y
	var scan: int = max(CORRIDOR_XR, CORRIDOR_YR) + 2
	var cells: Dictionary = {}
	for tx: int in range(-scan, scan + 1):
		for ty: int in range(-scan, scan + 1):
			var norm: float = float(abs(tx - ty)) / float(CORRIDOR_XR) + float(abs(tx + ty)) / float(CORRIDOR_YR)
			if norm <= 1.0:
				cells[Vector2i(tx, ty)] = true
	return _flood_fill_cells(cells, Vector2i(0, 0))


## Generates tile cells for a two-chamber room split by a chokepoint (SPLIT layout).
## Left chamber and right chamber are connected by a narrow bridge in screen space.
## bridge_half = 2 tiles → bridge is ≈ 128 px wide in screen space.
## bridge_height = 6 tiles → bridge is ≈ 96 px tall in screen space.
func _generate_split_cells() -> Array[Vector2i]:
	const BRIDGE_HALF: int = 2
	const BRIDGE_HY:   int = 6
	var xr: int = _WALL_HALF_X / _TILE_X_STEP   # 20
	var yr: int = _WALL_HALF_Y / _TILE_Y_STEP    # 24
	var cells: Dictionary = {}
	for tx: int in range(-_FLOOR_RADIUS, _FLOOR_RADIUS + 1):
		for ty: int in range(-_FLOOR_RADIUS, _FLOOR_RADIUS + 1):
			var norm: float = float(abs(tx - ty)) / float(xr) + float(abs(tx + ty)) / float(yr)
			if norm > 1.0:
				continue
			var col: int = tx - ty   # maps to screen X
			var in_left: bool   = col < -BRIDGE_HALF
			var in_right: bool  = col > BRIDGE_HALF
			var in_bridge: bool = abs(col) <= BRIDGE_HALF and abs(tx + ty) <= BRIDGE_HY
			if in_left or in_right or in_bridge:
				cells[Vector2i(tx, ty)] = true
	return _flood_fill_cells(cells, Vector2i(0, 0))


## Generates tile cells for a diamond with a walled core in the middle (RING layout).
## Tiles whose screen-space diamond norm is below RING_HOLE_NORM are left empty;
## _build_walls() turns the hole's rim into wall, so the core blocks movement AND enemy
## bullets. Works in screen space via map_to_local, so it holds for any tile layout.
## (ADR-0020)
func _generate_ring_cells() -> Array[Vector2i]:
	return _cells_where(func(p: Vector2) -> bool:
		var norm: float = absf(p.x) / float(_WALL_HALF_X) + absf(p.y) / float(_WALL_HALF_Y)
		return norm <= 1.0 and norm >= RING_HOLE_NORM,
		Vector2(0.0, _WALL_HALF_Y * 0.65))


## Generates tile cells for a plus-shaped room (CROSS layout): four arms that meet
## in an open hub. The corners of the diamond are cut away, so enemies funnel in
## along the arms and the hub is the only wide space. (ADR-0020)
func _generate_cross_cells() -> Array[Vector2i]:
	return _cells_where(func(p: Vector2) -> bool:
		var norm: float = absf(p.x) / float(_WALL_HALF_X) + absf(p.y) / float(_WALL_HALF_Y)
		return norm <= 1.0 and (absf(p.x) <= CROSS_ARM_HALF_X or absf(p.y) <= CROSS_ARM_HALF_Y),
		Vector2.ZERO)


## Returns the connected set of tiles whose room-local centre passes [param keep],
## flood-filled from the tile under [param start_pos]. Scans ±_FLOOR_RADIUS on both
## axes, which covers the default diamond for the stacked isometric layout.
func _cells_where(keep: Callable, start_pos: Vector2) -> Array[Vector2i]:
	var cells: Dictionary = {}
	for tx: int in range(-_FLOOR_RADIUS, _FLOOR_RADIUS + 1):
		for ty: int in range(-_FLOOR_RADIUS, _FLOOR_RADIUS + 1):
			var c := Vector2i(tx, ty)
			if keep.call(_tile_map.map_to_local(c)):
				cells[c] = true
	return _flood_fill_cells(cells, _tile_map.local_to_map(start_pos))


## Flood-fill from [param start] over [param all_cells], returning only the
## connected component that includes [param start]. Removes isolated tile clusters.
func _flood_fill_cells(all_cells: Dictionary, start: Vector2i) -> Array[Vector2i]:
	if not all_cells.has(start):
		# start not in set — pick the first available cell
		if all_cells.is_empty():
			return []
		start = all_cells.keys()[0] as Vector2i
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		if visited.has(cell) or not all_cells.has(cell):
			continue
		visited[cell] = true
		for d: Vector2i in dirs:
			var nb: Vector2i = cell + d
			if all_cells.has(nb) and not visited.has(nb):
				queue.append(nb)
	var result: Array[Vector2i] = []
	for c: Vector2i in visited:
		result.append(c)
	return result


## Paints [param cells] onto the TileMapLayer using the standard floor tile setup.
## Shared by _build_floor_from_template() and the procedural shape generators.
func _build_floor_from_cells(cells: Array[Vector2i]) -> void:
	_tile_map.clear()
	_install_floor_atlas()
	for cell: Vector2i in cells:
		_set_floor_cell(cell)


## Registers the procedural floor atlas (ADR-0021) as the tile map's floor source.
## Replaces any source baked into the .tscn so the runtime path always wins.
func _install_floor_atlas() -> void:
	if _tile_map.tile_set.has_source(_FLOOR_SOURCE_ID):
		_tile_map.tile_set.remove_source(_FLOOR_SOURCE_ID)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = FloorTileAtlas.build_texture(get_look())
	atlas.texture_region_size = Vector2i(FloorTileAtlas.TILE_W, FloorTileAtlas.TILE_H)
	for v: int in FloorTileAtlas.VARIANT_COUNT:
		atlas.create_tile(Vector2i(v, 0))
	_tile_map.tile_set.add_source(atlas, _FLOOR_SOURCE_ID)


## Places a floor tile at [param cell], picking its variant from the cell hash.
func _set_floor_cell(cell: Vector2i) -> void:
	var v: int = FloorTileAtlas.variant_for_cell(cell, get_look())
	_tile_map.set_cell(cell, _FLOOR_SOURCE_ID, Vector2i(v, 0))


## Re-skins an already built room with [param theme]'s look (ADR-0038): floor
## tiles, platform edge, backdrop and decor. Used for the first room, which
## main.tscn builds before the floor theme is known. Layout and collision are
## untouched; debris and pillars are repainted in the new palette (ADR-0039).
func apply_floor_look(theme: FloorTheme) -> void:
	floor_theme = theme
	_look = null
	if not is_node_ready():
		return
	var cells: Array[Vector2i] = _tile_map.get_used_cells()
	_install_floor_atlas()
	for cell: Vector2i in cells:
		_set_floor_cell(cell)
	_build_platform_edge()
	_add_backdrop()
	_apply_floor_theme()
	_build_decor()
	_repaint_obstacles()


## Repaints existing debris and pillars in the current look and theme colours.
func _repaint_obstacles() -> void:
	var look: RoomLook = get_look()
	for child: Node in get_children():
		var rubble := child.get_node_or_null(^"Rubble") as Sprite2D
		if rubble != null:
			rubble.texture = PropArt.texture(PropArt.Prop.RUBBLE, look)
			(child as CanvasItem).modulate = floor_theme.debris_tint if floor_theme != null else Color.WHITE
		var pillar := child as CoverPillar
		if pillar != null:
			if floor_theme != null:
				pillar.color = floor_theme.pillar_color
			pillar.rune_color = look.prop_glow
			pillar.queue_redraw()


## Returns this room's environment palette: the floor theme's look, or the
## art bible defaults when there is no theme or the theme has no look.
func get_look() -> RoomLook:
	if _look == null:
		if floor_theme != null and floor_theme.look != null:
			_look = floor_theme.look
		else:
			_look = RoomLook.new()
	return _look


## Builds the floor tiles from room_template.tile_cells instead of the default diamond.
## Uses _build_floor_from_cells() then erases isolated tiles via flood-fill.
func _build_floor_from_template() -> void:
	_build_floor_from_cells(room_template.tile_cells)
	# Flood-fill from template origin (first cell, or Vector2i.ZERO) to remove isolated tiles.
	var all_cells: Dictionary = {}
	for c: Vector2i in _tile_map.get_used_cells():
		all_cells[c] = true
	var start: Vector2i = room_template.tile_cells[0] if not room_template.tile_cells.is_empty() else Vector2i.ZERO
	var connected: Array[Vector2i] = _flood_fill_cells(all_cells, start)
	var connected_set: Dictionary = {}
	for c: Vector2i in connected:
		connected_set[c] = true
	for c: Vector2i in all_cells:
		if not connected_set.has(c):
			_tile_map.erase_cell(c)


## Places spawn markers at template.predefined spawn_positions.
## Skips the centroid+angle auto-placement algorithm.
func _place_spawn_markers_from_template() -> void:
	var markers: Array[Node] = _spawn_markers.get_children()
	for i: int in range(min(markers.size(), room_template.spawn_positions.size())):
		if markers[i] is Marker2D:
			(markers[i] as Marker2D).position = room_template.spawn_positions[i]


## Builds a NavigationRegion2D from the template tile boundary.
## Uses the same edge-counting approach as _build_walls() to find the boundary,
## then constructs a navigation polygon from the boundary vertices.
func _build_navigation_from_template_boundary() -> void:
	var used: Array[Vector2i] = _tile_map.get_used_cells()
	if used.is_empty():
		return
	var corner_offsets: Array[Vector2] = [
		Vector2(0, -_TILE_Y_STEP), Vector2(_TILE_X_STEP, 0),
		Vector2(0, _TILE_Y_STEP), Vector2(-_TILE_X_STEP, 0),
	]
	var edge_count: Dictionary = {}
	var edge_points: Dictionary = {}
	for cell: Vector2i in used:
		var center: Vector2 = _tile_map.map_to_local(cell)
		for i: int in range(4):
			var a: Vector2 = center + corner_offsets[i]
			var b: Vector2 = center + corner_offsets[(i + 1) % 4]
			var key: String = _edge_key(a, b)
			edge_count[key] = int(edge_count.get(key, 0)) + 1
			if not edge_points.has(key):
				edge_points[key] = [a, b]
	# Collect boundary vertices in clock-wise order from boundary edges.
	# Build connected chains: each boundary edge connects two vertices.
	var boundary_edges: Array[Dictionary] = []
	for key: String in edge_count:
		if int(edge_count[key]) == 1:
			var pair: Array = edge_points[key]
			boundary_edges.append({"a": pair[0] as Vector2, "b": pair[1] as Vector2})
	if boundary_edges.is_empty():
		return
	# Chain edges into ordered vertices.
	var ordered: Array[Vector2] = []
	var current: Vector2 = boundary_edges[0]["a"] as Vector2
	var next: Vector2 = boundary_edges[0]["b"] as Vector2
	ordered.append(current)
	var used_edges: Dictionary = {}
	used_edges[_edge_key(current, next)] = true
	while true:
		ordered.append(next)
		var found: bool = false
		for e: Dictionary in boundary_edges:
			var ek: String = _edge_key(e["a"] as Vector2, e["b"] as Vector2)
			if used_edges.has(ek):
				continue
			var ea: Vector2 = e["a"] as Vector2
			var eb: Vector2 = e["b"] as Vector2
			var eps: float = 0.5
			if (ea - next).length() < eps:
				next = eb
				used_edges[ek] = true
				found = true
				break
			elif (eb - next).length() < eps:
				next = ea
				used_edges[ek] = true
				found = true
				break
		if not found:
			break
		if ordered.size() > 1 and (ordered[0] - next).length() < 1.0:
			break  # closed loop
	var nav_poly := NavigationPolygon.new()
	nav_poly.vertices = PackedVector2Array(ordered)
	var indices: PackedInt32Array = PackedInt32Array()
	for i: int in range(1, ordered.size() - 1):
		indices.append(0)
		indices.append(i)
		indices.append(i + 1)
	nav_poly.add_polygon(indices)
	var nav_region := NavigationRegion2D.new()
	nav_region.navigation_polygon = nav_poly
	add_child(nav_region)


## Loads the floor tile texture, registers it as a TileSetAtlasSource,
## and fills a diamond-shaped grid of floor tiles centred on the room origin.
## Diamond filter: |tx-ty|/x_radius + |tx+ty|/y_radius ≤ 1 maps exactly to
## the screen-space diamond defined by SegmentShape2D wall bounds.
func _build_floor() -> void:
	_tile_map.clear()
	_install_floor_atlas()
	# Isometric projection: tile (tx, ty) → screen ((tx-ty)*32, (tx+ty)*16).
	# Diamond filter: |screen_x|/WALL_HALF_X + |screen_y|/WALL_HALF_Y ≤ 1
	# → |tx-ty|/16 + |tx+ty|/20 ≤ 1  (x_radius=16, y_radius=20)
	var x_radius: int = _WALL_HALF_X / _TILE_X_STEP   # 512/32 = 16
	var y_radius: int = _WALL_HALF_Y / _TILE_Y_STEP   # 320/16 = 20
	for tx: int in range(-_FLOOR_RADIUS, _FLOOR_RADIUS + 1):
		for ty: int in range(-_FLOOR_RADIUS, _FLOOR_RADIUS + 1):
			var norm: float = float(abs(tx - ty)) / float(x_radius) + float(abs(tx + ty)) / float(y_radius)
			if norm <= 1.0:
				_set_floor_cell(Vector2i(tx, ty))
	# Flood-fill from origin — remove any tile not 4-connected to the main body.
	# Tip tiles at norm==1.0 can be isolated singletons in the staggered grid.
	var all_cells: Dictionary = {}
	for c: Vector2i in _tile_map.get_used_cells():
		all_cells[c] = true
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [Vector2i(0, 0)]
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		if visited.has(cell) or not all_cells.has(cell):
			continue
		visited[cell] = true
		for d: Vector2i in dirs:
			var nb: Vector2i = cell + d
			if all_cells.has(nb) and not visited.has(nb):
				queue.append(nb)
	for c: Vector2i in all_cells:
		if not visited.has(c):
			_tile_map.erase_cell(c)


## Returns [param n] angles evenly spaced around the circle: TAU * i / n for i in [0, n).
## Each spawn marker gets a distinct target direction, so any marker count (3, 6, …)
## spreads evenly around the arena instead of clustering. Pure function — unit-tested.
func _even_spawn_angles(n: int) -> Array[float]:
	var angles: Array[float] = []
	for i: int in range(n):
		angles.append(TAU * float(i) / float(maxi(n, 1)))
	return angles


## Repositions Marker2D children under SpawnMarkers to tile centers that are
## guaranteed inside the walkable area.  This runs after _build_floor() so
## get_used_cells() is always authoritative — no hardcoded positions needed.
##
## Strategy: find the screen-space centroid of all filled tiles, then assign
## each of the 3 markers to the best tile for a target angle (0°, 120°, 240°).
## "Best" = furthest from centroid that still lies within ±45° of the target,
## scored as: distance – angular_deviation * 80.
func _place_spawn_markers() -> void:
	var cells: Array[Vector2i] = _tile_map.get_used_cells()
	if cells.is_empty():
		return

	var centroid: Vector2 = Vector2.ZERO
	for c: Vector2i in cells:
		centroid += _tile_map.map_to_local(c)
	centroid /= float(cells.size())

	# Exclude tiles within 150px of the SW player spawn — keeps enemies out of
	# the player's starting zone so PREP→BATTLE doesn't feel like an ambush.
	var sw_pos: Vector2 = _find_sw_position()

	# Distribute markers evenly around the arena: angle = TAU * i / N. This scales to
	# any marker count (3, 6, …) so adding SpawnZone_D/E/F in the scene spreads the wave
	# instead of leaving the extra markers stacked at their .tscn default positions.
	var markers: Array[Node] = _spawn_markers.get_children()
	var marker_count: int = markers.size()
	var target_angles: Array[float] = _even_spawn_angles(marker_count)
	var used_cells: Dictionary = {}
	var placed_positions: Array[Vector2] = []
	for i: int in range(marker_count):
		if not (markers[i] is Marker2D):
			continue
		var target: float = target_angles[i]
		var best_cell: Vector2i = Vector2i.ZERO
		var best_score: float = -INF
		for c: Vector2i in cells:
			if used_cells.has(c):
				continue
			var pos: Vector2 = _tile_map.map_to_local(c)
			# Exclude tiles in the outer 22% of the diamond — boundary tiles put enemies
			# at the visible edge of the floor and appear OOB at combat zoom 2.0×.
			var norm_check: float = absf(pos.x) / float(_WALL_HALF_X) + absf(pos.y) / float(_WALL_HALF_Y)
			if norm_check > 0.78:
				continue
			if sw_pos != Vector2.ZERO and pos.distance_to(sw_pos) < 150.0:
				continue
			var too_close: bool = false
			for placed: Vector2 in placed_positions:
				if pos.distance_to(placed) < 80.0:
					too_close = true
					break
			if too_close:
				continue
			var offset: Vector2 = pos - centroid
			var dist: float = offset.length()
			if dist < 32.0:
				continue
			var ang_diff: float = absf(angle_difference(atan2(offset.y, offset.x), target))
			var score: float = dist - ang_diff * 80.0
			if score > best_score:
				best_score = score
				best_cell = c
		used_cells[best_cell] = true
		var best_pos: Vector2 = _tile_map.map_to_local(best_cell)
		placed_positions.append(best_pos)
		(markers[i] as Marker2D).position = best_pos


## Builds the arena collision boundary directly from the filled floor tiles so the
## walkable area matches the visible tiles exactly (no walk-on-void, no unreachable tiles).
##
## Layout-agnostic: collects all four diamond edges of every filled tile and keeps only
## those that occur exactly once. Edges shared by two filled tiles occur twice (identical
## endpoints) and are dropped as interior; single-occurrence edges are the region boundary.
## This holds for any isometric / staggered TileMapLayer layout — no neighbor assumptions.
##
## All boundary edges go into one ConcavePolygonShape2D ("segment soup") on $ArenaBounds.
## Both PlayerController and EnemyInstance collide with it (physics layer 1).
func _build_walls() -> void:
	# Idempotent on scene reload — drop any previously built collision shape.
	for child: Node in _arena_bounds.get_children():
		child.free()

	# Tile diamond corners relative to center (tile_size 64×32 → half 32×16).
	# The visual tile diamond is always tile_size-wide/tall regardless of map layout.
	var corner_offsets: Array[Vector2] = [
		Vector2(0, -_TILE_Y_STEP),   # top
		Vector2(_TILE_X_STEP, 0),    # right
		Vector2(0, _TILE_Y_STEP),    # bottom
		Vector2(-_TILE_X_STEP, 0),   # left
	]

	var edge_count: Dictionary = {}   # canonical edge key → occurrence count
	var edge_points: Dictionary = {}  # canonical edge key → [Vector2 a, Vector2 b]
	for cell: Vector2i in _tile_map.get_used_cells():
		var center: Vector2 = _tile_map.map_to_local(cell)
		for i: int in range(4):
			var a: Vector2 = center + corner_offsets[i]
			var b: Vector2 = center + corner_offsets[(i + 1) % 4]
			var key: String = _edge_key(a, b)
			edge_count[key] = int(edge_count.get(key, 0)) + 1
			if not edge_points.has(key):
				edge_points[key] = [a, b]

	var segments: PackedVector2Array = PackedVector2Array()
	for key: String in edge_count:
		if int(edge_count[key]) == 1:  # boundary edge — bordered by empty space
			var pair: Array = edge_points[key]
			segments.append(pair[0] as Vector2)
			segments.append(pair[1] as Vector2)

	var shape := ConcavePolygonShape2D.new()
	shape.segments = segments
	var cshape := CollisionShape2D.new()
	cshape.shape = shape
	_arena_bounds.add_child(cshape)


## Hangs a slab face under every lower boundary edge of the floor (ADR-0021), so
## the room reads as a solid platform instead of tiles floating in the void.
## Faces sit at z -1, under the tiles, and fade from edge_face to edge_face_bottom.
## The left-facing side is lit slightly more than the right-facing one.
func _build_platform_edge() -> void:
	var old: Node = get_node_or_null(^"PlatformEdge")
	if old != null:
		old.free()
	var look: RoomLook = get_look()
	var root := Node2D.new()
	root.name = "PlatformEdge"
	root.z_index = -1
	add_child(root)
	if look.edge_depth <= 0.0:
		return
	var drop := Vector2(0.0, look.edge_depth)
	for edge: PackedVector2Array in get_lower_boundary_edges():
		var a: Vector2 = edge[0]
		var b: Vector2 = edge[1]
		# Left-facing edges run down-right from the left corner (a.x < b.x, a.y < b.y).
		var faces_left: bool = (b.x - a.x) * (b.y - a.y) > 0.0
		var top: Color = look.edge_face if faces_left else look.edge_face.darkened(0.25)
		var face := Polygon2D.new()
		face.polygon = PackedVector2Array([a, b, b + drop, a + drop])
		face.vertex_colors = PackedColorArray([top, top, look.edge_face_bottom, look.edge_face_bottom])
		root.add_child(face)


## Returns the floor's boundary edges on the lower half of their tile (the ones a
## viewer looking down sees the side of), each as [a, b] with a.x < b.x.
func get_lower_boundary_edges() -> Array[PackedVector2Array]:
	return _boundary_edges(true)


## Returns the floor's boundary edges on the upper half of their tile (the far rim,
## where background props stand), each as [a, b] with a.x < b.x.
func get_upper_boundary_edges() -> Array[PackedVector2Array]:
	return _boundary_edges(false)


func _boundary_edges(lower_half: bool) -> Array[PackedVector2Array]:
	var corner_offsets: Array[Vector2] = [
		Vector2(0, -_TILE_Y_STEP), Vector2(_TILE_X_STEP, 0),
		Vector2(0, _TILE_Y_STEP), Vector2(-_TILE_X_STEP, 0),
	]
	var count: Dictionary = {}
	var picked: Dictionary = {}  # edge key → [a, b] for edges on the wanted half of a tile
	for cell: Vector2i in _tile_map.get_used_cells():
		var center: Vector2 = _tile_map.map_to_local(cell)
		for i: int in range(4):
			var a: Vector2 = center + corner_offsets[i]
			var b: Vector2 = center + corner_offsets[(i + 1) % 4]
			var key: String = _edge_key(a, b)
			count[key] = int(count.get(key, 0)) + 1
			if ((a.y + b.y) * 0.5 > center.y) == lower_half:
				picked[key] = PackedVector2Array([a, b] if a.x < b.x else [b, a])
	var out: Array[PackedVector2Array] = []
	for key: String in picked:
		if int(count[key]) == 1:
			out.append(picked[key] as PackedVector2Array)
	return out


## Adds the floor's background props and the room's whimsy detail (ADR-0038).
## Decor stands outside the walkable floor and owns no collision.
func _build_decor() -> void:
	var old: Node = get_node_or_null(^"RoomDecor")
	if old != null:
		old.free()
	var seed_value: int = decor_seed
	if seed_value < 0:
		seed_value = randi()
	var is_boss: bool = room_template != null and room_template.room_type == 3
	var decor := RoomDecor.new()
	decor.build(get_look(), get_upper_boundary_edges(), get_lower_boundary_edges(),
		_keep_clear_points(), is_boss, seed_value)
	add_child(decor)


## Tints the floor toward [param color] by [param weight] over [param seconds]
## (ADR-0039, art bible §2.7 / §4.3): a boss's reserved colour bleeds into the arena.
## Weight 0 returns to the floor theme's own tint. Characters and spells are untouched.
func set_ambience(color: Color, weight: float, seconds: float = 1.0) -> void:
	var base: Color = floor_theme.floor_tint if floor_theme != null else Color.WHITE
	var target: Color = ambience_tint(base, color, weight)
	if _ambience_tween != null:
		_ambience_tween.kill()
	if seconds <= 0.0 or not is_inside_tree():
		_tile_map.modulate = target
		return
	_ambience_tween = create_tween()
	_ambience_tween.tween_property(_tile_map, ^"modulate", target, seconds)


## Pure: the floor modulate for an ambience of [param color] at [param weight] over
## [param base]. Keeps alpha; weight is clamped to 0–1.
static func ambience_tint(base: Color, color: Color, weight: float) -> Color:
	var out: Color = base.lerp(base * color, clampf(weight, 0.0, 1.0))
	out.a = base.a
	return out


## Adds the screen-space backdrop and vignette for this floor's look (ADR-0021).
func _add_backdrop() -> void:
	var old: Node = get_node_or_null(^"RoomBackdrop")
	if old != null:
		old.free()
	var backdrop := RoomBackdrop.new()
	backdrop.name = "RoomBackdrop"
	backdrop.setup(get_look())
	add_child(backdrop)


## Returns an order-independent key for the edge between integer-rounded points [param a]
## and [param b], so the same edge collected from two adjacent tiles maps to one key.
func _edge_key(a: Vector2, b: Vector2) -> String:
	var pa := Vector2i(roundi(a.x), roundi(a.y))
	var pb := Vector2i(roundi(b.x), roundi(b.y))
	if pb.x < pa.x or (pb.x == pa.x and pb.y < pa.y):
		var tmp: Vector2i = pa
		pa = pb
		pb = tmp
	return "%d,%d-%d,%d" % [pa.x, pa.y, pb.x, pb.y]


## Returns the active obstacle config, loading defaults on first access. (LD-02)
## Template authors override via the @export obstacle_config in the inspector,
## or via room_template.obstacle_config (template override takes priority).
func _get_obstacle_config() -> ObstacleConfig:
	if room_template != null and room_template.obstacle_config != null:
		return room_template.obstacle_config
	if obstacle_config == null:
		obstacle_config = ObstacleConfig.new()
	return obstacle_config


## Returns random obstacle positions satisfying all level-generation.md clearance constraints.
## Uses rejection sampling (up to obstacle_config.place_attempts per slot). Slots that exhaust
## all attempts are silently skipped — caller may receive fewer than count_max positions.
## Pure function: no @onready access, safe to call before _ready() or in headless tests.
##
## Reads obstacle parameters from obstacle_config resource (LD-02).
##
## [param zone_check] Optional validity Callable (Vector2) -> bool. Default: inner-diamond
##  check using obstacle_config.inner_scale. Inject a custom check for template-specific valid zones.
## [param sample_half_x] X half-extent for random candidate generation. Default (< 0):
##  falls back to _WALL_HALF_X * obstacle_config.inner_scale.
## [param sample_half_y] Y half-extent for random candidate generation. Default (< 0):
##  falls back to _WALL_HALF_Y * obstacle_config.inner_scale.
func _generate_debris_positions(spawn_positions: Array[Vector2], zone_check: Callable = Callable(), sample_half_x: float = -1.0, sample_half_y: float = -1.0) -> Array[Vector2]:
	var cfg: ObstacleConfig = _get_obstacle_config()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count: int = rng.randi_range(cfg.count_min, cfg.count_max)
	var placed: Array[Vector2] = []
	var _valid: Callable = zone_check if zone_check.is_valid() else func(pos: Vector2) -> bool: return absf(pos.x) / float(_WALL_HALF_X) + absf(pos.y) / float(_WALL_HALF_Y) <= cfg.inner_scale
	var sx: float = sample_half_x if sample_half_x > 0.0 else _WALL_HALF_X * cfg.inner_scale
	var sy: float = sample_half_y if sample_half_y > 0.0 else _WALL_HALF_Y * cfg.inner_scale
	for _i: int in range(count):
		for _attempt: int in range(cfg.place_attempts):
			var x: float = rng.randf_range(-sx, sx)
			var y: float = rng.randf_range(-sy, sy)
			if not _valid.call(Vector2(x, y)):
				continue
			var candidate := Vector2(x, y)
			if candidate.length() < cfg.min_center_dist:
				continue
			var skip: bool = false
			for sp: Vector2 in spawn_positions:
				if candidate.distance_to(sp) < cfg.min_spawn_dist:
					skip = true
					break
			if not skip:
				for p: Vector2 in placed:
					if candidate.distance_to(p) < cfg.min_between_dist:
						skip = true
						break
			if skip:
				continue
			placed.append(candidate)
			break
	return placed


## Returns a zone_check Callable for the current room template.
## If the template defines valid_zone_rects, returns a Callable that tests
## point-in-any-rect via Rect2.has_point().
## If no template or empty rects, returns an invalid Callable — the generation
## function falls back to default inner-diamond zone. (LD-12)
func _get_zone_check() -> Callable:
	if room_template == null or room_template.valid_zone_rects.is_empty():
		return Callable()
	var rects: Array[Rect2] = room_template.valid_zone_rects
	return func(pos: Vector2) -> bool:
		for r: Rect2 in rects:
			if r.has_point(pos):
				return true
		return false


## Returns sample half-extents for random candidate generation.
## Uses template wall_half overrides if set, otherwise defaults to WALL_HALF_X/Y.
func _get_sample_extents() -> Dictionary:
	var wx: float = float(room_template.wall_half_x) if room_template != null and room_template.wall_half_x > 0 else float(_WALL_HALF_X)
	var wy: float = float(room_template.wall_half_y) if room_template != null and room_template.wall_half_y > 0 else float(_WALL_HALF_Y)
	var cfg: ObstacleConfig = _get_obstacle_config()
	return {"x": wx * cfg.inner_scale, "y": wy * cfg.inner_scale}


## Returns the room-local centers of every "interior" floor tile — a filled tile whose
## four orthogonal neighbours are ALSO filled. Debris placed at an interior center (radius
## _DEBRIS_RADIUS) is therefore fully surrounded by floor and can never overhang a wall,
## for ANY layout: default diamond, narrow, arena, corridor, split, or hand-authored cells.
##
## Derived from the live TileMapLayer (authoritative after _build_floor*), so it tracks the
## actual generated shape rather than the default-diamond WALL_HALF constants. Returns an
## empty array when no tile map exists (headless/pure tests) — callers fall back to the
## legacy diamond sampler. (LD-02 — out-of-bounds obstacle fix)
func _interior_tile_centers() -> Array[Vector2]:
	var centers: Array[Vector2] = []
	if _tile_map == null:
		return centers
	var used: Dictionary = {}
	for c: Vector2i in _tile_map.get_used_cells():
		used[c] = true
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for c: Vector2i in used:
		var interior: bool = true
		for d: Vector2i in dirs:
			if not used.has(c + d):
				interior = false
				break
		if interior:
			centers.append(_tile_map.map_to_local(c))
	return centers


## Selects obstacle positions by sampling from [param candidates] — on-floor interior tile
## centers — instead of sampling free (x, y) against an approximate zone. Because every chosen
## point is a real floor-tile center, obstacles can never land outside the arena regardless of
## room layout. Enforces the same clearance constraints as _generate_debris_positions:
## min_center_dist from origin, min_spawn_dist from spawn markers, min_between_dist between
## obstacles. Candidates are shuffled so placement varies each run. (LD-02 — OOB fix)
##
## [param zone_check] optional extra filter (e.g. a template's valid_zone_rects). When valid,
##  a candidate must ALSO pass it — the on-floor mask remains the hard bound either way.
func _generate_debris_on_floor(spawn_positions: Array[Vector2], candidates: Array[Vector2], zone_check: Callable = Callable()) -> Array[Vector2]:
	var cfg: ObstacleConfig = _get_obstacle_config()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count: int = rng.randi_range(cfg.count_min, cfg.count_max)
	# Fisher-Yates shuffle a working copy so the chosen subset (and its order) varies per run.
	var pool: Array[Vector2] = candidates.duplicate()
	for i: int in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2 = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var placed: Array[Vector2] = []
	for cand: Vector2 in pool:
		if placed.size() >= count:
			break
		if cand.length() < cfg.min_center_dist:
			continue
		if zone_check.is_valid() and not zone_check.call(cand):
			continue
		var skip: bool = false
		for sp: Vector2 in spawn_positions:
			if cand.distance_to(sp) < cfg.min_spawn_dist:
				skip = true
				break
		if not skip:
			for p: Vector2 in placed:
				if cand.distance_to(p) < cfg.min_between_dist:
					skip = true
					break
		if skip:
			continue
		placed.append(cand)
	return placed


## Spawns half-cover debris obstacles (S9-09, design/quick-specs/arena-cover-types.md).
## Debris blocks movement (physics layer 16) but not Prana spells or projectiles.
## Each debris also has a NavigationObstacle2D for enemy avoidance.
##
## Positions come from interior floor-tile centers (_generate_debris_on_floor) so obstacles
## are guaranteed inside the arena for every layout. When no tile map is present (headless
## edge case) it falls back to the legacy diamond sampler. A room_template's valid_zone_rects,
## when set, further constrains placement on top of the on-floor mask. (LD-02, LD-12)
func _build_debris_obstacles() -> Array[Vector2]:
	var spawn_positions: Array[Vector2] = get_spawn_markers()
	var zone_check: Callable = _get_zone_check()
	var candidates: Array[Vector2] = _interior_tile_centers()
	var positions: Array[Vector2]
	if candidates.is_empty():
		var extents: Dictionary = _get_sample_extents()
		positions = _generate_debris_positions(spawn_positions, zone_check, extents["x"], extents["y"])
	else:
		positions = _generate_debris_on_floor(spawn_positions, candidates, zone_check)
	for pos: Vector2 in positions:
		var body := StaticBody2D.new()
		body.name = "Debris"
		body.position = pos
		body.collision_layer = _HALF_COVER_LAYER
		body.collision_mask = 0

		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = _DEBRIS_RADIUS
		shape.shape = circle
		body.add_child(shape)

		var nav_obstacle := NavigationObstacle2D.new()
		nav_obstacle.radius = _DEBRIS_NAV_RADIUS
		nav_obstacle.avoidance_enabled = true
		body.add_child(nav_obstacle)

		# ADR-0039: pixel-art rubble painted in the floor's prop palette, 2× pixel scale
		# like the rim props, with a flat ground shadow (art bible §5.4, §6.3).
		var r: float = _DEBRIS_RADIUS
		var shadow := Polygon2D.new()
		shadow.polygon = PackedVector2Array([
			Vector2(0, -r * 0.45), Vector2(r * 0.85, 0),
			Vector2(0, r * 0.45), Vector2(-r * 0.85, 0),
		])
		shadow.color = Color(0.05, 0.04, 0.06, 0.5)
		shadow.z_index = 4
		body.add_child(shadow)
		var rock := Sprite2D.new()
		rock.name = "Rubble"
		rock.texture = PropArt.texture(PropArt.Prop.RUBBLE, get_look())
		rock.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rock.scale = Vector2(RoomDecor.PIXEL_SCALE, RoomDecor.PIXEL_SCALE)
		rock.offset = Vector2(0.0, -float(rock.texture.get_height()) * 0.5 + 4.0)
		rock.flip_h = (int(pos.x) + int(pos.y)) % 2 == 0
		rock.z_index = 5
		body.add_child(rock)
		if floor_theme != null:
			body.modulate = floor_theme.debris_tint

		add_child(body)
	return positions


# ── Stage layout (ADR-0020) ───────────────────────────────────────────────────

## Applies the floor theme's tile tint. Debris and pillar colours are applied as
## they are built. No-op without a theme (floor 1 look).
func _apply_floor_theme() -> void:
	if floor_theme == null or _tile_map == null:
		return
	_tile_map.modulate = floor_theme.floor_tint


## Points pillars and random hazards must keep clear of: spawn markers, Fayde's
## start tile and the exit-door slots (computed the same way _spawn_exit_door does).
func _keep_clear_points() -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for m: Vector2 in get_spawn_markers():
		pts.append(to_local(m) if is_inside_tree() else m)
	var sw: Vector2 = _find_sw_position()
	if sw != Vector2.ZERO:
		pts.append(sw)
	pts.append_array(_find_ne_positions(3))
	return pts


## Half-extents of the built floor in pixels (max |x|, max |y| over tile edges).
## Falls back to the default diamond when no tiles exist.
func _floor_half_extents() -> Vector2:
	var ex := Vector2.ZERO
	if _tile_map != null:
		for c: Vector2i in _tile_map.get_used_cells():
			var p: Vector2 = _tile_map.map_to_local(c)
			ex.x = maxf(ex.x, absf(p.x) + _TILE_X_STEP)
			ex.y = maxf(ex.y, absf(p.y) + _TILE_Y_STEP)
	if ex == Vector2.ZERO:
		return Vector2(_WALL_HALF_X, _WALL_HALF_Y)
	return ex


## Builds the template's hazards under a "Hazards" node. Random-position hazards
## take a free interior tile clear of spawns, doors, Fayde's start and [param taken].
## Returns the room-local positions used, so pillars keep clear of them.
func _build_hazards(taken: Array[Vector2]) -> Array[Vector2]:
	var used: Array[Vector2] = []
	if room_template == null or room_template.hazards.is_empty():
		return used
	var holder := Node2D.new()
	holder.name = "Hazards"
	add_child(holder)
	var clear: Array[Vector2] = _keep_clear_points()
	var candidates: Array[Vector2] = _interior_tile_centers()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for spec: HazardSpec in room_template.hazards:
		var hazard: StageHazard = StageHazard.create(spec)
		if hazard == null:
			continue
		var pos: Vector2 = spec.position
		if spec.kind == HazardSpec.Kind.CLOSING_RING:
			pos = Vector2.ZERO
			(hazard as HazardClosingRing).half_extents = _floor_half_extents()
		elif spec.random_position:
			var avoid: Array[Vector2] = clear.duplicate()
			avoid.append_array(taken)
			avoid.append_array(used)
			var picked: Array[Vector2] = pick_spread_positions(
				candidates, 1, avoid, _PILLAR_KEEP_CLEAR_DIST, 0.0, 0.0, rng.randi())
			if picked.is_empty():
				# Crowded room (debris landed badly): relax the clearance rather than
				# silently dropping a hazard the template asked for.
				picked = pick_spread_positions(
					candidates, 1, avoid, _HAZARD_FALLBACK_CLEAR_DIST, 0.0, 0.0, rng.randi())
			if picked.is_empty():
				hazard.free()
				continue
			pos = picked[0]
		hazard.position = pos
		used.append(pos)
		holder.add_child(hazard)
	return used


## Places full-cover pillars (ADR-0020) from the obstacle config. They take interior
## tiles clear of spawns, doors, Fayde's start and [param taken] (debris, hazards).
func _build_pillars(taken: Array[Vector2]) -> void:
	var cfg: ObstacleConfig = _get_obstacle_config()
	if cfg.pillar_count_max <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count: int = rng.randi_range(maxi(cfg.pillar_count_min, 0), cfg.pillar_count_max)
	var avoid: Array[Vector2] = _keep_clear_points()
	avoid.append_array(taken)
	var positions: Array[Vector2] = pick_spread_positions(
		_interior_tile_centers(), count, avoid, _PILLAR_KEEP_CLEAR_DIST,
		cfg.pillar_min_between_dist, cfg.min_center_dist, rng.randi())
	var col: Color = floor_theme.pillar_color if floor_theme != null else Color(0.46, 0.44, 0.52, 1.0)
	for pos: Vector2 in positions:
		var pillar := CoverPillar.new()
		pillar.name = "Pillar"
		pillar.setup(cfg.pillar_hits, cfg.pillar_radius, col, get_look().prop_glow)
		pillar.position = pos
		add_child(pillar)


## Pure: picks up to [param count] points from [param candidates] (shuffled with
## [param rng_seed]) so that each pick is at least [param avoid_dist] from every point in
## [param avoid], at least [param min_between] from other picks, and at least
## [param min_center] from the room origin. May return fewer when space runs out.
static func pick_spread_positions(candidates: Array[Vector2], count: int, avoid: Array[Vector2],
		avoid_dist: float, min_between: float, min_center: float, rng_seed: int) -> Array[Vector2]:
	var placed: Array[Vector2] = []
	if count <= 0:
		return placed
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var pool: Array[Vector2] = candidates.duplicate()
	for i: int in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2 = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	for cand: Vector2 in pool:
		if placed.size() >= count:
			break
		if cand.length() < min_center:
			continue
		var ok: bool = true
		for a: Vector2 in avoid:
			if cand.distance_to(a) < avoid_dist:
				ok = false
				break
		if ok:
			for p: Vector2 in placed:
				if cand.distance_to(p) < min_between:
					ok = false
					break
		if ok:
			placed.append(cand)
	return placed


## Places one AnchorObjectNode at a safe position inside the walkable zone (LD-22).
## Position strategy: tile centroid offset by a fixed vector — guaranteed inside the
## diamond for the default arena, safe from spawn markers (>80px) and walls (>60px).
## Future: RoomPopulator will pass per-room safe positions derived from valid_zone_polygons.
##
## [param data] AnchorObject resource defining the anchor identity and trigger radius.
func _place_anchor_object(data: AnchorObject) -> void:
	var anchor_scene: PackedScene = load("res://src/scenes/AnchorObjectNode.tscn")
	if anchor_scene == null:
		push_error("IsometricRoom: AnchorObjectNode.tscn not found")
		return
	var node: AnchorObjectNode = anchor_scene.instantiate() as AnchorObjectNode
	node.set_anchor_data(data)
	node.memory_fragment_triggered.connect(_on_memory_fragment_triggered)
	var entity_layer: Node2D = get_node_or_null("EntityLayer") as Node2D
	var parent: Node = entity_layer if entity_layer != null else self
	parent.add_child(node)
	# Default safe position: slightly south of center — inside the default diamond,
	# well clear of spawn markers (A=-192,-96; B=192,-96; C=0,128) and walls (±384 y).
	node.position = Vector2(0.0, 60.0)


func _on_memory_fragment_triggered(memory_id: StringName) -> void:
	var modal := MemoryFragmentModal.new()
	modal.setup(memory_id)
	add_child(modal)
