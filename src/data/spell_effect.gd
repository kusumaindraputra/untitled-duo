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

## Primary Prana type's base_status from PranaCatalog (GDD Rule 11).
## GameEnums.BaseStatus enum value. SC&E applies this on every primary attack
## regardless of non_primary_modifiers content — see AC-CR-29.
## -1 = unset (invalid SpellEffect).
@export var primary_base_status: int = -1

## Two hands (ADR-0057): damage multiplier from Ayden's hand (left column), applied to
## every primary chain hit. 1.0 = empty hand.
@export var hand_power_mult: float = 1.0

## Two hands (ADR-0057): duration multiplier from Faith's hand (right column), applied
## to the core Prana's own status. 1.0 = empty hand.
@export var hand_control_mult: float = 1.0

## Two hands (ADR-0057): true when both hands hold the same number of Prana.
@export var hands_touching: bool = false

## Active non-primary type modifiers for this wave (GDD Rule 11).
## Array[NonPrimaryModifier]. One entry per qualifying non-primary type.
## Empty if no non-primary types meet the tier threshold.
@export var non_primary_modifiers: Array = []

## Active adjacency effects whose spatial conditions were satisfied this wave (GDD Rule 8).
## Array[StringName] effect IDs, e.g. [&"ADJ_DOUBLE_HIT", &"ADJ_PIERCE"].
## SpellCastingEffects applies these during chain execution.
@export var active_adjacency_effects: Array = []

## Active Prana Reactions armed this wave (GDD Rule 16 / Formula 9).
## Array[ReactionDef], one per distinct cardinally-adjacent cross-type pair, ordered
## ascending by (type_a, type_b). Entries consumed by a firing Cascade (Rule 17d) are
## absent. Holds shared read-only ReactionDef instances from the matrix — never mutate.
## SpellCastingEffects applies each by `effect_kind`. Empty if no two different types
## are cardinally adjacent.
@export var active_reactions: Array = []

## The core-anchored Cascade armed this wave (GDD Rule 17 / Formula 10), or null when the
## core has fewer than 2 distinct cardinal-neighbor types. Runtime-only (CascadeEffect is
## RefCounted, not serialized) — not @export. When present, the core↔neighbor pairwise
## reactions it consumes are absent from active_reactions.
var active_cascade: CascadeEffect = null
