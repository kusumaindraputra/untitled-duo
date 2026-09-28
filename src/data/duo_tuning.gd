## DuoTuning — knobs for the Ayden / Faith duo swap (ADR-0058).
##
## Ayden and Faith are two brothers the player swaps between in combat. Ayden hits
## hard at short range and is sturdy; Faith reaches far, holds status longer and is the
## only one who dashes. Each takes his palm Prana as his core, the other's element on an
## enemy sets off a Link Reaction, and a swap on the shared heartbeat Resonates. Authored as
## assets/data/duo_tuning.tres and read through a preload const, like PaceTuning.
## Design: design/gdd/duo-swap.md
class_name DuoTuning
extends Resource

@export_group("Swap")

## Seconds between swaps. Safe range 0.4–2.0. Short, because swapping to Faith is
## Ayden's only way out of a bullet (he cannot dash).
@export_range(0.1, 5.0, 0.05) var swap_cooldown_sec: float = 0.6
## Multiplier on the swap cooldown while the grid's hands touch (ADR-0057). 1.0 = off.
@export_range(0.1, 1.0, 0.05) var touch_swap_cooldown_mult: float = 0.7
## Seconds of i-frames the tagging-in brother gets. Safe range 0.1–0.35.
@export_range(0.0, 1.0, 0.01) var swap_iframe_sec: float = 0.2
## Radius (px) of the tag-in effect: Ayden's Breach push, Faith's Anchor bullet wipe.
@export_range(0.0, 300.0, 1.0) var tag_in_radius: float = 70.0
## Push distance (px) of Ayden's Breach.
@export_range(0.0, 200.0, 1.0) var breach_knockback: float = 60.0
## Tag-in radius and push multiplier after a Perfect Swap.
@export_range(1.0, 4.0, 0.1) var perfect_swap_tag_in_mult: float = 2.0

@export_group("Ayden")

## Hit damage multiplier while Ayden is out. Safe range 1.0–1.4.
@export_range(0.5, 2.0, 0.01) var ayden_damage_mult: float = 1.15
## Cast range multiplier (shorter reach). Safe range 0.6–1.0.
@export_range(0.3, 1.5, 0.01) var ayden_range_mult: float = 0.85
## Move speed multiplier (slightly heavier). Safe range 0.8–1.0.
@export_range(0.5, 1.5, 0.01) var ayden_speed_mult: float = 0.92
## Multiplier on damage Ayden takes (he cannot dash, so he is sturdier). Safe range
## 0.6–0.9.
@export_range(0.1, 1.0, 0.01) var ayden_damage_taken_mult: float = 0.75
## Multiplier on knock-back Ayden takes from contact hits. 0 = he never staggers.
@export_range(0.0, 1.0, 0.05) var ayden_knockback_mult: float = 0.0

@export_group("Faith")

## Hit damage multiplier while Faith is out. Safe range 0.6–1.0.
@export_range(0.3, 2.0, 0.01) var faith_damage_mult: float = 0.85
## Cast range multiplier (longer reach). Safe range 1.2–1.8.
@export_range(0.5, 3.0, 0.01) var faith_range_mult: float = 1.45
## Move speed multiplier.
@export_range(0.5, 1.5, 0.01) var faith_speed_mult: float = 1.0
## Only Faith can dash; this is her dash's extra. Radius (px) of enemy bullets it wipes (like the dash-cut sigil).
@export_range(0.0, 100.0, 1.0) var faith_dash_cut_radius: float = 24.0

@export_group("Palm faces")

## Each brother takes the Prana in his palm (Ayden: middle-left slot, Faith:
## middle-right) as his core, so the grid has two faces: spell, tier, reactions and
## Cascade change with the swap. Off = both brothers cast the centre Prana.
@export var palm_faces: bool = true

@export_group("Link Reaction")

## Seconds a hit's element stays on an enemy for the other brother to react with.
@export_range(0.5, 10.0, 0.1) var link_mark_sec: float = 3.0
## Link Reaction burst damage, as a multiple of the base spell damage (20).
@export_range(0.0, 5.0, 0.05) var link_damage_mult: float = 1.5
## Radius (px) of the burst around the reacting enemy.
@export_range(0.0, 300.0, 1.0) var link_radius: float = 60.0
## Damage share the burst deals to other enemies in the radius.
@export_range(0.0, 1.0, 0.05) var link_splash_mult: float = 0.5
## Seconds of each element's status the burst applies (Burn, Blind, Freeze; Stun is
## a third of it). Verdant heals Fayde instead.
@export_range(0.0, 5.0, 0.1) var link_status_sec: float = 1.5
## Special meter the Link Reaction pays.
@export_range(0.0, 100.0, 1.0) var link_meter_gain: float = 12.0

