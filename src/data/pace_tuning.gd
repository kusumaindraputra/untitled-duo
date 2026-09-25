## PaceTuning — data-driven knobs for the fast-paced layer (ADR-0019).
##
## Covers Perfect Dodge, kill orbs, bullet-cancel meter, the style meter and its
## room-end rank, kill hitstop and the quick-continue preparation phase. Authored as
## assets/data/pace_tuning.tres and consumed via a preload const so it resolves in
## headless tests without an Autoload (same pattern as BulletHellTuning).
## Design: design/gdd/fast-pace.md
class_name PaceTuning
extends Resource

@export_group("Perfect Dodge")

## Engine.time_scale during the Perfect Dodge slow-mo. Safe range 0.2–0.5.
@export var perfect_dodge_time_scale: float = 0.3
## Real-time seconds the Perfect Dodge slow-mo lasts.
@export var perfect_dodge_slowmo_sec: float = 0.3
## Special meter gained on a Perfect Dodge.
@export var perfect_dodge_meter_gain: float = 12.0
## Seconds after a Perfect Dodge before another one can trigger (stops dash-spam farming).
@export var perfect_dodge_cooldown_sec: float = 1.0
## Seconds after a Perfect Dodge during which the next basic cast counts as Perfect.
## 0 disables the free Perfect.
@export var perfect_dodge_cast_window_sec: float = 1.5

@export_group("Kill Orbs")

## Chance (0..1) that a normal kill drops an HP orb.
@export_range(0.0, 1.0) var hp_orb_chance: float = 0.12
## Elites and bosses always drop an HP orb.
@export var elite_always_drops_hp: bool = true
## HP restored by one HP orb.
@export var hp_orb_heal: float = 6.0
## Meter orbs dropped by a normal kill (elites drop twice as many).
@export var meter_orbs_per_kill: int = 1
## Special meter gained per meter orb.
@export var meter_orb_gain: float = 3.0
## Distance (px) at which an orb starts flying to Fayde.
@export var orb_magnet_radius: float = 80.0
## Orb flight speed (px/s) once magnetised.
@export var orb_magnet_speed: float = 460.0
## Distance (px) at which a flying orb is collected.
@export var orb_pickup_radius: float = 10.0
## Seconds an untouched orb lives before fading out.
@export var orb_lifetime_sec: float = 7.0
## When the room is cleared every orb on the floor flies to Fayde.
@export var collect_all_on_clear: bool = true
## Flight speed multiplier for orbs pulled in by a room clear, so they arrive before
## the reward overlay pauses the game.
@export var orb_clear_speed_mult: float = 3.0

@export_group("Bullet Cancel Meter")

## Special meter gained per bullet wiped by a Perfect Cast or a dash cut.
## The Special's own wipe grants none, so the meter cannot refill itself.
@export var cancel_meter_gain: float = 0.4

@export_group("Style")

## Style meter cap.
@export var style_max: float = 100.0
## Style gained per kill (elites and bosses count elite_kill).
@export var style_kill: float = 7.0
@export var style_elite_kill: float = 15.0
## Style gained per graze.
@export var style_graze: float = 1.5
## Style gained per Perfect Cast.
@export var style_perfect_cast: float = 5.0
## Style gained per Perfect Dodge.
@export var style_perfect_dodge: float = 12.0
## Style lost when Fayde takes damage.
@export var style_hit_penalty: float = 30.0
## Seconds without a style event before the meter starts decaying.
@export var style_idle_grace_sec: float = 1.5
## Style lost per second once idle.
@export var style_decay_per_sec: float = 10.0
## Minimum room-average style for each rank, highest first: S, A, B, C. Below the
## last entry the rank is D.
@export var rank_thresholds: PackedFloat32Array = PackedFloat32Array([55.0, 40.0, 25.0, 12.0])
## HP restored at room clear per rank, in S, A, B, C, D order.
@export var rank_heal: PackedFloat32Array = PackedFloat32Array([12.0, 8.0, 4.0, 0.0, 0.0])
## Special meter the next room starts with per rank, in S, A, B, C, D order.
@export var rank_meter_bonus: PackedFloat32Array = PackedFloat32Array([40.0, 25.0, 10.0, 0.0, 0.0])

@export_group("Kill Hitstop")

## Kill hitstop reuses SpellVFX's hit freeze (HITSTOP_TIME_SCALE); only its length is
## tuned here.
## Real-time seconds of hitstop on a normal kill.
@export var kill_hitstop_sec: float = 0.025
## Real-time seconds of hitstop on an elite or boss kill.
@export var elite_kill_hitstop_sec: float = 0.07

@export_group("Preparation")

## When the bag is empty and the centre slot is filled, one press of Cast / Enter /
## the Lanjut button starts the next room with the build unchanged.
@export var quick_continue: bool = true
