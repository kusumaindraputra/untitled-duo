## BoonConfig — data-driven tuning and copy for the between-room boon reward system.
##
## Holds the values that were previously hardcoded as constants in BoonManager:
## the stat-boon multipliers, the boon catalog (id/title/desc), the reward-screen
## heading, and the Prana-card title/desc templates. Centralizing here makes boon
## balance designer-editable without touching code (coding-standards: data-driven)
## and stages the user-facing strings for a future localization pass (see /localize).
##
## Authored as assets/data/boon_config.tres and consumed by BoonManager via a
## preload const so it is available in headless tests without an Autoload.
##
## NOTE: boon ids in [member boons] must match the dispatch table in
## BoonManager.apply_boon(); an unknown id is a no-op with a warning. The percent
## figures in each desc are authored copy and must be kept in sync with the
## multipliers below by the designer (demo debt — not auto-generated).
class_name BoonConfig
extends Resource

@export_group("Tuning")

## Spell-damage multiplier applied by the "damage" boon (+20%).
@export var damage_mult: float = 1.20

## Spell-damage multiplier applied by the "overcharge" boon (+35%).
@export var overcharge_mult: float = 1.35

## Move-speed multiplier applied by the "move_speed" boon (+15%).
@export var move_speed_mult: float = 1.15

## Dash-cooldown multiplier applied by the "dash_cd" boon (-25%).
@export var dash_cooldown_mult: float = 0.75

## Flat HP restored by the "heal" boon.
@export var heal_amount: float = 40.0

@export_group("Copy")

## Heading shown at the top of the reward-choice overlay.
@export var heading: String = "ROOM CLEARED — Choose a Reward"

## Prana-card title template; %s is replaced with the element's full name.
@export var prana_card_title: String = "Gain %s"

## Prana-card description template; %s is replaced with the element's full name.
@export var prana_card_desc: String = "+1 %s Prana to your bag"

## Stat-boon catalog. Each entry: {id: StringName, title: String, desc: String}.
## The effect is dispatched by id in BoonManager.apply_boon(). Prana cards are not
## listed here — they are generated per Prana type from PranaCatalog at runtime.
@export var boons: Array[Dictionary] = [
	{"id": &"damage",     "title": "Sharpened Cipher", "desc": "+20% spell damage"},
	{"id": &"overcharge", "title": "Overcharge",       "desc": "+35% spell damage"},
	{"id": &"move_speed", "title": "Swift Step",        "desc": "+15% move speed"},
	{"id": &"dash_cd",    "title": "Quick Recovery",    "desc": "-25% dash cooldown"},
	{"id": &"heal",       "title": "Second Wind",       "desc": "Restore 40 HP"},
]
