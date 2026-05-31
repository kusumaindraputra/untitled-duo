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

# ── @onready ──────────────────────────────────────────────────────────────────

@onready var _spawn_markers: Node2D = $SpawnMarkers

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
