## DuoFoe — enemies that pick a brother (ADR-0058, design/gdd/duo-swap.md Rule 6h).
##
## A duo foe resists one brother, so the room itself asks the player to swap:
##   WARDED   — a ward only Ayden's heavy hits crack. Faith's hits bounce off
##              (wrong_brother_mult) until ward_hits Ayden hits break it, stunning it.
##   FLITTING — too quick for Ayden: his hits glance off, and it hops away when he
##              comes close. Faith's long reach pins it.
## Pure rules; EnemyInstance holds the state and HealthAndDamage applies the multiplier.
class_name DuoFoe
extends RefCounted

enum Kind { NONE = 0, WARDED = 1, FLITTING = 2 }

const TUNING: DuoTuning = preload("res://assets/data/duo_tuning.tres")


## The brother who beats a foe of [param kind] (DuoSwap.NONE for plain enemies).
static func favoured(kind: int) -> int:
	match kind:
		Kind.WARDED: return DuoSwap.Character.AYDEN
		Kind.FLITTING: return DuoSwap.Character.FAITH
	return DuoSwap.NONE


## Damage multiplier for a hit by [param character] on a foe of [param kind]: 1.0 from
## the favoured brother, with no duo, or on a plain enemy; wrong_brother_mult otherwise.
static func hit_mult(kind: int, character: int, t: DuoTuning = TUNING) -> float:
	if kind == Kind.NONE or character == DuoSwap.NONE or character == favoured(kind):
		return 1.0
	return t.wrong_brother_mult


## Rolls a spawn: [param chance_roll] and [param kind_roll] are 0..1 draws.
static func roll(chance_roll: float, kind_roll: float, t: DuoTuning = TUNING) -> int:
	if chance_roll >= t.duo_foe_chance:
		return Kind.NONE
	return Kind.WARDED if kind_roll < t.warded_share else Kind.FLITTING


## True when a flitting foe at [param foe_pos] should hop away from [param character]
## at [param player_pos] now ([param cooldown] seconds left on its last hop).
static func should_flit(kind: int, character: int, foe_pos: Vector2, player_pos: Vector2,
		cooldown: float, t: DuoTuning = TUNING) -> bool:
	return kind == Kind.FLITTING and character == DuoSwap.Character.AYDEN and cooldown <= 0.0 \
		and foe_pos.distance_to(player_pos) <= t.flit_radius
