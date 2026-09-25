## RoomModifierTuning — data-driven knobs for room variety (ADR-0026).
##
## Combat rooms can roll a modifier when a floor is generated: Challenge (clear it
## without being hit for a bonus) or Cursed (harder enemies, two sigil picks). Rest
## rooms become Wayshrines, where the player may trade HP for a sigil. Authored as
## assets/data/room_modifier_tuning.tres and read through a preload const so tests
## resolve it headless. Design: design/gdd/room-modifiers.md
class_name RoomModifierTuning
extends Resource

@export_group("Rolls")

## Chance a non-entry combat room becomes a Challenge room.
@export_range(0.0, 1.0) var challenge_chance: float = 0.25
## Chance a non-entry combat room becomes a Cursed room (rolled after Challenge).
@export_range(0.0, 1.0) var cursed_chance: float = 0.2
## Most modified rooms on one floor, so a floor never feels all-gimmick.
@export var max_modified_per_floor: int = 2

@export_group("Challenge")

## Cipher Shards paid at run end for each Challenge room cleared without a hit.
@export var challenge_shards: int = 8
## Sigil picks after a flawless Challenge clear (a normal clear gives 1).
@export var challenge_picks: int = 2

@export_group("Cursed")

## Extra threat budget (and enemy cap) in a Cursed room.
@export var cursed_extra_enemies: int = 2
## Added to the elite chance in a Cursed room.
@export var cursed_elite_bonus: float = 0.25
## Multiplier on enemy bullet speed in a Cursed room.
@export var cursed_bullet_speed_mult: float = 1.1
## Sigil picks after clearing a Cursed room.
@export var cursed_picks: int = 2

@export_group("Wayshrine")

## HP spent to inscribe one sigil at a Wayshrine. Refused when it would leave < 1 HP.
@export var wayshrine_hp_cost: int = 20
