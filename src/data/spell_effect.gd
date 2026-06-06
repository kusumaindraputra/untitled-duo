## SpellEffect — Wave-scoped spell payload produced by CombinationResolution.
##
## Authored by CombinationResolution via combo_resolved and owned exclusively by
## SpellCastingEffects (ADR-0009). No other system reads aggregate_stat_bonus
## directly — all stat queries go through SpellCastingEffects.get_stat_bonus().
##
## At FP scope: primary_type, primary_tier, base_damage_modifier, and
## combo_attack_count are populated by the CombinationResolution stub.
## aggregate_stat_bonus is empty (no stat modifiers at FP).
class_name SpellEffect
extends Resource

## Primary Prana type driving this wave's spell chain.
## 0=Ashfire, 1=Voidblue, 2=Stormgold, 3=Deepfrost, 4=Verdant, -1=invalid.
## SpellCastingEffects rejects -1 with push_error and stays IDLE.
@export var primary_type: int = -1

## Tier of the primary Prana type (1 / 2 / 3).
## T1 = 1 chain attack, T2 = 2, T3 = 3.
@export var primary_tier: int = 1

## Per-type damage multiplier applied to BASE_SPELL_DAMAGE in Formula 3.
## 1.0 = neutral. Type defaults: Ashfire=1.25, Voidblue=0.90, Stormgold=1.15,
## Deepfrost=0.80, Verdant=0.70.
@export var base_damage_modifier: float = 1.0

## Number of chain attacks for this wave. Mirrors primary_tier at FP scope.
@export var combo_attack_count: int = 1

## Additive stat delta dictionary for the current wave.
## Keys are StringName stat IDs (e.g. &"ASH_DMG", &"FROST_FREEZE_DUR").
## Queried exclusively via SpellCastingEffects.get_stat_bonus() (ADR-0009).
## Untyped Dictionary (not Dictionary[StringName, float]) — typed dicts cannot
## be used with @export in GDScript 4.6.
@export var aggregate_stat_bonus: Dictionary = {}
