## DuoTuning — knobs for the Ayden / Faith duo swap (ADR-0058).
##
## Ayden and Faith are two brothers the player swaps between in combat. Ayden hits
## hard at short range; Faith reaches far and holds status longer. Authored as
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

@export_group("Hand-off")

## Seconds after a swap during which the first attack gets the hand-off bonus.
@export_range(0.0, 5.0, 0.05) var handoff_window_sec: float = 2.0
## Ayden's damage multiplier on an enemy that carries any status (Faith's setup).
@export_range(1.0, 3.0, 0.05) var handoff_damage_mult: float = 1.5
## Faith's status duration multiplier on an enemy Ayden hit recently.
@export_range(1.0, 3.0, 0.05) var handoff_status_mult: float = 1.5
## How long (s) an Ayden hit marks an enemy for Faith's hand-off.
@export_range(0.0, 5.0, 0.05) var ayden_mark_sec: float = 2.0