@export_group("Heartbeat")

## Seconds between beats of the brothers' shared core.
@export_range(0.3, 3.0, 0.05) var heartbeat_sec: float = 1.0
## Seconds either side of a beat in which a swap resonates. Generous for young players.
@export_range(0.02, 0.5, 0.01) var resonance_window_sec: float = 0.15
## Seconds a Resonance keeps the next basic cast Perfect whatever its timing.
@export_range(0.0, 5.0, 0.1) var resonance_perfect_sec: float = 1.5
## Special meter a Resonance pays.
@export_range(0.0, 100.0, 1.0) var resonance_meter_gain: float = 10.0

@export_group("Link Burst")

## The Special also fires a Link Burst when the two brothers' cores differ: both
## brothers appear and their two elements react at full Special size. Off = plain Special.
@export var link_burst: bool = true
## Burst damage per enemy, as a multiple of the Special's own damage.
@export_range(0.0, 3.0, 0.05) var link_burst_damage_mult: float = 0.8
## Burst radius, as a multiple of AttackTuning.special_radius.
@export_range(0.5, 3.0, 0.05) var link_burst_radius_mult: float = 1.3
## Status seconds, as a multiple of link_status_sec.
@export_range(0.0, 5.0, 0.1) var link_burst_status_mult: float = 2.0
## Pull (px) toward the burst when Voidblue is in the pair.
@export_range(0.0, 200.0, 1.0) var link_burst_pull: float = 40.0
## Seconds the benched brother stands beside Fayde for the burst.
@export_range(0.1, 3.0, 0.05) var partner_show_sec: float = 0.6

@export_group("Severed link")

## Hits the player lands to reconnect a link a boss severed (floor-bosses.md).
@export_range(1, 30, 1) var sever_reconnect_hits: int = 6
## Special meter the reconnection pays (the brothers find each other again).
@export_range(0.0, 100.0, 1.0) var relink_meter_gain: float = 25.0

@export_group("Duo foes")

## Chance a non-boss enemy spawns as a duo foe (warded or flitting). 0 = off.
@export_range(0.0, 1.0, 0.01) var duo_foe_chance: float = 0.22
## Share of duo foes that are warded (Ayden's foes); the rest flit (Faith's foes).
@export_range(0.0, 1.0, 0.05) var warded_share: float = 0.5
## Damage multiplier for a hit from the brother the foe resists.
@export_range(0.0, 1.0, 0.05) var wrong_brother_mult: float = 0.35
## Ayden hits that break a ward; the foe is then a plain enemy.
@export_range(1, 20, 1) var ward_hits: int = 3
## Seconds a broken ward stuns its enemy.
@export_range(0.0, 3.0, 0.05) var ward_break_stun_sec: float = 1.0
## A flitting foe hops away when Ayden comes within this many px.
@export_range(0.0, 300.0, 1.0) var flit_radius: float = 80.0
## Hop distance (px) of a flitting foe.
@export_range(0.0, 300.0, 1.0) var flit_distance: float = 90.0
## Seconds between hops.
@export_range(0.1, 10.0, 0.1) var flit_cooldown_sec: float = 1.4
## Seconds between "swap" hints over the same foe.
@export_range(0.1, 10.0, 0.1) var foe_hint_sec: float = 1.5

@export_group("Duo music")

## The music leans toward the brother in the arena: Ayden's low end, Faith's highs.
@export var duo_music: bool = true
## Shelf gain (linear, 1 = flat) of the brother's band. Safe range 1.2–2.0.
@export_range(1.0, 4.0, 0.05) var voice_gain: float = 1.6
## Low shelf (Ayden) and high shelf (Faith) cutoffs in Hz.
@export_range(40.0, 1000.0, 5.0) var ayden_shelf_hz: float = 220.0
@export_range(1000.0, 12000.0, 50.0) var faith_shelf_hz: float = 3200.0
## Seconds the music takes to lean to the new brother after a swap.
@export_range(0.0, 2.0, 0.05) var voice_fade_sec: float = 0.25
## Seconds both bands swell together after a Link Burst.
@export_range(0.0, 5.0, 0.1) var link_burst_music_sec: float = 1.2
## A soft heart thump on every shared heartbeat, so a Resonance can be heard.
@export var heartbeat_thump: bool = true
## Volume (dB) of the thump. Ayden's is low, Faith's pitched up.
@export_range(-40.0, 0.0, 0.5) var thump_db: float = -12.0
@export_range(0.5, 3.0, 0.05) var faith_thump_pitch: float = 1.5
