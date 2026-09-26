## DeathRecap — what killed Fayde, as one line on the run summary (ADR-0032).
##
## Every source that damages Fayde passes a cause Dictionary to
## HealthAndDamage.apply_damage(); H&D keeps the last one in last_player_hit.
## A cause is { "attacker": String, "attack": StringName }: attacker is a raw enemy
## name ("VaultSentinel") or a hazard id (&"hazard_turret"), attack is one of the
## ATTACK_* ids below. Pure static helpers so the recap is unit-testable.
class_name DeathRecap
extends RefCounted

## Attack ids. Bullet attacks are named by the pattern's motion first (homing, wave),
## then its shape; UICopy.death_attack_names maps each id to player text.
const ATTACK_CONTACT: StringName = &"contact"
const ATTACK_SLAM: StringName = &"slam"
const ATTACK_AIMED: StringName = &"aimed"
const ATTACK_FAN: StringName = &"fan"
const ATTACK_RING: StringName = &"ring"
const ATTACK_SPIRAL: StringName = &"spiral"
const ATTACK_HOMING: StringName = &"homing"
const ATTACK_WAVE: StringName = &"wave"
const ATTACK_LASER: StringName = &"laser"
const ATTACK_MORTAR: StringName = &"mortar"
const ATTACK_VENT: StringName = &"vent"
const ATTACK_CLOSING_RING: StringName = &"closing_ring"
const ATTACK_SWEEP: StringName = &"sweep"

## Attacker ids for stage hazards, by HazardSpec.Kind.
const HAZARD_ATTACKERS: Array[StringName] = [
	&"hazard_turret", &"hazard_sweep_laser", &"hazard_floor_zone", &"hazard_closing_ring",
]


## A cause Dictionary for apply_damage().
static func cause(attacker: String, attack: StringName) -> Dictionary:
	return {"attacker": attacker, "attack": attack}


## Attack id for a hit from [param p]: LASER / MORTAR by kind, else homing or wave
## motion, else the volley shape. Null → ATTACK_AIMED.
static func attack_for_pattern(p: BulletPattern) -> StringName:
	if p == null:
		return ATTACK_AIMED
	match p.kind:
		BulletPattern.Kind.LASER:
			return ATTACK_LASER
		BulletPattern.Kind.MORTAR:
			return ATTACK_MORTAR
	match p.motion:
		BulletPattern.Motion.HOMING:
			return ATTACK_HOMING
		BulletPattern.Motion.SINE:
			return ATTACK_WAVE
	match p.shape:
		BulletPattern.Shape.FAN:
			return ATTACK_FAN
		BulletPattern.Shape.RING:
			return ATTACK_RING
		BulletPattern.Shape.SPIRAL:
			return ATTACK_SPIRAL
	return ATTACK_AIMED


## Attack id for a stage hazard of [param kind] hitting Fayde directly (a turret's
## bullets carry their pattern's attack instead).
static func attack_for_hazard(kind: HazardSpec.Kind) -> StringName:
	match kind:
		HazardSpec.Kind.SWEEP_LASER:
			return ATTACK_SWEEP
		HazardSpec.Kind.FLOOR_ZONE:
			return ATTACK_VENT
		HazardSpec.Kind.CLOSING_RING:
			return ATTACK_CLOSING_RING
	return ATTACK_CONTACT


## Attacker id for a stage hazard of [param kind].
static func hazard_attacker(kind: HazardSpec.Kind) -> String:
	var i: int = int(kind)
	return String(HAZARD_ATTACKERS[i]) if i >= 0 and i < HAZARD_ATTACKERS.size() else "hazard"


## Player-facing attacker name: hazard names from UICopy, enemy names spaced
## ("VaultSentinel" → "Vault Sentinel").
static func attacker_name(attacker: String, copy: UICopy) -> String:
	if copy.death_hazard_names.has(attacker):
		return str(copy.death_hazard_names[attacker])
	return Spellbook.display_name(attacker)


## The recap line for [param hit] (H&D last_player_hit): "Killed by X  ·  during Y",
## just the attacker when the attack has no name, or UICopy.death_unknown for {}.
static func line(hit: Dictionary, copy: UICopy) -> String:
	var attacker: String = str(hit.get("attacker", ""))
	if attacker.is_empty():
		return copy.death_unknown
	var who: String = attacker_name(attacker, copy)
	var attack: String = String(hit.get("attack", &""))
	if not copy.death_attack_names.has(attack):
		return copy.death_by_format % who
	return copy.death_by_attack_format % [who, str(copy.death_attack_names[attack])]
