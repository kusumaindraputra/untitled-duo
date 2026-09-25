## ObstacleConfig — data-driven debris/obstacle placement parameters.
##
## Each room template can have its own ObstacleConfig.tres, enabling different
## obstacle densities and clearance constraints per template or layer.
##
## Consumed by IsometricRoom._generate_debris_positions().
## GDD: design/gdd/level-generation.md
class_name ObstacleConfig
extends Resource

## Minimum obstacles generated per room.
@export var count_min: int = 5

## Maximum obstacles generated per room.
@export var count_max: int = 9

## Inner zone fraction (0.82 = inner 82 % of the diamond/sampling area).
@export var inner_scale: float = 0.82

## Minimum distance from arena origin (player start area), in pixels.
@export var min_center_dist: float = 90.0

## Minimum distance from any spawn marker, in pixels.
@export var min_spawn_dist: float = 110.0

## Minimum gap between any two obstacles, in pixels.
@export var min_between_dist: float = 75.0

## Maximum rejection-sampling attempts per obstacle slot.
@export var place_attempts: int = 80

# ── Pillars (full cover, ADR-0020) ────────────────────────────────────────────

## Minimum full-cover pillars per room. 0 = no pillars (default, legacy behaviour).
@export var pillar_count_min: int = 0

## Maximum full-cover pillars per room.
@export var pillar_count_max: int = 0

## Enemy bullets a pillar absorbs before it crumbles (a laser counts as
## CoverPillar.LASER_HITS). Cover buys time, it does not solve the room.
@export var pillar_hits: int = 14

## Pillar collision radius in pixels.
@export var pillar_radius: float = 20.0

## Minimum gap between two pillars, in pixels. Keeps cover spread across the room.
@export var pillar_min_between_dist: float = 150.0
