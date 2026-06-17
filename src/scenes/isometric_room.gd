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

const _FLOOR_TILE_PATH: String = "res://assets/art/tiles/iso_floor_stone.png"
const _FLOOR_SOURCE_ID: int = 0
const _FLOOR_ATLAS_COORD: Vector2i = Vector2i(0, 0)
## Scan radius. Must be >= max(|tx-ty|, |tx+ty|) needed to fill the arena.
const _FLOOR_RADIUS: int = 10
## Arena diamond half-extents in screen pixels — match SegmentShape2D in IsometricRoom.tscn.
const _WALL_HALF_X: int = 256
const _WALL_HALF_Y: int = 192
## Screen pixels per tile isometric axis unit (tile_size = 64x32 → half = 32x16).
const _TILE_X_STEP: int = 32
const _TILE_Y_STEP: int = 16
## Half-cover debris: blocks movement, not Prana/projectiles (S9-09, design/quick-specs/arena-cover-types.md).
const _HALF_COVER_LAYER: int = 16  # bit 4 — Layer 5 in Godot physics layer UI
const _DEBRIS_RADIUS: float = 20.0
const _DEBRIS_NAV_RADIUS: float = 25.0
## Asymmetric debris positions — create routing lanes without blocking spawn markers.
const _DEBRIS_POSITIONS: Array = [Vector2(80, -55), Vector2(-100, 25), Vector2(45, 85)]

# ── @onready ──────────────────────────────────────────────────────────────────

@onready var _spawn_markers: Node2D = $SpawnMarkers
@onready var _tile_map: TileMapLayer = $TileMapLayer

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_floor()
	_build_wall_visuals()
	_build_navigation()
	_build_debris_obstacles()

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

## Draws a debug Line2D diamond matching the isometric arena boundary.
## Removed when real wall art replaces the physics-only collision shapes.
func _build_wall_visuals() -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([
		Vector2(_WALL_HALF_X, 0), Vector2(0, _WALL_HALF_Y),
		Vector2(-_WALL_HALF_X, 0), Vector2(0, -_WALL_HALF_Y), Vector2(_WALL_HALF_X, 0)
	])
	line.width = 2.0
	line.default_color = Color(0.8, 0.6, 0.2, 0.9)
	line.z_index = 100
	add_child(line)


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


## Loads the floor tile texture, registers it as a TileSetAtlasSource,
## and fills a square grid of floor tiles centred on the room origin.
func _build_floor() -> void:
	if not _tile_map.tile_set.has_source(_FLOOR_SOURCE_ID):
		var tex: Texture2D = load(_FLOOR_TILE_PATH) as Texture2D
		if tex == null:
			push_error("IsometricRoom: floor tile not found at %s" % _FLOOR_TILE_PATH)
			return
		var atlas := TileSetAtlasSource.new()
		atlas.texture = tex
		atlas.texture_region_size = Vector2i(64, 32)
		atlas.create_tile(_FLOOR_ATLAS_COORD)
		_tile_map.tile_set.add_source(atlas, _FLOOR_SOURCE_ID)
	# Isometric projection: tile (tx, ty) has center at screen ((tx-ty)*32, (tx+ty)*16).
	# Diamond filter: tile visual edge (not center) must stay within wall diamond.
	# Each tile extends ±TILE_X_STEP in x and ±TILE_Y_STEP in y from its center.
	# So the max safe center radius = WALL_HALF - 1 tile step in each axis.
	# Minkowski sum: center_diamond + tile_diamond = wall_diamond → exact visual fit.
	var x_radius: int = (_WALL_HALF_X - _TILE_X_STEP) / _TILE_X_STEP   # (256-32)/32 = 7
	var y_radius: int = (_WALL_HALF_Y - _TILE_Y_STEP) / _TILE_Y_STEP   # (192-16)/16 = 11
	for tx: int in range(-_FLOOR_RADIUS, _FLOOR_RADIUS + 1):
		for ty: int in range(-_FLOOR_RADIUS, _FLOOR_RADIUS + 1):
			if float(abs(tx - ty)) / x_radius + float(abs(tx + ty)) / y_radius <= 1.0:
				_tile_map.set_cell(Vector2i(tx, ty), _FLOOR_SOURCE_ID, _FLOOR_ATLAS_COORD)


## Spawns half-cover debris obstacles (S9-09, design/quick-specs/arena-cover-types.md).
## Debris blocks movement (physics layer 16) but not Prana spells or projectiles.
## Each debris also has a NavigationObstacle2D for enemy avoidance.
func _build_debris_obstacles() -> void:
	for pos: Vector2 in _DEBRIS_POSITIONS:
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

		# Debug visual — replaced by art at VS scope.
		var poly := Polygon2D.new()
		var pts: PackedVector2Array = PackedVector2Array()
		var steps: int = 8
		for i: int in range(steps):
			var angle: float = (float(i) / steps) * TAU
			pts.append(Vector2(cos(angle), sin(angle)) * _DEBRIS_RADIUS)
		poly.polygon = pts
		poly.color = Color(0.55, 0.40, 0.25, 0.85)
		poly.z_index = 5
		body.add_child(poly)

		add_child(body)
