## CoreFrame — one Cipher Core the player picks with the core Prana (ADR-0033).
##
## The Prana element decides the spell; the Core decides a run-long passive with a
## trade-off. Every field is a plain multiplier or count that an existing system
## already accepts (the same hooks the sigils use), so a Core adds no new combat
## rules. Neutral values (1.0 / 0) mean "no change". Player-facing name and
## description come from UICopy.core_titles / core_descs by [member id].
##
## Authored inside assets/data/cores/core_roster.tres. Design: design/gdd/cipher-cores.md
class_name CoreFrame
extends Resource

## Stable key for the UICopy name/description and MetaProgress.last_core.
@export var id: StringName = &""
## Multiplies run-wide spell damage (SpellCastingEffects.apply_damage_mult).
@export var spell_damage_mult: float = 1.0
## Multiplies the damage Fayde takes (HealthAndDamage.player_damage_mult, with Assist).
@export var damage_taken_mult: float = 1.0
## Multiplies Fayde's move speed (PlayerController.apply_move_speed_mult).
@export var move_speed_mult: float = 1.0
## Extra dash charges (PlayerController.add_dash_charges).
@export var bonus_dash_charges: int = 0
## Reward cards per sigil offer; 0 keeps SigilConfig.offer_cards.
@export var offer_cards: int = 0
## Free sigil rerolls on each reward screen.
@export var free_rerolls_per_offer: int = 0
## Accent colour of the Core's card on the pick screen.
@export var accent: Color = Color(0.85, 0.85, 0.9)


## Applies the passive for a new run. [param player] takes move speed and dash
## charges, [param spells] the spell-damage multiplier (anything with
## apply_damage_mult), [param sigils] the offer size and free rerolls. Any of them
## may be null; the damage-taken share is read by the run scene through
## [member damage_taken_mult] because Assist also sets it.
func apply(player: Node, spells: Object, sigils: SigilManager) -> void:
	if spells != null and not is_equal_approx(spell_damage_mult, 1.0):
		spells.call(&"apply_damage_mult", spell_damage_mult)
	if is_instance_valid(player):
		if not is_equal_approx(move_speed_mult, 1.0) and player.has_method(&"apply_move_speed_mult"):
			player.call(&"apply_move_speed_mult", move_speed_mult)
		if bonus_dash_charges > 0 and player.has_method(&"add_dash_charges"):
			player.call(&"add_dash_charges", bonus_dash_charges)
	if sigils != null:
		if offer_cards > 0:
			sigils.offer_cards = offer_cards
		sigils.free_rerolls_per_offer = maxi(free_rerolls_per_offer, 0)
