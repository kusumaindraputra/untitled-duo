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

## Density cap relative to room geometry: max enemies per spawn marker. 0 = disabled.
## The effective wave size is also limited to (spawn_marker_count * this), so small
## rooms never get visually overwhelmed regardless of threat budget. Combined with
## enemy_count_max, the smaller of the two caps wins. Guaranteed/min_count types are
## never trimmed below their required counts.
@export var max_enemies_per_marker: int = 0

## ADR-0018 — chance (0..1) that each spawned non-boss enemy is promoted to an elite.
## ELITE rooms add BulletHellTuning.elite_room_bonus on top.
@export_range(0.0, 1.0) var elite_chance: float = 0.0

## ADR-0018 — the wave is split into this many groups. Group 0 spawns at combat start;
## each later group arrives as reinforcements while the fight is still going.
## 1 = the whole wave spawns at once (pre-ADR-0018 behaviour).
@export_range(1, 5) var reinforcement_groups: int = 1

## ADR-0018 — the next reinforcement group arrives once this many enemies (or fewer)
## are still alive on the field.
@export var reinforcement_trigger_alive: int = 2

## ADR-0019 — per-floor difficulty curve. Multiplies the speed of every bullet enemies
## fire in rooms using this config. 1.0 = authored pattern speed.
@export_range(0.5, 2.0) var bullet_speed_mult: float = 1.0

## ADR-0019 — multiplies how fast pattern cooldowns tick (1.2 = 20 % more volleys).
@export_range(0.5, 2.0) var fire_rate_mult: float = 1.0

## ADR-0019 — multiplies laser and mortar telegraph time (0.85 = 15 % less warning).
@export_range(0.3, 1.5) var telegraph_mult: float = 1.0

## ADR-0052 — multiplies the HP of every ordinary enemy spawned from this config
## (Ascension). Elite and boss-variant multipliers stack on top.
@export_range(0.5, 4.0) var enemy_hp_mult: float = 1.0

## ADR-0052 — multiplies the HP of bosses spawned from this config (Ascension).
@export_range(0.5, 4.0) var boss_hp_mult: float = 1.0
