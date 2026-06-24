## ReactionDef — A single Prana Reaction in the data-driven Reaction Matrix (GDD Rule 16 / Formula 9).
##
## One ReactionDef exists per unordered cross-type Prana pair (10 at MVP). The matrix
## is keyed by the sorted (type_a, type_b) pair and built once at load from the .tres
## files in res://assets/data/reactions/ (ADR-0016). A reaction arms when its two types
## are cardinally adjacent on the combination grid.
##
## Authored as .tres files in the Godot Inspector and consumed read-only by
## CombinationResolution and SpellCastingEffects. SC&E switches on `effect_kind` to
## route application (Formula 9). Never mutated at runtime — the same shared instance
## is referenced from SpellEffect.active_reactions.
##
## Rules (ADR-0016 / control-manifest Foundation layer):
##   - @export var only — @export const is invalid GDScript syntax.
##   - type_a < type_b always (lower type id first); the matrix loader keys on this.
##   - effect_kind serializes as an integer in .tres (GameEnums.ReactionKind value).
class_name ReactionDef
extends Resource

## Stable identifier for this reaction (e.g. &"REACT_THERMAL_SHOCK").
## Used by the matrix loader for diagnostics and by the HUD/preview for lookup.
@export var id: StringName = &""

## Human-readable display name shown in the prep preview and Combat HUD.
@export var name: String = ""

## Lower type id of the reacting pair (0–4). type_a < type_b by construction.
@export var type_a: int = -1

## Higher type id of the reacting pair (0–4). type_b > type_a by construction.
@export var type_b: int = -1

## Routes SpellCastingEffects application logic for this reaction (Formula 9).
## Serializes as an integer in .tres (ADR-0006 enum stability).
@export var effect_kind: GameEnums.ReactionKind = GameEnums.ReactionKind.THERMAL_SHOCK

## Primary tuning value for the reaction's effect (see GDD Tuning Knobs table).
## Interpretation is per-reaction — a bonus fraction, duration, range, or multiplier.
@export var magnitude: float = 0.0

## One-line tooltip text describing the reaction in the preview.
@export var description: String = ""
