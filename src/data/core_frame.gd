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
## ADR-0058 duo Cores: Ayden's and Faith's own hit damage (SpellCastingEffects
## .apply_brother_damage_mult) and the swap cooldown (PlayerController
## .apply_swap_cooldown_mult). A duo Core leans the run toward one brother or the swap.
@export var ayden_damage_mult: float = 1.0
@export var faith_damage_mult: float = 1.0
@export var swap_cooldown_mult: float = 1.0
## Multiplies the Link Reaction and Link Burst reach (SpellCastingEffects.apply_link_radius_mult).
@export var link_radius_mult: float = 1.0
## Accent colour of the Core's card on the pick screen.
@export var accent: Color = Color(0.831, 0.788, 0.722)


## Applies the passive for a new run. [param player] takes move speed and dash
## charges, [param spells] the spell-damage multiplier (anything with
## apply_damage_mult), [param sigils] the offer size and free rerolls. Any of them
## may be null; the damage-taken share is read by the run scene through
## [member damage_taken_mult] because Assist also sets it.
func apply(player: Node, spells: Object, sigils: SigilManager) -> void:
	if spells != null and not is_equal_approx(spell_damage_mult, 1.0):
		spells.call(&"apply_damage_mult", spell_damage_mult)
	if spells != null and spells.has_method(&"apply_brother_damage_mult"):
		if not is_equal_approx(ayden_damage_mult, 1.0):
			spells.call(&"apply_brother_damage_mult", DuoSwap.Character.AYDEN, ayden_damage_mult)
		if not is_equal_approx(faith_damage_mult, 1.0):
			spells.call(&"apply_brother_damage_mult", DuoSwap.Character.FAITH, faith_damage_mult)
	if spells != null and not is_equal_approx(link_radius_mult, 1.0) and spells.has_method(&"apply_link_radius_mult"):
		spells.call(&"apply_link_radius_mult", link_radius_mult)
	if is_instance_valid(player):
		if not is_equal_approx(move_speed_mult, 1.0) and player.has_method(&"apply_move_speed_mult"):
			player.call(&"apply_move_speed_mult", move_speed_mult)
		if bonus_dash_charges > 0 and player.has_method(&"add_dash_charges"):
			player.call(&"add_dash_charges", bonus_dash_charges)
		if not is_equal_approx(swap_cooldown_mult, 1.0) and player.has_method(&"apply_swap_cooldown_mult"):
			player.call(&"apply_swap_cooldown_mult", swap_cooldown_mult)
	if sigils != null:
		if offer_cards > 0:
			sigils.offer_cards = offer_cards
		sigils.free_rerolls_per_offer = maxi(free_rerolls_per_offer, 0)
