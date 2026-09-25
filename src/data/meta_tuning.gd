## MetaTuning — data-driven knobs for progress that carries between runs (ADR-0025).
##
## Covers the Cipher Shard payout at the end of a run, the Heirloom unlocks bought
## with shards (each Heirloom is an existing stat sigil granted at run start), and
## Hard Mode. Authored as assets/data/meta_tuning.tres and consumed via a preload
## const so it resolves in headless tests without an Autoload.
## Design: design/gdd/meta-progression.md
class_name MetaTuning
extends Resource

@export_group("Cipher Shards")

## Shards per floor reached (floor 1 counts, so a floor-1 death still pays this once).
@export var shards_per_floor: int = 10
## Shards per room cleared.
@export var shards_per_room: int = 3
## One shard per this many enemies slain (integer division).
@export var kills_per_shard: int = 5
## Flat bonus for winning the run.
@export var win_bonus: int = 60
## Multiplier on the whole payout when the run was played on Hard Mode.
@export var hard_mode_shard_mult: float = 1.5

@export_group("Heirlooms")

## Stat sigils that can be unlocked as Heirlooms, in menu order. Titles and
## descriptions come from SigilConfig.stat_sigils, so they are not duplicated here.
@export var heirloom_ids: Array[StringName] = [&"move_speed", &"damage", &"graze_ring", &"dash_charge", &"dash_cut"]
## Shard cost of each Heirloom, parallel to heirloom_ids.
@export var heirloom_costs: Array[int] = [30, 45, 50, 70, 90]

@export_group("Hard Mode")

## Wins needed before Hard Mode can be switched on.
@export var hard_mode_wins_required: int = 1
## Multipliers applied on top of every floor's EnemyPoolConfig while Hard Mode is on.
@export var hard_bullet_speed_mult: float = 1.15
@export var hard_fire_rate_mult: float = 1.2
## Below 1 means less warning before lasers and mortars.
@export var hard_telegraph_mult: float = 0.85
## Extra enemies per wave on top of the pool's own cap (0 = unchanged).
@export var hard_extra_enemies: int = 2
## Chance added to each pool's elite_chance.
@export var hard_elite_chance_bonus: float = 0.1


## Cost of [param id], or -1 when it is not an Heirloom.
func cost_of(id: StringName) -> int:
	var i: int = heirloom_ids.find(id)
	return heirloom_costs[i] if i >= 0 and i < heirloom_costs.size() else -1
