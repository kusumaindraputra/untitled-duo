## RoomTemplate — data-driven room layout for template-based dungeon generation.
##
## Each template defines a unique room shape: which tiles are filled, where obstacles
## can be placed (valid zone), where enemies spawn, and optional parameter overrides.
##
## When a template is assigned to IsometricRoom (via @export room_template), the room
## uses template data instead of generating a default diamond. When room_template is
## null (default), the room behaves as before — full diamond floor, inner-diamond
## valid zone, auto-placed spawn markers.
##
## Room authors create .tres files via the inspector. No editor plugin required.
##
## GDD: design/layer1-template-pool.md
## Roadmap: design/level-design-roadmap.md (LD-12)
class_name RoomTemplate
extends Resource

# ── Identity ────────────────────────────────────────────────────────────────────

## Human-readable template name. Shown in debug overlay and template selector.
@export var display_name: String = ""

## Room type: 0=Combat, 1=Elite, 2=Rest, 3=BossGate.
@export var room_type: int = 0

# ── Tile Layout ─────────────────────────────────────────────────────────────────

## Tile coordinates (Vector2i) to fill. If empty, the room falls back to default
## diamond generation — full diamond with WALL_HALF_X/WALL_HALF_Y extents.
## Each cell is placed via TileMapLayer.set_cell() at runtime.
@export var tile_cells: Array[Vector2i] = []

## Half-extent for tile scan. Used when tile_cells is empty (default diamond).
## Template authors can ignore this; it only matters for the diamond fallback.
## Default 26 covers WALL_HALF_X=640 → x_radius=20 and WALL_HALF_Y=384 → y_radius=24.
@export var floor_radius: int = 26

# ── Walls & Navigation ──────────────────────────────────────────────────────────

## Optional wall half-extents override. If zero (default), uses IsometricRoom._WALL_HALF_X/Y.
## Templates with non-standard shapes can shrink or expand the expected wall boundary.
## These are screen-pixel values (not tile coords).
@export var wall_half_x: int = 0
@export var wall_half_y: int = 0

# ── Valid Zone (Obstacle Placement) ─────────────────────────────────────────────

## Rect2 regions defining areas where obstacles CAN be placed.
## Each rect is in room-local screen coordinates. A candidate point is valid
## if it falls inside ANY of the rects (union logic).
##
## Empty array = fall back to default inner-diamond zone:
##   |x|/WALL_HALF_X + |y|/WALL_HALF_Y <= obstacle_config.inner_scale
@export var valid_zone_rects: Array[Rect2] = []

# ── Spawn Markers ───────────────────────────────────────────────────────────────

## Pre-placed spawn marker positions in room-local coordinates.
## If non-empty, these exact positions are used and _place_spawn_markers() is skipped.
## If empty, spawn markers are auto-placed via the existing centroid+angle algorithm.
## Typically 3 positions spaced around the arena perimeter.
@export var spawn_positions: Array[Vector2] = []

# ── Config Overrides ─────────────────────────────────────────────────────────────

## Optional obstacle config override. null = use IsometricRoom.obstacle_config.
## Templates like "The Maze" can set lower clearance, "The Arena" can set wider spacing.
@export var obstacle_config: ObstacleConfig = null
