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

const _FLOOR_TILE_PATH: String = "res://assets/art/tiles/iso_floor_stone2.png"
const _FLOOR_SOURCE_ID: int = 0
const _FLOOR_ATLAS_COORD: Vector2i = Vector2i(0, 0)
## Scan radius. Must be >= max(x_radius, y_radius) = max(20, 24).
const _FLOOR_RADIUS: int = 26
## Arena diamond half-extents in screen pixels.
## Full diamond 1280×768 game-px. At combat zoom 1.5×: visible 768×432 — Fayde (~64px)
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

## Obstacle placement parameters. Set in the scene inspector to override per-template
## defaults. Falls back to a default ObstacleConfig (5–9 obstacles, inner 82 % diamond,
## 90/110/75 px clearances, 80 attempts). (LD-02)
@export var obstacle_config: ObstacleConfig = null

## Room template resource — data-driven room layout (LD-12).
## When set, _ready() uses template tile_cells, valid_zone_polygons, and spawn_positions
## instead of generating a default diamond. null = default diamond arena.
@export var room_template: RoomTemplate = null

## Anchor object to place in this room (LD-22).
## Set by RoomPopulator when room type is Memory Chamber. null = no anchor in this room.
## Placed at a safe position inside the walkable zone after _build_floor() completes.
@export var anchor_object_data: AnchorObject = null

# ── @onready ──────────────────────────────────────────────────────────────────

@onready var _spawn_markers: Node2D = $SpawnMarkers
@onready var _tile_map: TileMapLayer = $TileMapLayer
@onready var _arena_bounds: StaticBody2D = $ArenaBounds

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	if room_template != null and not room_template.tile_cells.is_empty():
		_build_floor_from_template()
	else:
		_build_floor()
	if room_template != null and not room_template.spawn_positions.is_empty():
		_place_spawn_markers_from_template()
	else:
		_place_spawn_markers()
	_build_walls()
	if room_template != null and not room_template.tile_cells.is_empty():
		_build_navigation_from_template_boundary()
	else:
		_build_navigation()
	_build_debris_obstacles()
	if anchor_object_data != null:
		_place_anchor_object(anchor_object_data)

# ── Public API ────────────────────────────────────────────────────────────────

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


## Builds the floor tiles from room_template.tile_cells instead of the default diamond.
## Reuses the same TileSetAtlasSource setup as _build_floor().
func _build_floor_from_template() -> void:
	_tile_map.clear()
	if _tile_map.tile_set.has_source(_FLOOR_SOURCE_ID):
		_tile_map.tile_set.remove_source(_FLOOR_SOURCE_ID)
	var tex: Texture2D = load(_FLOOR_TILE_PATH) as Texture2D
	if tex == null:
		push_error("IsometricRoom: floor tile not found at %s" % _FLOOR_TILE_PATH)
		return
	var atlas := TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(64, 32)
	atlas.create_tile(_FLOOR_ATLAS_COORD)
	_tile_map.tile_set.add_source(atlas, _FLOOR_SOURCE_ID)
	for cell: Vector2i in room_template.tile_cells:
		_tile_map.set_cell(cell, _FLOOR_SOURCE_ID, _FLOOR_ATLAS_COORD)
	# Flood-fill from origin — remove isolated tiles not connected to the main body.
	var all_cells: Dictionary = {}
	for c: Vector2i in _tile_map.get_used_cells():
		all_cells[c] = true
	# Start flood-fill from the first tile cell (template origin point).
	var start: Vector2i = room_template.tile_cells[0] if not room_template.tile_cells.is_empty() else Vector2i.ZERO
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
	for c: Vector2i in all_cells:
		if not visited.has(c):
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
	# Always reload — removes stale baked source from .tscn so the runtime path wins.
	if _tile_map.tile_set.has_source(_FLOOR_SOURCE_ID):
		_tile_map.tile_set.remove_source(_FLOOR_SOURCE_ID)
	var tex: Texture2D = load(_FLOOR_TILE_PATH) as Texture2D
	if tex == null:
		push_error("IsometricRoom: floor tile not found at %s" % _FLOOR_TILE_PATH)
		return
	var atlas := TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(64, 32)
	atlas.create_tile(_FLOOR_ATLAS_COORD)
	_tile_map.tile_set.add_source(atlas, _FLOOR_SOURCE_ID)
	# Isometric projection: tile (tx, ty) → screen ((tx-ty)*32, (tx+ty)*16).
	# Diamond filter: |screen_x|/WALL_HALF_X + |screen_y|/WALL_HALF_Y ≤ 1
	# → |tx-ty|/16 + |tx+ty|/20 ≤ 1  (x_radius=16, y_radius=20)
	var x_radius: int = _WALL_HALF_X / _TILE_X_STEP   # 512/32 = 16
	var y_radius: int = _WALL_HALF_Y / _TILE_Y_STEP   # 320/16 = 20
	for tx: int in range(-_FLOOR_RADIUS, _FLOOR_RADIUS + 1):
		for ty: int in range(-_FLOOR_RADIUS, _FLOOR_RADIUS + 1):
			var norm: float = float(abs(tx - ty)) / float(x_radius) + float(abs(tx + ty)) / float(y_radius)
			if norm <= 1.0:
				_tile_map.set_cell(Vector2i(tx, ty), _FLOOR_SOURCE_ID, _FLOOR_ATLAS_COORD)
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

	var target_angles: Array[float] = [0.0, TAU / 3.0, 2.0 * TAU / 3.0]
	var markers: Array[Node] = _spawn_markers.get_children()
	var used_cells: Dictionary = {}
	var placed_positions: Array[Vector2] = []
	for i: int in range(min(markers.size(), target_angles.size())):
		if not (markers[i] is Marker2D):
			continue
		var target: float = target_angles[i]
		var best_cell: Vector2i = Vector2i.ZERO
		var best_score: float = -INF
		for c: Vector2i in cells:
			if used_cells.has(c):
				continue
			var pos: Vector2 = _tile_map.map_to_local(c)
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


