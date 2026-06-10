## NonPrimaryModifier — Wave-scoped modifier contributed by a non-primary Prana type.
##
## When a non-primary Prana type meets the fragment threshold for the current wave
## (GDD Section C Rule 11b), CombinationResolution produces one NonPrimaryModifier
## per qualifying type and stores it in SpellEffect.non_primary_modifiers.
##
## SpellCastingEffects reads these modifiers to apply secondary effects during the
## spell chain. Defaults represent the "not active" state — a freshly constructed
## NonPrimaryModifier with all defaults has no gameplay effect.
##
## This Resource is produced at runtime (not authored in editor), so it is created
## via `.new()` and populated by CombinationResolution (CR Story 003).
class_name NonPrimaryModifier
extends Resource

## Prana type ID of the non-primary type contributing this modifier.
## 0–4. -1 = invalid / unset.
@export var type_id: int = -1

## Tier of this non-primary type (1 / 2 / 3), derived from its fragment count.
@export var tier: int = 1

## Bonus damage added to burn/ignite applications from this modifier.
## 0.0 = no bonus (inactive default).
@export var burn_bonus: float = 0.0

## Seconds added to the active combo window when this modifier fires.
## 0.0 = no extension (inactive default).
@export var window_extension: float = 0.0

## Whether this modifier applies a stun on the final chain attack of the wave.
## false = no stun (inactive default).
@export var final_attack_stun: bool = false

## Multiplier applied to any heal events during the wave.
## 1.0 = no amplification (inactive default). Values > 1.0 amplify healing.
@export var heal_amplifier: float = 1.0

## Duration in seconds added to freeze status applications from this modifier.
## 0.0 = no freeze extension (inactive default).
@export var freeze_duration: float = 0.0

## Percentage slow applied by chill status from this modifier (0.0–1.0 range).
## 0.0 = no chill slow (inactive default).
@export var chill_slow_pct: float = 0.0
