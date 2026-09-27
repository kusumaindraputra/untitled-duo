## BigMomentTuning — knobs for the boss death cinematic and the room clear moment (ADR-0041).
##
## Authored as assets/data/big_moment_tuning.tres and read through preload consts by
## BossDeathCinematic, RoomClearMoment, ClearBanner, EnemyInstance and RoomExitDoor,
## so the values resolve in headless tests without an Autoload. All durations are
## real seconds unless the name says otherwise: the moments run through slow-mo.
class_name BigMomentTuning
extends Resource

@export_group("Boss death")

## Engine.time_scale while the boss falls.
@export_range(0.05, 1.0) var boss_slowmo_scale: float = 0.25
## Real seconds the boss slow-mo lasts.
@export var boss_slowmo_sec: float = 1.4
## Camera zoom on the boss, as a multiple of the zoom the fight was using.
@export var boss_zoom_mult: float = 1.35
## Real seconds the camera takes to glide onto the boss.
@export var boss_zoom_in_sec: float = 0.35
## Real seconds the camera holds on the boss while it dissolves.
@export var boss_hold_sec: float = 1.3
## Real seconds the camera takes to glide back to Fayde.
@export var boss_zoom_out_sec: float = 0.5
## Peak alpha of the white flash at the kill (scaled by the Reduce flashes setting).
@export_range(0.0, 1.0) var boss_flash_alpha: float = 0.85
## Real seconds the white flash takes to fade.
@export var boss_flash_sec: float = 0.55
## Game seconds the boss sprite takes to dissolve (normal enemies use CharacterFxTuning).
@export var boss_dissolve_sec: float = 1.1

@export_group("Room clear")

## Engine.time_scale right after the last kill of a room.
@export_range(0.05, 1.0) var clear_slowmo_scale: float = 0.3
## Real seconds the room clear slow-mo lasts.
@export var clear_slowmo_sec: float = 0.45
## Real seconds a slow-mo waits for a running hitstop to end before giving up.
@export var slowmo_wait_sec: float = 0.3
## Real seconds the CLEAR text takes to punch in.
@export var clear_in_sec: float = 0.18
## Real seconds the CLEAR text holds.
@export var clear_hold_sec: float = 0.75
## Real seconds the CLEAR text takes to fade.
@export var clear_out_sec: float = 0.4
## Starting scale of the CLEAR text punch (1.0 = no punch).
@export var clear_punch_scale: float = 1.6
## Game seconds a pulled orb takes to reach full pull speed (it eases in, then whips).
@export var orb_pull_ramp_sec: float = 0.35
## Length of the streak a pulled orb leaves behind, in seconds of travel.
@export var orb_trail_sec: float = 0.06

@export_group("Door")

## Real seconds the door's unlock burst ring takes to grow and fade.
@export var door_burst_sec: float = 0.7
## Radius the door's unlock burst ring grows to, px.
@export var door_burst_radius: float = 120.0
