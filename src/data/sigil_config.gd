## SigilConfig — data-driven tuning and copy for the between-room sigil reward system.
##
## Holds the values that were previously hardcoded as constants in SigilManager:
## the stat-sigil multipliers, the sigil catalog (id/title/desc), the reward-screen
## heading, and the Prana-card title/desc templates. Centralizing here makes sigil
## balance designer-editable without touching code (coding-standards: data-driven)
## and stages the user-facing strings for a future localization pass (see /localize).
##
## Authored as assets/data/sigil_config.tres and consumed by SigilManager via a
## preload const so it is available in headless tests without an Autoload.
##
## NOTE: sigil ids in [member sigils] must match the dispatch table in
## SigilManager.apply_sigil(); an unknown id is a no-op with a warning. The percent
## figures in each desc are authored copy and must be kept in sync with the
## multipliers below by the designer (demo debt — not auto-generated).
class_name SigilConfig
extends Resource

@export_group("Tuning")

## Spell-damage multiplier applied by the "damage" sigil (+20%).
@export var damage_mult: float = 1.20

## Spell-damage multiplier applied by the "overcharge" sigil (+35%).
@export var overcharge_mult: float = 1.35

## Move-speed multiplier applied by the "move_speed" sigil (+15%).
@export var move_speed_mult: float = 1.15

## Dash-cooldown multiplier applied by the "dash_cd" sigil (-25%).
@export var dash_cooldown_mult: float = 0.75

## Flat HP restored by the "heal" sigil.
@export var heal_amount: float = 40.0

## ADR-0019 — extra dash charges granted by the "dash_charge" sigil.
@export var dash_charge_bonus: int = 1

## ADR-0019 — graze ring multiplier applied by the "graze_ring" sigil (+40%).
@export var graze_radius_mult: float = 1.4

## ADR-0019 — radius (px) of enemy bullets a dash cuts with the "dash_cut" sigil.
@export var dash_cut_radius: float = 26.0

@export_group("Offer and Reroll (ADR-0033)")

## Reward cards shown per offer. A Core (ADR-0033) may raise it for the run.
@export var offer_cards: int = 3
## HP price of the first bought reroll in a run.
@export var reroll_hp_cost: int = 6
## Added to the reroll price after each bought reroll, so rerolling stays a real cost.
@export var reroll_hp_step: int = 4

@export_group("Behaviour Sigils")

## Ember Wake: a burning patch is dropped every this many px of dash travel.
@export var ember_spacing: float = 26.0
## Ember Wake: patch radius (px) and lifetime (s).
@export var ember_radius: float = 22.0
@export var ember_duration: float = 1.6
## Ember Wake: damage per tick to each enemy in a patch, per stack.
@export var ember_damage: float = 4.0
## Ember Wake: seconds between damage ticks.
@export var ember_tick_sec: float = 0.3

## Static Halo: a graze zaps the nearest enemy within this range (px).
@export var static_range: float = 200.0
## Static Halo: zap damage per stack.
@export var static_damage: float = 9.0
## Static Halo: minimum seconds between zaps.
@export var static_cooldown: float = 0.15

## Afterglow: fraction of the Special meter refunded after a Special, per stack (capped).
@export var afterglow_refund: float = 0.3
@export var afterglow_refund_cap: float = 0.75

## Unravel: enemy bullets within this radius of a kill are cancelled (+50 % per extra stack).
@export var unravel_radius: float = 70.0

## Siphon: every this many kills heals siphon_heal HP per stack.
@export var siphon_kills: int = 8
@export var siphon_heal: float = 6.0

## Riposte: a Perfect Dodge blasts enemies within this radius for this damage per stack.
@export var riposte_radius: float = 110.0
@export var riposte_damage: float = 22.0

## Metronome: a Perfect Cast at streak >= metronome_streak heals this much per stack.
@export var metronome_streak: int = 3
@export var metronome_heal: float = 3.0
## Duo sigils (ADR-0058).
## Wide Link: multiplier on the Link Reaction and Link Burst radius per stack.
@export var wide_link_mult: float = 1.5
## Deep Heartbeat: the shared heartbeat and its Resonance window stretch by this per
## stack, and a Resonance pays deep_heart_meter_mult × its Special meter.
@export var deep_heart_mult: float = 1.4
@export var deep_heart_meter_mult: float = 2.0
## Echo Brother: on each swap the benched brother's afterimage strikes the nearest enemy
## within echo_range px for echo_damage × stacks, leaving his Link mark.
@export var echo_damage: float = 14.0
@export var echo_range: float = 220.0
## Text colour of behaviour-sigil cards in the reward overlay.
@export var behaviour_card_color: Color = Color(1.0, 0.78, 0.35)

@export_group("Copy")

## Heading shown at the top of the reward-choice overlay.
@export var heading: String = "ROOM CLEARED — Inscribe a Sigil"

## Prana-card title template; %s is replaced with the element's full name.
@export var prana_card_title: String = "Gain %s"

## Prana-card description template; %s is replaced with the element's full name.
@export var prana_card_desc: String = "+1 %s Prana to your bag"

## Stat-sigil catalog. Each entry: {id: StringName, title: String, desc: String}.
## The effect is dispatched by id in SigilManager.apply_sigil(). Prana sigils are not
## listed here — they are generated per Prana type from PranaCatalog at runtime.
@export var sigils: Array[Dictionary] = [
	{"id": &"damage",     "title": "Sharpened Cipher", "desc": "+20% spell damage"},
	{"id": &"overcharge", "title": "Overcharge",       "desc": "+35% spell damage"},
	{"id": &"move_speed", "title": "Swift Step",        "desc": "+15% move speed"},
	{"id": &"dash_cd",    "title": "Quick Recovery",    "desc": "-25% dash cooldown"},
	{"id": &"heal",       "title": "Second Wind",       "desc": "Restore 40 HP"},
	{"id": &"dash_charge", "title": "Third Step",       "desc": "+1 dash charge"},
	{"id": &"dash_cut",   "title": "Severing Dash",     "desc": "Dashing cuts through enemy bullets"},
	{"id": &"graze_ring", "title": "Wide Halo",         "desc": "+40% graze ring"},
	{"id": &"ember_wake",  "title": "Ember Wake",       "desc": "Dashing leaves burning ground", "behaviour": true},
	{"id": &"static_halo", "title": "Static Halo",      "desc": "Grazing a bullet zaps the nearest enemy", "behaviour": true},
	{"id": &"afterglow",   "title": "Afterglow",        "desc": "A Special refunds 30% of its meter", "behaviour": true},
	{"id": &"unravel",     "title": "Unravel",          "desc": "Kills erase nearby enemy bullets", "behaviour": true},
	{"id": &"siphon",      "title": "Siphon",           "desc": "Every 8 kills restore 6 HP", "behaviour": true},
	{"id": &"riposte",     "title": "Riposte",          "desc": "A Perfect Dodge blasts enemies around you", "behaviour": true},
	{"id": &"metronome",   "title": "Metronome",        "desc": "Perfect Casts on a 3+ streak restore HP", "behaviour": true},
	{"id": &"wide_link",   "title": "Wide Link",        "desc": "+50% LINK and Link Burst reach"},
	{"id": &"deep_heart",  "title": "Deep Heartbeat",   "desc": "A slower heartbeat, easier RESONANCE, double its meter"},
	{"id": &"echo_brother", "title": "Echo Brother",    "desc": "Each swap, the brother leaving strikes once and marks the foe for LINK", "behaviour": true},
]
