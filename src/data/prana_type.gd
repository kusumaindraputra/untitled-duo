## PranaType — Data schema for a single Prana element type.
##
## Authored as .tres files in the Godot Inspector (Story 004) and loaded at
## runtime via PranaCatalog.get_type(id) which returns duplicate_deep() — see ADR-0008.
##
## Rules (ADR-0008 + control-manifest Foundation layer):
##   - @export var only — @export const is invalid GDScript syntax.
##   - icon and audio_signature are null until .tres is authored (Story 004).
##   - Do NOT add targeting_shape, cast_shape, spell_shape, resonance, or
##     resonance_weight — forbidden by AC-PD-06 and AC-PD-07.
##   - All @export enum fields serialize as integers in .tres (not string names).
##     See ADR-0006 and AC-4 roundtrip test.
class_name PranaType
extends Resource

@export_group("Identity")

## Stable integer ID. Assigned by the data table; never hardcode in .tres files.
## Default 0 matches AC-1 spec sentinel.
@export var id: int = 0

## Human-readable display name shown in UI (e.g. "Fire", "Shadow").
@export var name: String = ""

## Element label for lore/tooltip display only (e.g. "flame", "void").
@export var element: String = ""

## One-sentence narrative phrase capturing the essence of this Prana type.
@export var semantic_identity: String = ""

@export_group("Visual / Audio")

## Primary color used for particle tints, grid slot highlights, and damage numbers.
@export var color: Color = Color.WHITE

## 8×8 px silhouette icon for grid tile and HUD display.
## Null until .tres is authored (Story 004) — PranaCatalog validates non-null at startup.
@export var icon: Texture2D

## Shape of the on-hit VFX burst spawned at the target on cast.
@export var vfx_burst_shape: GameEnums.VfxBurstShape = GameEnums.VfxBurstShape.BURST_FLAME

## Audio cue played when a spell of this Prana type is cast.
## Null until .tres is authored (Story 004) — PranaCatalog validates non-null at startup.
@export var audio_signature: AudioStream

## Animation variant played on the caster character when a spell fires.
@export var cast_animation: GameEnums.CastAnimation = GameEnums.CastAnimation.CAST_THRUST

@export_group("Combat")

## Elemental damage type used by damage formulas and Elemental Affiliation.
@export var damage_class: GameEnums.DamageClass = GameEnums.DamageClass.FIRE

## Status effect naturally applied by single-type casts of this element.
@export var base_status: GameEnums.BaseStatus = GameEnums.BaseStatus.BURN

## Multiplier applied to base_damage on a direct hit.
## 1.0 = neutral. Designer range 0.5–2.0 enforced by Inspector hint.
@export_range(0.5, 2.0, 0.05) var base_damage_modifier: float = 1.0
