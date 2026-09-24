## AttackTuning — data-driven knobs for Perfect Cast timing and the Special attack.
##
## Perfect Cast: after each basic attack's cast lock ends, a short rhythm window opens.
## A basic press landing inside it is a Perfect — bonus damage, more Special meter, and
## a Perfect final hit powers up the chain's Cascade. A press before the window (mashing,
## or a press buffered during cast lock) is Rushed — weaker, no meter, no Cascade.
##
## Special: a meter filled by landed basic hits (more on Perfects). When full, the
## special action unleashes a large, Prana-shaped burst around Fayde.
##
## Authored as assets/data/attack_tuning.tres and consumed via a preload const so it
## resolves in headless tests without an Autoload (same pattern as ReactionTuning).
class_name AttackTuning
extends Resource

@export_group("Perfect Cast")

## Seconds after the cast lock ends when the Perfect window opens. Safe range 0.10–0.30.
@export var perfect_window_start: float = 0.18

## Seconds after the cast lock ends when the Perfect window closes. Safe range 0.30–0.60.
@export var perfect_window_end: float = 0.42

## Damage multiplier on a Perfect basic hit. Safe range 1.1–1.6.
@export var perfect_damage_mult: float = 1.3

## Cascade burst multiplier when the chain's final hit is Perfect. Safe range 1.2–2.0.
@export var perfect_cascade_mult: float = 1.5

## Damage multiplier on a Rushed press — one fired while chaining but before the
## Perfect window (mashing, or a press buffered during cast lock). Rushed presses also
## gain no Special meter and never fire the Cascade. Safe range 0.4–0.8.
## At 0.5, mashing (~8 presses/s) roughly matches Perfect rhythm on a single target
## but loses the Special and Cascade entirely (design/gdd/special-attack.md Formula 2).
@export var rushed_damage_mult: float = 0.5

@export_group("Special Meter")

## Meter value required (and spent) to fire the Special.
@export var special_meter_max: float = 100.0

## Meter gained per landed basic attack (once per attack, not per enemy hit).
@export var special_gain_hit: float = 8.0

## Meter gained per landed Perfect basic attack (replaces special_gain_hit).
@export var special_gain_perfect: float = 20.0

@export_group("Special Attack")

## Special damage = BASE_SPELL_DAMAGE × base_damage_modifier × special_damage_mult
## × (1 + special_tier_bonus × (tier − 1)).
@export var special_damage_mult: float = 3.0

## Extra Special damage per primary tier above 1.
@export var special_tier_bonus: float = 0.25

## Radius (px) of the Ashfire, Deepfrost, and Verdant bursts around Fayde.
@export var special_radius: float = 120.0

## Radius (px) of the Voidblue burst and the Stormgold chain's reach.
@export var special_wide_radius: float = 170.0

## Enemies the Stormgold chain lightning strikes (nearest first).
@export var special_chain_targets: int = 4

## Seconds of cast lock after firing the Special.
@export var special_lock_duration: float = 0.35

## Burn duration (s) of the Ashfire Special.
@export var special_burn_duration: float = 3.0

## Blind duration (s) of the Voidblue Special.
@export var special_blind_duration: float = 2.5

## Stun duration (s) of the Stormgold Special.
@export var special_stun_duration: float = 1.2

## Freeze duration (s) of the Deepfrost Special.
@export var special_freeze_duration: float = 2.5

## Fraction of the Special's per-enemy damage the Verdant Special heals Fayde (once).
@export var special_heal_ratio: float = 0.5

## Ashfire Eruption: damage multiplier on enemies already Burning (consumes the fire).
@export var eruption_burning_mult: float = 1.5

## Voidblue Eclipse: pixels each enemy is pulled toward Fayde (never past her).
@export var eclipse_pull_distance: float = 70.0

## Verdant Sanctuary: Regen duration (s) granted to Fayde on top of the instant heal.
@export var sanctuary_regen_duration: float = 3.0

@export_group("Special Infusions")

## Infusions come from the wave's non-primary Prana (SpellEffect.non_primary_modifiers).
## Each value below is the non-primary Tier 1 amount; Tier 2 multiplies it by this.
@export var infusion_tier2_mult: float = 2.0

## Ashfire infusion: Burn duration (s) on every enemy the Special hits.
@export var infusion_burn_duration: float = 2.0

## Voidblue infusion: Blind duration (s) on every enemy the Special hits.
@export var infusion_blind_duration: float = 1.5

## Stormgold infusion: extra nearest enemies the Special arcs to (Stunned on arrival).
@export var infusion_arc_targets: int = 1

## Stormgold infusion: Stun duration (s) on arced enemies.
@export var infusion_arc_stun_duration: float = 0.8

## Deepfrost infusion: Freeze duration (s) on every enemy the Special hits.
@export var infusion_freeze_duration: float = 1.0

## Verdant infusion: flat HP healed to Fayde when the Special fires.
@export var infusion_heal: float = 8.0
