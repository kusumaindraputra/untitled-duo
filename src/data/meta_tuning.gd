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

## Sigils (stat or behaviour) that can be unlocked as Heirlooms, in menu order. Titles and
## descriptions come from SigilConfig.stat_sigils, so they are not duplicated here.
@export var heirloom_ids: Array[StringName] = [&"move_speed", &"damage", &"graze_ring", &"dash_charge", &"dash_cut",
	&"dash_cd", &"ember_wake", &"static_halo", &"siphon", &"riposte"]
## Shard cost of each Heirloom, parallel to heirloom_ids.
@export var heirloom_costs: Array[int] = [30, 45, 50, 70, 90, 60, 80, 90, 110, 130]
## Memory fragments needed before each Heirloom can be bought, parallel to heirloom_ids
## (F4: a new pair every 3 memories). 0 = available from the start.
@export var heirloom_memory_gates: Array[int] = [0, 0, 0, 0, 0, 3, 3, 6, 6, 9]

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


## Memories needed before [param id] can be bought (0 when ungated or unknown).
func memories_needed(id: StringName) -> int:
	var i: int = heirloom_ids.find(id)
	return heirloom_memory_gates[i] if i >= 0 and i < heirloom_memory_gates.size() else 0


## Heirlooms whose memory gate lies in (from, to]: the ones revealed by recovering
## memories from [param from] up to [param to].
func heirlooms_revealed_between(from: int, to: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in heirloom_ids:
		var gate: int = memories_needed(id)
		if gate > from and gate <= to:
			out.append(id)
	return out


## Cost of [param id], or -1 when it is not an Heirloom.
func cost_of(id: StringName) -> int:
	var i: int = heirloom_ids.find(id)
	return heirloom_costs[i] if i >= 0 and i < heirloom_costs.size() else -1
