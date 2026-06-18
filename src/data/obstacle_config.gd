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
