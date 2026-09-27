## BulletHellTuning — data-driven knobs for the bullet-hell layer (ADR-0018).
##
## Covers Fayde's hurtbox and graze ring, bullet cancelling, dash charges, elite
## enemies and wave reinforcements. Authored as assets/data/bullet_hell_tuning.tres
## and consumed via a preload const so it resolves in headless tests without an
## Autoload (same pattern as AttackTuning / ReactionTuning).
## Design: design/gdd/bullet-hell.md
class_name BulletHellTuning
extends Resource

@export_group("Hurtbox & Graze")

## Radius (px) of Fayde's hurtbox against enemy bullets. Much smaller than her 8 px
## movement body so near misses read as fair. Safe range 2–6.
@export var player_hurt_radius: float = 3.0
## Radius (px) of the graze ring. A bullet passing inside it without hitting grazes.
## Safe range 12–30.
@export var graze_radius: float = 20.0
## Special meter gained per grazed bullet (each bullet grazes at most once).
@export var graze_meter_gain: float = 1.5
## Graze gain multiplier while dashing through a bullet (dash i-frames).
@export var dash_graze_mult: float = 2.0
## Show the hurtbox dot on Fayde during combat.
@export var show_hurtbox_dot: bool = true

@export_group("Bullet Cancel")

## Radius (px) around Fayde cleared of enemy bullets on a Perfect Cast.
@export var perfect_cancel_radius: float = 60.0
## The Special clears bullets within its own radius times this factor.
@export var special_cancel_radius_mult: float = 1.25
## Radius (px) cleared when the Special has no radius of its own (Lightning chain).
@export var special_cancel_fallback_radius: float = 170.0

@export_group("Dash")

## Dash charges held at full recharge. 1 = the old single dash.
@export var dash_charges: int = 2
## Seconds to recharge one dash charge. Scaled by dash-cooldown sigils.
@export var dash_recharge_sec: float = 0.9

@export_group("Elites")

## HP multiplier for an elite enemy.
@export var elite_hp_mult: float = 1.8
## Damage multiplier for an elite enemy.
@export var elite_damage_mult: float = 1.25
## Visual scale multiplier for an elite enemy.
@export var elite_scale_mult: float = 1.3
## Tint applied to elites so they read at a glance.
@export var elite_tint: Color = Color(1.6, 1.3, 0.4, 1.0)
## Extra pattern layer every elite fires on top of its normal behaviour.
@export var elite_pattern: BulletPattern = null
## Extra elite chance added in ELITE rooms (on top of EnemyPoolConfig.elite_chance).
@export var elite_room_bonus: float = 0.35

@export_group("Reinforcements")

## Seconds a reinforcement group spends as a warning marker before it activates.
@export var reinforcement_warning_sec: float = 0.6

@export_group("Performance")

## Most enemy bullets alive at once (ADR-0050). At the cap a volley fires only the
## bullets that fit, so the web build keeps its frame budget in the densest boss phases.
## 0 = no cap. Safe range 160–320; the busiest fight measured peaks well below it.
@export var max_live_bullets: int = 240
