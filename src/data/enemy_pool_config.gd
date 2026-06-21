## EnemyPoolConfig — data-driven enemy composition parameters.
##
## Each layer can have its own EnemyPoolConfig.tres, enabling different enemy
## palettes per layer (e.g., Layer 1 has no RUSHER, Layer 2 introduces SHOOTER).
##
## Consumed by WaveManager._build_wave_composition().
## GDD: design/gdd/level-generation.md
class_name EnemyPoolConfig
extends Resource

## Lower bound of random threat budget drawn once per room.
@export var threat_budget_min: int = 10

## Upper bound of random threat budget drawn once per room.
@export var threat_budget_max: int = 18

## Threat cost per type ID. Key = type_id (int), Value = cost (int).
@export var threat_cost: Dictionary = { 0: 1, 1: 2, 2: 1, 4: 1 }

## All type IDs available in the random pool-fill phase.
@export var enemy_pool: Array[int] = [0, 1, 2, 4]

## Type IDs guaranteed to appear at least once (subtracted from budget first).
@export var guaranteed_types: Array[int] = [0, 2]

## Minimum spawn count per type. Key = type_id (int), Value = minimum count (int).
## Applied after guaranteed_types; adds extra copies if current count is below minimum.
## Budget is reduced for each extra copy added.
@export var min_counts: Dictionary = {}

## Hard cap on the number of enemies in a single wave. 0 = uncapped (default).
## Applied after pool-fill, before spawn — guaranteed types are never trimmed.
@export var enemy_count_max: int = 0
