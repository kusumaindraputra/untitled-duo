## RoomModifiers — room variety rules (ADR-0026).
##
## When a floor is generated, some combat rooms roll a modifier stored on the graph
## room under the "modifier" key:
##   CHALLENGE — clear it without taking a hit for bonus Cipher Shards and an extra
##               sigil pick. Getting hit only loses the bonus.
##   CURSED    — more enemies, more elites, faster bullets; clearing it gives two picks.
## Rest rooms are always Wayshrines (heal, then optionally trade HP for a sigil), so
## they need no roll. The entry room and elite / boss rooms are never modified.
##
## Pure static rules (no scene tree) so generation and rewards are unit-tested
## headless; debug_game_loop applies them. Tuning: assets/data/room_modifier_tuning.tres.
class_name RoomModifiers
extends RefCounted

const TUNING: RoomModifierTuning = preload("res://assets/data/room_modifier_tuning.tres")

const NONE: int = 0
const CHALLENGE: int = 1
const CURSED: int = 2

## Key on DungeonGraph room dictionaries.
const KEY: String = "modifier"


## Rolls modifiers onto [param graph]'s combat rooms (the entry room excluded), at
## most [member RoomModifierTuning.max_modified_per_floor]. Every room gets the key,
## NONE by default. Deterministic for a seeded [param rng]. Returns how many rooms
## were modified.
static func assign(graph: DungeonGraph, rng: RandomNumberGenerator,
		t: RoomModifierTuning = TUNING) -> int:
	if graph == null:
		return 0
	var entry: int = graph.get_entry_room()
	var modified: int = 0
	for i: int in graph.room_count():
		var room: Dictionary = graph.get_room(i)
		room[KEY] = NONE
		if i == entry or int(room.get("type", -1)) != DungeonGraph.ROOM_TYPE_COMBAT:
			continue
		if modified >= t.max_modified_per_floor:
			continue
		var roll: float = rng.randf()
		if roll < t.challenge_chance:
			room[KEY] = CHALLENGE
		elif roll < t.challenge_chance + t.cursed_chance:
			room[KEY] = CURSED
		if int(room[KEY]) != NONE:
			modified += 1
	return modified


## The modifier of room [param idx] in [param graph] (NONE when unset).
static func of(graph: DungeonGraph, idx: int) -> int:
	if graph == null:
		return NONE
	return int(graph.get_room(idx).get(KEY, NONE))


## Returns a copy of [param cfg] made harder for a Cursed room. [param cfg] is
## shared data and is never changed.
static func apply_cursed(cfg: EnemyPoolConfig, t: RoomModifierTuning = TUNING) -> EnemyPoolConfig:
	if cfg == null:
		return null
	var c: EnemyPoolConfig = cfg.duplicate() as EnemyPoolConfig
	c.threat_budget_min = cfg.threat_budget_min + t.cursed_extra_enemies
	c.threat_budget_max = cfg.threat_budget_max + t.cursed_extra_enemies
	if cfg.enemy_count_max > 0:
		c.enemy_count_max = cfg.enemy_count_max + t.cursed_extra_enemies
	c.elite_chance = clampf(cfg.elite_chance + t.cursed_elite_bonus, 0.0, 1.0)
	c.bullet_speed_mult = cfg.bullet_speed_mult * t.cursed_bullet_speed_mult
	return c


## Sigil picks offered after clearing a room with [param modifier]; a Challenge room
## only pays extra when [param flawless] (no hit taken).
static func picks_for(modifier: int, flawless: bool, t: RoomModifierTuning = TUNING) -> int:
	match modifier:
		CHALLENGE:
			return t.challenge_picks if flawless else 1
		CURSED:
			return t.cursed_picks
	return 1


## Bonus Cipher Shards for clearing a room with [param modifier].
static func bonus_shards(modifier: int, flawless: bool, t: RoomModifierTuning = TUNING) -> int:
	return t.challenge_shards if modifier == CHALLENGE and flawless else 0


## True when Fayde at [param hp] can pay the Wayshrine price and keep at least 1 HP.
static func can_pay_wayshrine(hp: int, t: RoomModifierTuning = TUNING) -> bool:
	return t.wayshrine_hp_cost > 0 and hp - t.wayshrine_hp_cost >= 1
