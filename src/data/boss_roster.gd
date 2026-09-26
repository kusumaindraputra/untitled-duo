## BossRoster — every floor boss and its variants (ADR-0028).
##
## Authored as assets/data/bosses/boss_roster.tres. debug_game_loop calls pick_all()
## once per run with the run seed and hands the result to WaveManager, which applies
## the variant to the boss as it spawns. BossDirector reads the profiles for the
## arena events.
class_name BossRoster
extends Resource

@export var profiles: Array[BossProfile] = []


## Profile for the boss with EnemyType id [param type_id], or null.
func profile_for(type_id: int) -> BossProfile:
	for p: BossProfile in profiles:
		if p != null and p.boss_type_id == type_id:
			return p
	return null


## The variant of [param profile] this run plays. Same seed, same variant; each boss
## draws from its own stream so their picks are independent. Null when the profile
## has no variants.
static func pick_variant(profile: BossProfile, run_seed: int) -> BossVariant:
	if profile == null or profile.variants.is_empty():
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + profile.boss_type_id * 7919
	return profile.variants[rng.randi_range(0, profile.variants.size() - 1)]


## { boss type id: BossVariant } for every boss that has variants.
func pick_all(run_seed: int) -> Dictionary:
	var out: Dictionary = {}
	for p: BossProfile in profiles:
		var v: BossVariant = pick_variant(p, run_seed)
		if v != null:
			out[p.boss_type_id] = v
	return out
