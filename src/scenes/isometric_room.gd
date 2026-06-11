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
## Radius in tiles from origin. 10 tiles covers ±320 px screen-x, ±160 px screen-y
## per step — enough to enclose all spawn markers and player start position.
const _FLOOR_RADIUS: int = 10

# ── @onready ──────────────────────────────────────────────────────────────────

@onready var _spawn_markers: Node2D = $SpawnMarkers
@onready var _tile_map: TileMapLayer = $TileMapLayer

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_floor()

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

## Loads the floor tile texture, registers it as a TileSetAtlasSource,
## and fills a square grid of floor tiles centred on the room origin.
func _build_floor() -> void:
	var tex: Texture2D = load(_FLOOR_TILE_PATH) as Texture2D
	if tex == null:
		push_error("IsometricRoom: floor tile not found at %s" % _FLOOR_TILE_PATH)
		return
	var atlas := TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(64, 32)
	atlas.create_tile(_FLOOR_ATLAS_COORD)
	_tile_map.tile_set.add_source(atlas, _FLOOR_SOURCE_ID)
	for tx: int in range(-_FLOOR_RADIUS, _FLOOR_RADIUS + 1):
		for ty: int in range(-_FLOOR_RADIUS, _FLOOR_RADIUS + 1):
			_tile_map.set_cell(Vector2i(tx, ty), _FLOOR_SOURCE_ID, _FLOOR_ATLAS_COORD)
