## ReactionTuning — data-driven secondary knobs for applying Prana Reactions and Cascades.
##
## Each ReactionDef carries its own primary `magnitude` (GDD Formula 9). The values here
## are the extra knobs the GDD Tuning Knobs table lists alongside them (Detonate radius,
## Surge heal) plus every Cascade facet knob (Formula 10). SpellCastingEffects reads them
## when it applies `SpellEffect.active_reactions` and `SpellEffect.active_cascade`.
##
## Authored as assets/data/reaction_tuning.tres and consumed via a preload const so it
## resolves in headless tests without an Autoload (same pattern as SigilConfig).
class_name ReactionTuning
extends Resource

@export_group("Reactions")

## Radius (px) of the Detonate kill-burst (REACT_DETONATE_RADIUS). Safe range 40–120.
@export var detonate_radius: float = 70.0

## Flat HP Surge heals Fayde on every chain hit (REACT_SURGE_HEAL). Safe range 1–5.
@export var surge_heal: float = 2.0

## Burn duration (s) Wildfire spreads to its second target (fixed per GDD Formula 9).
@export var wildfire_burn_duration: float = 2.0

@export_group("Cascade")

## Radius (px) of the Ashfire nova, Deepfrost field, and Verdant facet reach (CASCADE_AOE_RADIUS).
@export var aoe_radius: float = 90.0

## Radius (px) of the Voidblue "collapse" — the wide-cluster lead shape.
@export var collapse_radius: float = 160.0

## Extra enemies a Stormgold-lead chain burst jumps to after the primary target.
@export var lead_chain_targets: int = 2

## Blind duration (s) the Voidblue facet applies (CASCADE_BLIND_DUR).
@export var blind_duration: float = 1.0

## Freeze duration (s) the Deepfrost facet and Deepfrost-lead field apply (CASCADE_FREEZE_DUR).
@export var freeze_duration: float = 1.0

## Burn duration (s) the Ashfire facet applies (standard Burn).
@export var burn_duration: float = 2.0

## Extra enemies the Stormgold facet arcs to (CASCADE_ARC_TARGETS).
@export var arc_targets: int = 1

## Fraction of burst damage healed to Fayde by the Verdant facet or a Verdant lead (CASCADE_LIFESTEAL).
@export var lifesteal: float = 0.15