## Spawns half-cover debris obstacles (S9-09, design/quick-specs/arena-cover-types.md).
## Debris blocks movement (physics layer 16) but not Prana spells or projectiles.
## Each debris also has a NavigationObstacle2D for enemy avoidance.
## Positions are randomised each run via _generate_debris_positions (level-generation.md).
## When a room_template is set, passes the template's zone_check and sample extents. (LD-12)
func _build_debris_obstacles() -> void:
	var spawn_positions: Array[Vector2] = get_spawn_markers()
	var zone_check: Callable = _get_zone_check()
	var extents: Dictionary = _get_sample_extents()
	for pos: Vector2 in _generate_debris_positions(spawn_positions, zone_check, extents["x"], extents["y"]):
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

		# Isometric rock silhouette — diamond base with raised top mass.
		# Three layered Polygon2D simulate a chunky rock in isometric view.
		var r: float = _DEBRIS_RADIUS
		# Shadow footprint (dark diamond on floor)
		var shadow := Polygon2D.new()
		shadow.polygon = PackedVector2Array([
			Vector2(0, -r * 0.45), Vector2(r * 0.85, 0),
			Vector2(0, r * 0.45), Vector2(-r * 0.85, 0),
		])
		shadow.color = Color(0.10, 0.08, 0.07, 0.60)
		shadow.z_index = 4
		body.add_child(shadow)
		# Main rock body (mid-grey stone mass)
		var rock := Polygon2D.new()
		rock.polygon = PackedVector2Array([
			Vector2(-r * 0.30, -r * 1.10),
			Vector2( r * 0.30, -r * 1.10),
			Vector2( r * 0.80, -r * 0.30),
			Vector2( r * 0.65,  r * 0.20),
			Vector2( r * 0.00,  r * 0.42),
			Vector2(-r * 0.65,  r * 0.20),
			Vector2(-r * 0.80, -r * 0.30),
		])
		rock.color = Color(0.42, 0.38, 0.34, 1.0)
		rock.z_index = 5
		body.add_child(rock)
		# Top face highlight (lighter patch on top of rock)
		var top := Polygon2D.new()
		top.polygon = PackedVector2Array([
			Vector2(-r * 0.20, -r * 1.05),
			Vector2( r * 0.20, -r * 1.05),
			Vector2( r * 0.45, -r * 0.55),
			Vector2( r * 0.00, -r * 0.40),
			Vector2(-r * 0.45, -r * 0.55),
		])
		top.color = Color(0.62, 0.57, 0.51, 1.0)
		top.z_index = 6
		body.add_child(top)

		add_child(body)


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
	var entity_layer: Node2D = get_node_or_null("EntityLayer") as Node2D
	var parent: Node = entity_layer if entity_layer != null else self
	parent.add_child(node)
	# Default safe position: slightly south of center — inside the default diamond,
	# well clear of spawn markers (A=-192,-96; B=192,-96; C=0,128) and walls (±384 y).
	node.position = Vector2(0.0, 60.0)
