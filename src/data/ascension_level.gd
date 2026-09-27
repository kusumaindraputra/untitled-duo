## AscensionLevel — one step of Ascension, the difficulty ladder above Hard Mode (ADR-0052).
##
## Levels stack: Ascension N applies levels 1..N on top of Hard Mode. Each field is
## the change this level adds; neutral values (1.0 / 0) leave that part alone.
## Player-facing text for the level lives in UICopy.ascension_level_descs.
class_name AscensionLevel
extends Resource

## Multiplies the HP of ordinary enemies (elites included).
@export var enemy_hp_mult: float = 1.0
## Multiplies the HP of floor bosses.
@export var boss_hp_mult: float = 1.0
## Multiplies enemy bullet speed, pattern fire rate and laser/mortar telegraph time.
@export var bullet_speed_mult: float = 1.0
@export var fire_rate_mult: float = 1.0
@export var telegraph_mult: float = 1.0
## Extra threat budget and enemy cap per wave.
@export var extra_enemies: int = 0
## Added to every pool's elite chance.
@export var elite_chance_bonus: float = 0.0
## Multiplies every heal Fayde receives (below 1 = less healing).
@export var heal_mult: float = 1.0
## Added to the run's shard multiplier (0.1 = +10 % shards).
@export var shard_bonus: float = 0.0
